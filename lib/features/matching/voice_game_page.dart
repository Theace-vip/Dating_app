import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/network/connectivity_service.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/api/socket_client.dart';
import 'package:dating_app/data/models/models.dart';
import 'package:dating_app/data/repositories/chat_repository.dart';
import 'package:dating_app/data/repositories/catalog_repository.dart';
import 'package:dating_app/features/call/rtc_session.dart';
import 'package:dating_app/features/chat/chat_detail_page.dart';

enum _VoiceStatus { searching, matched, ended }

/// Voice Game THẬT: ghép 2 người ẩn danh qua hàng đợi server (mode=voice)
/// rồi thoại trực tiếp bằng WebRTC trong thời lượng do API cung cấp.
class VoiceGamePage extends ConsumerStatefulWidget {
  const VoiceGamePage({super.key});

  @override
  ConsumerState<VoiceGamePage> createState() => _VoiceGamePageState();
}

class _VoiceGamePageState extends ConsumerState<VoiceGamePage>
    with SingleTickerProviderStateMixin {
  int _totalSeconds = 0;
  DateTime? _endsAt;
  int _remaining = 0;
  Timer? _timer;
  late final AnimationController _pulseController;

  _VoiceStatus _status = _VoiceStatus.searching;
  String? _sessionId;
  String _strangerAvatar = '🙂';
  RtcSession? _session;
  RtcState _rtcState = RtcState.connecting;

  bool _micMuted = false;
  bool _speakerOn = true;
  bool _endSheetOpen = false;
  bool _leaving = false;

  final List<StreamSubscription<dynamic>> _subs = [];
  SocketService? _socket;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    final socket = ref.read(socketProvider);
    _socket = socket;
    if (!socket.connected) {
      Future.microtask(() {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa kết nối tới máy chủ — kiểm tra mạng'),
          ),
        );
        Navigator.of(context).pop();
      });
      return;
    }

    _subs.add(
      socket.on('soul:matched').listen((data) async {
        if (!mounted) return;
        final map = data as Map;
        if (map['mode'] != 'voice') return;
        setState(() {
          _sessionId = map['sessionId'] as String?;
          _totalSeconds = (map['durationSeconds'] as num?)?.toInt() ?? _totalSeconds;
          _endsAt = DateTime.tryParse(map['endsAt']?.toString() ?? '');
          _remaining = _totalSeconds;
          _strangerAvatar =
              ((map['stranger'] ?? {}) as Map)['avatar']?.toString() ?? '🙂';
          _status = _VoiceStatus.matched;
          _remaining = _totalSeconds;
          _rtcState = RtcState.connecting;
        });
        _startTimer();
        await _startRtc(initiator: map['initiator'] == true);
      }),
    );

    _subs.add(
      socket.on('soul:rtc:signal').listen((data) {
        final map = data as Map;
        if (map['sessionId'] != _sessionId) return;
        final session = _session;
        if (session != null && map['data'] is Map) {
          session.handleSignal((map['data'] as Map).cast<String, dynamic>());
        }
      }),
    );

    _subs.add(
      socket.on('soul:partner-left').listen((data) {
        if (!mounted || _leaving) return;
        _timer?.cancel();
        _disposeSession();
        setState(() {
          _status = _VoiceStatus.searching;
          _sessionId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đối phương đã rời đi — đang tìm người mới...'),
          ),
        );
        socket.emit('soul:queue', {'mode': 'voice'});
      }),
    );

    _subs.add(
      socket.on('soul:revealed').listen((data) {
        if (!mounted || _leaving) return;
        final map = (data as Map).cast<String, dynamic>();
        final user = UserModel.fromJson(map['user'] as Map<String, dynamic>);
        final conversationId = map['conversationId'] as String?;
        _leaving = true;
        _timer?.cancel();
        ref.read(chatProvider.notifier).load();
        Future.microtask(() {
          if (!mounted) return;
          final navigator = Navigator.of(context);
          if (_endSheetOpen) navigator.pop();
          navigator.pop();
          if (conversationId != null) {
            navigator.push(
              MaterialPageRoute(
                builder: (_) => ChatDetailPage(
                  conversationId: conversationId,
                  partnerId: user.id,
                  partnerName: user.name,
                  partnerAvatar: user.avatar,
                ),
              ),
            );
          }
        });
      }),
    );

    _subs.add(
      socket.on('soul:continue:error').listen((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Phiên chat đã kết thúc — hãy hiện danh tính hoặc tìm người mới',
            ),
          ),
        );
      }),
    );

    _subs.add(
      socket.on('soul:time-ended').listen((data) {
        if (!mounted || (data as Map)['sessionId'] != _sessionId) return;
        _timer?.cancel();
        setState(() {
          _remaining = 0;
          _endsAt = null;
          _status = _VoiceStatus.ended;
        });
        _showEndSheet();
      }),
    );

    _subs.add(
      socket.on('soul:continued').listen((data) {
        if (!mounted) return;
        final map = data as Map;
        if (map['sessionId'] != _sessionId) return;
        setState(() {
          _status = _VoiceStatus.matched;
          _totalSeconds = (map['durationSeconds'] as num?)?.toInt() ?? _totalSeconds;
          _remaining = _totalSeconds;
          _endsAt = DateTime.tryParse(map['endsAt']?.toString() ?? '');
        });
        _startTimer();
        if (_endSheetOpen) Navigator.of(context).pop();
      }),
    );

    // Lấy cấu hình thời lượng từ server trước khi vào hàng ghép voice.
    Future.microtask(_loadOptionsAndQueue);
  }

  Future<void> _loadOptionsAndQueue() async {
    try {
      final catalog = await ref.read(appCatalogProvider.future);
      if (!mounted) return;
      setState(() {
        _totalSeconds = catalog.voiceSeconds;
        _remaining = _totalSeconds;
      });
      _socket?.emit('soul:queue', {'mode': 'voice'});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tải được cấu hình từ máy chủ')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _startRtc({required bool initiator}) async {
    await _disposeSession();
    try {
      final sessionId = _sessionId;
      final session = RtcSession(
        isVideo: false,
        isInitiator: initiator,
        send: (data) => _socket?.emit('soul:rtc:signal', {
          'sessionId': sessionId,
          'data': data,
        }),
      );
      _session = session;
      _subs.add(
        session.state.listen((s) {
          if (mounted) setState(() => _rtcState = s);
        }),
      );
      await session.start();
      if (!mounted) return;
      session.setMic(!_micMuted);
      await session.setSpeaker(_speakerOn);
    } catch (_) {
      if (mounted) {
        setState(() => _rtcState = RtcState.failed);
      }
    }
  }

  Future<void> _disposeSession() async {
    final s = _session;
    _session = null;
    await s?.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _status != _VoiceStatus.matched) return;
      // Lấy mốc hết hạn từ server để đồng hồ không trôi theo thời gian thiết bị.
      final endsAt = _endsAt;
      final secondsLeft = endsAt == null
          ? (_remaining - 1).clamp(0, _totalSeconds)
          : endsAt.difference(DateTime.now()).inSeconds.clamp(0, _totalSeconds);
      setState(() => _remaining = secondsLeft);
      if (_remaining <= 0) {
        _timer?.cancel();
        _socket?.emit('soul:finish', {'sessionId': _sessionId});
        // Chỉ event soul:time-ended từ server mới xác nhận hết giờ và mở sheet cho cả hai.
      }
    });
  }

  Future<void> _continueChat() async {
    if (_sessionId == null || !await ensureOnline(context, ref) || !mounted) {
      return;
    }
    final socket = ref.read(socketProvider);
    if (!socket.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mất kết nối máy chủ — vui lòng thử lại')),
      );
      return;
    }
    socket.emit('soul:continue', {'sessionId': _sessionId});
  }

  Future<void> _findAnother() async {
    if (!await ensureOnline(context, ref) || !mounted) return;
    final socket = ref.read(socketProvider);
    if (!socket.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mất kết nối máy chủ — vui lòng thử lại')),
      );
      return;
    }
    await _disposeSession();
    if (!mounted) return;
    setState(() {
      _status = _VoiceStatus.searching;
      _sessionId = null;
      _endsAt = null;
      _remaining = _totalSeconds;
    });
    socket.emit('soul:queue', {'mode': 'voice'});
    if (_endSheetOpen) Navigator.of(context).pop();
  }

  void _showEndSheet() {
    _endSheetOpen = true;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Hết thời gian!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bạn muốn tiếp tục như thế nào?',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _continueChat,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Tiếp tục trò chuyện ẩn danh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                if (_sessionId == null ||
                    !await ensureOnline(context, ref) ||
                    !mounted) {
                  return;
                }
                final socket = ref.read(socketProvider);
                if (!socket.connected) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mất kết nối máy chủ — vui lòng thử lại'),
                    ),
                  );
                  return;
                }
                socket.emit('soul:reveal', {'sessionId': _sessionId});
              },
              child: Container(
                height: 52,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Hiện danh tính & Kết bạn',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _findAnother,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Tìm người mới',
                  style: TextStyle(color: AppColors.primary, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      _endSheetOpen = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _pulseController.dispose();
    _session?.dispose();
    _socket?.emit('soul:leave');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remaining ~/ 60;
    final seconds = _remaining % 60;
    final timeLabel =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final statusLabel = switch (_status) {
      _VoiceStatus.searching => 'Đang tìm người gọi ẩn danh...',
      _VoiceStatus.matched => switch (_rtcState) {
        RtcState.connecting => 'Đang kết nối...',
        RtcState.connected => 'Đang gọi... ●',
        RtcState.failed => 'Mất kết nối',
        RtcState.closed => 'Đã đóng',
      },
      _VoiceStatus.ended => 'Đã hết thời gian',
    };

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.soulGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    const Spacer(),
                    if (_status == _VoiceStatus.matched)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.timer,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                statusLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                _status == _VoiceStatus.searching
                    ? 'Chờ người tâm giao'
                    : 'Người lạ',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ScaleTransition(
                scale: Tween<double>(
                  begin: 0.95,
                  end: 1.08,
                ).animate(_pulseController),
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                    border: Border.all(
                      color: _rtcState == RtcState.connected
                          ? AppColors.success
                          : Colors.white.withValues(alpha: 0.5),
                      width: 3,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _strangerAvatar,
                    style: const TextStyle(fontSize: 84),
                  ),
                ),
              ),
              const Spacer(),
              if (_status == _VoiceStatus.matched)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CircleButton(
                      icon: _micMuted ? Icons.mic_off : Icons.mic,
                      label: _micMuted ? 'Đã tắt mic' : 'Mic',
                      active: !_micMuted,
                      onTap: () {
                        setState(() => _micMuted = !_micMuted);
                        _session?.setMic(!_micMuted);
                      },
                    ),
                    const SizedBox(width: 32),
                    _CircleButton(
                      icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                      label: _speakerOn ? 'Loa' : 'Đã tắt loa',
                      active: _speakerOn,
                      onTap: () {
                        setState(() => _speakerOn = !_speakerOn);
                        _session?.setSpeaker(_speakerOn);
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 32),
              if (_status == _VoiceStatus.matched)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Nút kết thúc vẫn gửi yêu cầu; server kiểm tra thành viên và phát trạng thái.
                        _socket?.emit('soul:finish', {'sessionId': _sessionId});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.call_end),
                      label: const Text(
                        'Kết thúc',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _CircleButton({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppColors.error.withValues(alpha: 0.85),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
