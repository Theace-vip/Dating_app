import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:dating_app/core/network/connectivity_service.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/api/socket_client.dart';
import 'package:dating_app/data/repositories/catalog_repository.dart';
import 'package:dating_app/shared/widgets/app_widgets.dart';
import 'package:dating_app/features/call/rtc_session.dart';

/// Màn hình cuộc gọi thoại/video 1-1.
/// Trạng thái đi theo thứ tự: ringing/outgoing -> accepted -> WebRTC connected -> ended.
/// Socket chỉ vận chuyển offer/answer/ICE; mic/camera truyền trực tiếp qua WebRTC.
///
/// Đang có 1 cuộc gọi (chặn gọi đến chồng lên nhau)
bool gInCall = false;

enum _CallPhase { outgoing, incoming, connecting, connected, ended }

class CallPage extends ConsumerStatefulWidget {
  const CallPage({
    super.key,
    required this.peerId,
    required this.partnerName,
    required this.partnerAvatar,
    this.isVideo = false,
    required this.callId,
    this.incoming = false,
  });

  final String peerId; // userId của đối phương
  final String partnerName;
  final String partnerAvatar;
  final bool isVideo;
  final String callId;
  final bool incoming; // true = màn hình gọi đến

  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

/// Điều phối trạng thái ringing -> accept -> WebRTC -> kết thúc, đồng thời vẽ media.
class _CallPageState extends ConsumerState<CallPage>
    with SingleTickerProviderStateMixin {
  _CallPhase _phase = _CallPhase.outgoing;
  RtcSession? _session;
  final List<StreamSubscription<dynamic>> _subs = [];
  final List<Map<String, dynamic>> _pendingSignals = [];
  bool _sessionReady = false;
  bool _callAccepted = false;
  int _ringTimeoutSeconds = 45;
  Timer? _ringTimeout;
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _localReady = false;
  bool _remoteReady = false;

  bool _micOn = true;
  bool _cameraOn = true;
  bool _speakerOn = false;
  String? _statusText;

  @override
  void initState() {
    super.initState();
    gInCall = true;
    _speakerOn = !widget.isVideo; // loa ngoài mặc định cho gọi thoại
    _phase = widget.incoming ? _CallPhase.incoming : _CallPhase.outgoing;

    // Thời gian chuông lấy từ cấu hình backend thay vì hằng số giao diện.
    Future.microtask(_loadCallOptions);

    // ===== Lắng nghe sự kiện cuộc gọi =====
    // Mọi sự kiện đều lọc theo callId để không nhầm cuộc gọi khác.
    final socket = ref.read(socketProvider);

    _subs.add(
      socket.on('call:accepted').listen((data) {
        if ((data as Map)['callId'] != widget.callId) return;
        _ringTimeout?.cancel();
        _callAccepted = true;
        _startSession(initiator: true);
      }),
    );

    _subs.add(
      socket.on('call:rejected').listen((data) {
        if ((data as Map)['callId'] != widget.callId) return;
        _finish(message: 'Đối phương đã từ chối cuộc gọi');
      }),
    );

    _subs.add(
      socket.on('call:ended').listen((data) {
        if ((data as Map)['callId'] != widget.callId) return;
        _finish(message: 'Cuộc gọi đã kết thúc');
      }),
    );

    _subs.add(
      socket.on('call:error').listen((data) {
        final map = data as Map;
        if (map['callId'] != widget.callId) return;
        _finish(message: map['message'] ?? 'Không gọi được');
      }),
    );

    _subs.add(
      socket.on('rtc:signal').listen((data) {
        final map = data as Map;
        if (map['callId'] != widget.callId || map['data'] is! Map) return;
        final signal = (map['data'] as Map).cast<String, dynamic>();
        // Buffer SDP/ICE while microphone/camera initializes; RtcSession consumes it once ready.
        _pendingSignals.add(signal);
        _flushPendingSignals();
      }),
    );

    if (widget.incoming) {
      // Dọn lời mời nếu người nhận không thao tác; tránh để cuộc gọi chiếm trạng thái bận.
      _ringTimeout = Timer(Duration(seconds: _ringTimeoutSeconds), () {
        if (!mounted || _phase != _CallPhase.incoming) return;
        ref.read(socketProvider).emit('call:reject', {
          'to': widget.peerId,
          'callId': widget.callId,
        });
        _finish(message: 'Cuộc gọi đến đã hết hạn');
      });
    } else {
      _invite();
    }
  }

  Future<void> _loadCallOptions() async {
    try {
      final catalog = await ref.read(appCatalogProvider.future);
      if (mounted) setState(() => _ringTimeoutSeconds = catalog.callRingingTimeoutSeconds);
    } catch (_) {
      // Nếu API cấu hình tạm thời lỗi, giữ ngưỡng an toàn dự phòng là 45 giây.
    }
  }

  /// Chờ socket kết nối trước khi gửi lời mời, rồi kết thúc thay vì để UI treo.
  Future<void> _invite() async {
    if (!await ensureOnline(context, ref)) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;

    final socket = ref.read(socketProvider);
    if (!socket.connected) {
      final connected = socket
          .on('connect')
          .firstWhere((isConnected) => isConnected == true)
          .timeout(const Duration(seconds: 8));
      try {
        await socket.connect();
        if (!socket.connected) await connected;
      } on TimeoutException {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không kết nối được máy chủ cuộc gọi')),
        );
        Navigator.of(context).pop();
        return;
      }
    }
    if (!mounted || !socket.connected) return;

    socket.emit('call:invite', {
      'to': widget.peerId,
      'callId': widget.callId,
      'isVideo': widget.isVideo,
    });
    setState(() => _statusText = 'Đang gọi ${widget.partnerName}...');
    // Nếu không bắt máy trong 45 giây thì báo hangup để server nhả cuộc gọi.
    _ringTimeout?.cancel();
    _ringTimeout = Timer(Duration(seconds: _ringTimeoutSeconds), () {
      if (mounted &&
          (_phase == _CallPhase.outgoing || _phase == _CallPhase.connecting)) {
        ref.read(socketProvider).emit('call:hangup', {
          'to': widget.peerId,
          'callId': widget.callId,
        });
        _finish(
          message: _callAccepted
              ? 'Không thể kết nối cuộc gọi'
              : 'Không có ai bắt máy',
        );
      }
    });
  }

  /// Tạo phiên media sau accept; caller tạo offer, callee chờ offer rồi trả answer.
  Future<void> _startSession({required bool initiator}) async {
    if (_session != null) return;
    setState(() {
      _phase = _CallPhase.connecting;
      _statusText = 'Đang kết nối...';
    });

    try {
      final session = RtcSession(
        isVideo: widget.isVideo,
        isInitiator: initiator,
        send: (data) => ref.read(socketProvider).emit('rtc:signal', {
          'to': widget.peerId,
          'callId': widget.callId,
          'data': data,
        }),
      );
      _session = session;

      await _localRenderer.initialize();
      _localReady = true;

      _subs.add(
        session.state.listen((s) {
          if (!mounted) return;
          if (s == RtcState.connected) {
            _ringTimeout?.cancel();
            setState(() {
              _phase = _CallPhase.connected;
              _statusText = 'Đã kết nối ●';
            });
            unawaited(session.setSpeaker(_speakerOn));
          } else if (s == RtcState.failed) {
            _finish(
              message: 'Kết nối WebRTC thất bại — kiểm tra mạng hoặc quyền micro/camera',
            );
          }
        }),
      );

      _subs.add(
        session.onRemoteStream.listen((stream) async {
          await _remoteRenderer.initialize();
          _remoteRenderer.srcObject = stream;
          if (mounted) setState(() => _remoteReady = true);
          await session.setSpeaker(_speakerOn);
        }),
      );

      await session.start();
      _ringTimeout?.cancel();
      _sessionReady = true;
      _startConnectionTimeout();
      _flushPendingSignals();
      session.setMic(_micOn);
      if (widget.isVideo) session.setCamera(_cameraOn);
      await session.setSpeaker(_speakerOn);

      if (widget.isVideo && session.localStream != null) {
        _localRenderer.srcObject = session.localStream;
        if (mounted) setState(() => _localReady = true);
      }
    } catch (_) {
      _finish(message: 'Không khởi tạo được cuộc gọi (kiểm tra micro/camera)');
    }
  }

  void _startConnectionTimeout() {
    _ringTimeout?.cancel();
    _ringTimeout = Timer(const Duration(seconds: 35), () {
      if (mounted && _phase == _CallPhase.connecting) {
        ref.read(socketProvider).emit('call:hangup', {
          'to': widget.peerId,
          'callId': widget.callId,
        });
        _finish(message: 'Kết nối cuộc gọi quá lâu — hãy thử gọi lại');
      }
    });
  }

  /// Đẩy các tín hiệu SDP/ICE đã nhận sớm vào phiên WebRTC khi phiên sẵn sàng.
  void _flushPendingSignals() {
    final session = _session;
    if (!_sessionReady || session == null || _pendingSignals.isEmpty) return;
    final pending = List<Map<String, dynamic>>.of(_pendingSignals);
    _pendingSignals.clear();
    for (final signal in pending) {
      unawaited(session.handleSignal(signal));
    }
  }

  /// Người nhận xác nhận với server rồi mở phiên RTC phía callee.
  void _accept() {
    if (!mounted || _phase != _CallPhase.incoming) return;
    _ringTimeout?.cancel();
    _callAccepted = true;
    ref.read(socketProvider).emit('call:accept', {
      'to': widget.peerId,
      'callId': widget.callId,
    });
    _startSession(initiator: false);
  }

  void _decline() {
    _ringTimeout?.cancel();
    ref.read(socketProvider).emit('call:reject', {
      'to': widget.peerId,
      'callId': widget.callId,
    });
    Navigator.of(context).pop();
  }

  /// Báo server đóng callId và giải phóng UI/thiết bị media.
  Future<void> _hangup() async {
    _ringTimeout?.cancel();
    _callAccepted = true;
    ref.read(socketProvider).emit('call:hangup', {
      'to': widget.peerId,
      'callId': widget.callId,
    });
    _finish();
  }

  /// Đóng UI/phiên theo một đường duy nhất; guard để không chạy lặp khi
  /// nhiều sự kiện (từ chối, cúp máy, timeout) cùng về một lúc.
  void _finish({String? message}) {
    if (!mounted || _phase == _CallPhase.ended) return;
    _ringTimeout?.cancel();
    _sessionReady = false;
    setState(() => _phase = _CallPhase.ended);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() {
    gInCall = false;
    _ringTimeout?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _session?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color color = Colors.white24,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 26),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showVideo =
        widget.isVideo &&
        (_phase == _CallPhase.connecting || _phase == _CallPhase.connected);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text(
                widget.isVideo ? 'Cuộc gọi video' : 'Cuộc gọi thoại',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                widget.partnerName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(switch (_phase) {
                _CallPhase.outgoing => _statusText ?? 'Đang gọi...',
                _CallPhase.incoming => 'Cuộc gọi đến',
                _CallPhase.connecting => 'Đang kết nối...',
                _CallPhase.connected => 'Đã kết nối ●',
                _CallPhase.ended => 'Đã kết thúc',
              }, style: const TextStyle(fontSize: 15, color: Colors.white70)),
              const SizedBox(height: 24),
              Expanded(
                child: showVideo
                    ? Stack(
                        children: [
                          if (_remoteReady)
                            SizedBox.expand(
                              child: RTCVideoView(
                                _remoteRenderer,
                                objectFit: RTCVideoViewObjectFit
                                    .RTCVideoViewObjectFitCover,
                              ),
                            )
                          else
                            const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          if (_localReady)
                            Align(
                              alignment: Alignment.topRight,
                              child: Container(
                                margin: const EdgeInsets.all(16),
                                width: 110,
                                height: 160,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: RTCVideoView(
                                  _localRenderer,
                                  mirror: true,
                                  objectFit: RTCVideoViewObjectFit
                                      .RTCVideoViewObjectFitCover,
                                ),
                              ),
                            ),
                        ],
                      )
                    : Center(
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 1.0,
                            end: 1.08,
                          ).animate(_pulseController),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white38,
                                width: 3,
                              ),
                            ),
                            child: AppAvatar(
                              avatar: widget.partnerAvatar,
                              size: 140,
                              isOnline: false,
                            ),
                          ),
                        ),
                      ),
              ),
              // ===== Điều khiển =====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (_phase == _CallPhase.incoming) ...[
                      _roundButton(
                        icon: Icons.call_end,
                        onPressed: _decline,
                        color: AppColors.error,
                      ),
                      _roundButton(
                        icon: Icons.call,
                        onPressed: _accept,
                        color: AppColors.success,
                      ),
                    ] else ...[
                      _roundButton(
                        icon: _micOn ? Icons.mic : Icons.mic_off,
                        onPressed: () {
                          setState(() => _micOn = !_micOn);
                          _session?.setMic(_micOn);
                        },
                        color: _micOn ? Colors.white24 : Colors.white38,
                      ),
                      if (widget.isVideo)
                        _roundButton(
                          icon: _cameraOn ? Icons.videocam : Icons.videocam_off,
                          onPressed: () {
                            setState(() => _cameraOn = !_cameraOn);
                            _session?.setCamera(_cameraOn);
                          },
                          color: _cameraOn ? Colors.white24 : Colors.white38,
                        ),
                      _roundButton(
                        icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                        onPressed: () {
                          setState(() => _speakerOn = !_speakerOn);
                          _session?.setSpeaker(_speakerOn);
                        },
                        color: _speakerOn ? Colors.white24 : Colors.white38,
                      ),
                      _roundButton(
                        icon: Icons.call_end,
                        onPressed: _hangup,
                        color: AppColors.error,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
