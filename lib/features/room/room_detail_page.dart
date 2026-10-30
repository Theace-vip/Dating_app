import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/network/connectivity_service.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/api/api_client.dart';
import 'package:dating_app/data/api/socket_client.dart';
import 'package:dating_app/data/models/models.dart';
import 'package:dating_app/data/repositories/chat_repository.dart';
import 'package:dating_app/data/repositories/catalog_repository.dart';
import 'package:dating_app/shared/widgets/app_widgets.dart';
import 'package:dating_app/features/call/rtc_session.dart';

/// Màn hình phòng tiệc: chat nhóm, thành viên online, thả tim, gửi quà và mic.
/// Mic dùng WebRTC mesh: mỗi cặp thành viên có một [RtcSession] riêng, tín hiệu
/// SDP/ICE đi qua socket của phòng; server kiểm tra thành viên trước khi relay.
class RoomDetailPage extends ConsumerStatefulWidget {
  const RoomDetailPage({super.key, required this.room});
  final RoomModel room;

  @override
  ConsumerState<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends ConsumerState<RoomDetailPage> {
  final List<RoomMessageModel> _messages = [];
  final List<_FloatingHeartData> _hearts = [];
  final List<_GiftAnimationData> _activeGifts = [];
  final math.Random _random = math.Random();
  final _ctrl = TextEditingController();
  bool _micOn = false; // mic THẬT trong phòng (WebRTC mesh)
  bool _loading = true;
  bool _giftCatalogLoading = false;
  List<RoomGiftOption> _roomGifts = const [];

  // Các kết nối WebRTC tới từng thành viên đang mic (mesh)
  final Map<String, RtcSession> _rtcPeers = {};

  final List<StreamSubscription<dynamic>> _subs = [];
  late final SocketService _socket;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(socketProvider);
    final socket = _socket;
    final roomId = widget.room.id;

    // ===== Vào phòng: tải lịch sử trước rồi mới join để không lỡ tin mới =====
    Future.microtask(() async {
      await _loadHistory();
      if (mounted) socket.emit('room:join', {'roomId': roomId});
    });

    // ===== Chat, thành viên, tim và quà =====
    // Tin nhắn phòng realtime (kể cả do chính mình gửi qua REST)
    _subs.add(socket.on('room:message').listen((data) {
      if (!mounted) return;
      final map = data as Map;
      if (map['roomId'] != roomId) return;
      final msg =
          RoomMessageModel.fromJson(map['message'] as Map<String, dynamic>);
      _addMessage(msg);
    }));

    // Thành viên đang online trong phòng
    _subs.add(socket.on('room:presence').listen((data) {
      if (!mounted) return;
      final map = data as Map;
      if (map['roomId'] != roomId) return;
      ref
          .read(roomsProvider.notifier)
          .applyPresence(roomId, map['members'] as List? ?? const []);
    }));

    // Thả tim từ người khác
    _subs.add(socket.on('room:heart').listen((data) {
      if (!mounted) return;
      final map = data as Map;
      if (map['roomId'] != roomId) return;
      _spawnHeart();
    }));

    // Quà từ thành viên trong phòng (bao gồm cả chính mình)
    _subs.add(socket.on('room:gift').listen((data) {
      if (!mounted) return;
      final map = data as Map;
      if (map['roomId'] != roomId) return;
      final fromMap = (map['from'] ?? {}) as Map;
      final fromName = fromMap['name']?.toString() ?? 'Ai đó';
      final fromAvatar = fromMap['avatar']?.toString();
      final giftEmoji = map['gift']?.toString() ?? '🎁';
      _triggerGiftEffect(
        fromName: fromName,
        fromAvatar: fromAvatar,
        giftEmoji: giftEmoji,
      );
    }));

    // Lỗi từ server (vd: không đủ Xu)
    _subs.add(socket.on('room:error').listen((data) {
      if (!mounted) return;
      final message = ((data ?? {}) as Map)['message'] ?? 'Có lỗi xảy ra';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$message')));
    }));

    // ===== WebRTC mesh trong phòng =====
    // Người vào sau trả lời offer (tạo session chờ offer)
    _subs.add(socket.on('room:rtc:peers').listen((data) {
      if (!mounted) return;
      final map = data as Map;
      if (map['roomId'] != roomId) return;
      for (final p in (map['peers'] as List? ?? const [])) {
        final peer = (p as Map)['userId']?.toString();
        if (peer != null) _ensurePeer(peer, initiator: false);
      }
    }));
    // Người đang ở phòng tạo offer cho người vừa vào
    _subs.add(socket.on('room:rtc:joined').listen((data) {
      if (!mounted || !_micOn) return;
      final map = data as Map;
      if (map['roomId'] != roomId) return;
      final peer = ((map['peer'] ?? {}) as Map)['userId']?.toString();
      if (peer != null) _ensurePeer(peer, initiator: true);
    }));
    // Người rời phòng -> đóng kết nối
    _subs.add(socket.on('room:rtc:left').listen((data) {
      if (!mounted) return;
      final map = data as Map;
      if (map['roomId'] != roomId) return;
      _closePeer(map['userId']?.toString() ?? '');
    }));
    // Tín hiệu SDP/ICE qua lại
    _subs.add(socket.on('room:rtc:signal').listen((data) {
      if (!mounted) return;
      final map = data as Map;
      if (map['roomId'] != roomId) return;
      final from = map['from']?.toString() ?? '';
      final session = _rtcPeers[from];
      if (session != null && map['data'] is Map) {
        session.handleSignal((map['data'] as Map).cast<String, dynamic>());
      }
    }));
  }

  /// Tạo kết nối mesh tới một thành viên đang bật mic.
  /// Người vào sau nhận danh sách peers và chờ offer; người đã ở trong phòng
  /// chủ động tạo offer khi có người mới tham gia mic.
  Future<void> _ensurePeer(String peerId, {required bool initiator}) async {
    if (_rtcPeers.containsKey(peerId)) return;
    final session = RtcSession(
      isVideo: false,
      isInitiator: initiator,
      send: (data) => _socket.emit('room:rtc:signal', {
            'roomId': widget.room.id,
            'to': peerId,
            'data': data,
          }),
    );
    _rtcPeers[peerId] = session;
    try {
      await session.start();
      session.setMic(_micOn);
      await session.setSpeaker(true);
    } catch (_) {
      _closePeer(peerId);
    }
  }

  Future<void> _closePeer(String peerId) async {
    final s = _rtcPeers.remove(peerId);
    await s?.dispose();
  }

  Future<void> _closeAllPeers() async {
    final sessions = Map<String, RtcSession>.of(_rtcPeers);
    _rtcPeers.clear();
    for (final s in sessions.values) {
      await s.dispose();
    }
  }

  Future<void> _loadHistory() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/api/rooms/${widget.room.id}/messages');
      final list = (data['messages'] as List)
          .map((e) => RoomMessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(list);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addMessage(RoomMessageModel msg) {
    if (_messages.any((m) => m.id == msg.id)) return;
    setState(() => _messages.add(msg));
  }

  void _spawnHeart() {
    final emojis = const ['❤️', '💖', '💕', '💓', '💗', '💘', '💝', '✨'];
    final heart = _FloatingHeartData(
      id: UniqueKey().toString(),
      emoji: emojis[_random.nextInt(emojis.length)],
      startX: _random.nextDouble() * 40 - 20,
      sway: (_random.nextDouble() - 0.5) * 60,
      size: 28.0 + _random.nextDouble() * 14.0,
      durationMs: 1800 + _random.nextInt(600),
    );
    setState(() => _hearts.add(heart));
    Future.delayed(Duration(milliseconds: heart.durationMs + 200), () {
      if (mounted) setState(() => _hearts.remove(heart));
    });
  }

  void _triggerGiftEffect({
    required String fromName,
    required String? fromAvatar,
    required String giftEmoji,
  }) {
    final gift = _GiftAnimationData(
      id: UniqueKey().toString(),
      fromName: fromName,
      fromAvatar: fromAvatar,
      giftEmoji: giftEmoji,
    );
    setState(() => _activeGifts.add(gift));
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _activeGifts.remove(gift));
    });
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    if (!await ensureOnline(context, ref)) return;
    _ctrl.clear();
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.post('/api/rooms/${widget.room.id}/messages',
          data: {'content': t});
      // Thêm ngay; socket broadcast tới sẽ được dedup theo id
      _addMessage(
          RoomMessageModel.fromJson(data['message'] as Map<String, dynamic>));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _loadRoomGifts() async {
    if (_giftCatalogLoading) return;
    setState(() => _giftCatalogLoading = true);
    try {
      // Tải danh mục quà server định giá; app không gửi giá hay tự trừ số dư.
      final catalog = await ref.read(appCatalogProvider.future);
      if (!mounted) return;
      setState(() => _roomGifts = catalog.roomGifts);
      _showGifts();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tải được danh sách quà')),
        );
      }
    } finally {
      if (mounted) setState(() => _giftCatalogLoading = false);
    }
  }

  void _showGifts() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _roomGifts.isEmpty
                  ? 'Danh sách quà trống'
                  : 'Gửi quà (${_roomGifts.first.cost} Xu / quà)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: _roomGifts
                  .map((gift) => InkWell(
                        onTap: () {
                          Navigator.pop(sheetContext);
                          // Server kiểm tra id quà, số dư và trừ Xu trước khi phát broadcast.
                          _socket.emit('room:gift', {
                            'roomId': widget.room.id,
                            'gift': gift.id,
                          });
                        },
                        child: Center(
                          child: Tooltip(
                            message: '${gift.cost} Xu',
                            child: Text(
                              gift.emoji,
                              style: const TextStyle(fontSize: 36),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    // Thứ tự dọn dẹp: ngắt mic/peer trước, rời phòng sau, cuối cùng giải phóng UI.
    if (_micOn) _socket.emit('room:rtc:leave', {'roomId': widget.room.id});
    _closeAllPeers();
    _socket.emit('room:leave', {'roomId': widget.room.id});
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Phòng cập nhật realtime (số thành viên...) qua roomsProvider
    final rooms = ref.watch(roomsProvider);
    final room = rooms.firstWhere(
      (r) => r.id == widget.room.id,
      orElse: () => widget.room,
    );

    return Scaffold(
      appBar: AppBar(title: Text(room.name)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: Column(
              children: [
                Text(room.backgroundEmoji ?? '🎉',
                    style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text(
                  '${room.memberCount} đang online • ${room.topic}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 60,
                  child: room.memberAvatars.isEmpty
                      ? const Center(
                          child: Text('Chưa ai tham gia phòng',
                              style: TextStyle(color: Colors.white70)))
                      : GridView.count(
                          crossAxisCount: 6,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: room.memberAvatars
                              .take(12)
                              .map((a) => Center(
                                  child: AppAvatar(avatar: a, size: 40)))
                              .toList(),
                        ),
                ),
                const SizedBox(height: 6),
                Text('Chủ phòng: ${room.hostName}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                _loading
                    ? const LoadingWidget()
                    : _messages.isEmpty
                        ? const EmptyState(
                            message: 'Chưa có tin nhắn', emoji: '💬')
                        : ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.all(12),
                            itemCount: _messages.length,
                            itemBuilder: (_, i) {
                              final m = _messages[_messages.length - 1 - i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${m.senderName}:',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w600)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: AppColors.bubbleOther,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                      child: Text(m.content),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                // Trái tim bay lên kiểu TikTok (bên góc dưới phải)
                Positioned(
                  right: 24,
                  bottom: 12,
                  child: IgnorePointer(
                    child: SizedBox(
                      width: 140,
                      height: 450,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.bottomCenter,
                        children: _hearts
                            .map((h) => _TikTokHeartWidget(
                                  key: ValueKey(h.id),
                                  data: h,
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ),
                // Hiệu ứng quà tặng nổi bật giữa màn hình
                if (_activeGifts.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _activeGifts
                              .map((g) => _GiftBannerWidget(
                                    key: ValueKey(g.id),
                                    data: g,
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppColors.surface,
              child: Row(
                children: [
                  IconButton(
                    tooltip: _micOn ? 'Tắt mic phòng' : 'Bật mic phòng',
                    icon: Icon(_micOn ? Icons.mic : Icons.mic_none,
                        color:
                            _micOn ? AppColors.accent : AppColors.textSecondary),
                    onPressed: () async {
                      if (!_micOn) {
                        if (!await ensureOnline(context, ref)) return;
                        setState(() => _micOn = true);
                        _socket.emit('room:rtc:join',
                            {'roomId': widget.room.id});
                      } else {
                        setState(() => _micOn = false);
                        _socket.emit('room:rtc:leave',
                            {'roomId': widget.room.id});
                        await _closeAllPeers();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.favorite, color: AppColors.accent),
                    onPressed: () async {
                      if (!await ensureOnline(context, ref)) return;
                      ref
                          .read(socketProvider)
                          .emit('room:heart', {'roomId': widget.room.id});
                      _spawnHeart(); // tim của mình hiện ngay
                    },
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.card_giftcard, color: AppColors.primary),
                    onPressed: () async {
                      if (!await ensureOnline(context, ref)) return;
                      await _loadRoomGifts();
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        hintText: 'Nhắn tin...',
                        filled: true,
                        fillColor: AppColors.bubbleOther,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primary),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingHeartData {
  _FloatingHeartData({
    required this.id,
    required this.emoji,
    required this.startX,
    required this.sway,
    required this.size,
    required this.durationMs,
  });
  final String id;
  final String emoji;
  final double startX;
  final double sway;
  final double size;
  final int durationMs;
}

class _TikTokHeartWidget extends StatelessWidget {
  const _TikTokHeartWidget({super.key, required this.data});
  final _FloatingHeartData data;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: data.durationMs),
      curve: Curves.easeOutCubic,
      builder: (_, value, child) {
        // Lượn sóng sin sang 2 bên
        final dx = data.startX + math.sin(value * math.pi * 3) * data.sway;
        final dy = -360.0 * value;
        // Fade out ở 35% chặng cuối
        final opacity =
            value < 0.65 ? 1.0 : ((1.0 - value) / 0.35).clamp(0.0, 1.0);
        // Scale nở to lúc mới sinh ra rồi ổn định
        final scale = value < 0.2 ? (0.4 + value * 3.5) : 1.1;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: child,
            ),
          ),
        );
      },
      child: Text(
        data.emoji,
        style: TextStyle(
          fontSize: data.size,
          shadows: const [
            Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
  }
}

class _GiftAnimationData {
  _GiftAnimationData({
    required this.id,
    required this.fromName,
    required this.fromAvatar,
    required this.giftEmoji,
  });
  final String id;
  final String fromName;
  final String? fromAvatar;
  final String giftEmoji;
}

class _GiftBannerWidget extends StatelessWidget {
  const _GiftBannerWidget({super.key, required this.data});
  final _GiftAnimationData data;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 3000),
      curve: Curves.easeInOutBack,
      builder: (_, value, child) {
        // Vào từ 0 -> 0.15: Scale phóng to đàn hồi
        // Giữ nguyên từ 0.15 -> 0.8
        // Ra từ 0.8 -> 1.0: Bay lên nhẹ và mờ dần
        double scale = 1.0;
        double opacity = 1.0;
        double dy = 0.0;

        if (value < 0.15) {
          final t = value / 0.15;
          scale = 0.3 + 0.7 * Curves.easeOutBack.transform(t);
          opacity = t.clamp(0.0, 1.0);
        } else if (value > 0.8) {
          final t = (value - 0.8) / 0.2;
          opacity = (1.0 - t).clamp(0.0, 1.0);
          dy = -50.0 * Curves.easeIn.transform(t);
          scale = 1.0 - 0.2 * t;
        }

        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFF5E7E),
              Color(0xFFA124F2),
              Color(0xFF6C5CE7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white70, width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5E7E).withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAvatar(avatar: data.fromAvatar ?? '', size: 48),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.fromName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'vừa gửi quà cho cả phòng!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Text(
              data.giftEmoji,
              style: const TextStyle(
                fontSize: 48,
                shadows: [
                  Shadow(
                      color: Colors.black38,
                      blurRadius: 10,
                      offset: Offset(0, 3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
