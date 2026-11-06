// room_detail_page.dart — Trong một phòng tiệc.
//
// Vai trò: chat trong phòng, thả tim bay, tặng quà (server trừ Xu rồi phát
// hiệu ứng cho cả phòng), bật mic nói chuyện qua WebRTC nhiều người, và
// hiển thị danh sách người đang trong phòng.

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
import 'package:dating_app/features/room/widgets/svga_gift_view.dart';

/// Màn hình phòng tiệc: chat nhóm, thành viên online, thả tim, gửi quà và mic.
/// Mic dùng WebRTC mesh: mỗi cặp thành viên có một [RtcSession] riêng, tín hiệu
/// SDP/ICE đi qua socket của phòng; server kiểm tra thành viên trước khi relay.
class RoomDetailPage extends ConsumerStatefulWidget {
  const RoomDetailPage({super.key, required this.room});
  final RoomModel room;

  @override
  ConsumerState<RoomDetailPage> createState() => _RoomDetailPageState();
}

/// Giữ tin nhắn phòng, các peer WebRTC, hiệu ứng tim/quà và thành viên.
class _RoomDetailPageState extends ConsumerState<RoomDetailPage> {
  final List<RoomMessageModel> _messages = [];
  final List<_FloatingHeartData> _hearts = [];
  final List<_GiftAnimationData> _activeGifts = [];
  final math.Random _random = math.Random();
  final _ctrl = TextEditingController();
  bool _micOn = false; // mic THẬT trong phòng (WebRTC mesh)
  bool _speakerOn = true; // Loa phòng (mặc định bật)
  bool _loading = true;
  bool _giftCatalogLoading = false;
  List<RoomGiftOption> _roomGifts = const [];

  // Các kết nối WebRTC tới từng thành viên đang mic (mesh)
  final Map<String, RtcSession> _rtcPeers = {};

  final List<StreamSubscription<dynamic>> _subs = [];
  late final SocketService _socket;

  // Join phòng, tải lịch sử, đăng ký sự kiện phòng và quà.
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
      // Server gửi kèm tên quà và đường dẫn asset SVGA; nếu thiếu thì tra lại
      // catalog đã tải để tìm animation tương ứng với id.
      var giftName = map['giftName']?.toString();
      var svgaAsset = map['svga']?.toString();
      var giftCost = (map['cost'] as num?)?.toInt() ?? 0;
      if (svgaAsset == null || svgaAsset.isEmpty || giftCost == 0) {
        for (final option in _roomGifts) {
          if (option.id == map['gift']?.toString()) {
            svgaAsset = (svgaAsset == null || svgaAsset.isEmpty)
                ? option.svga
                : svgaAsset;
            giftName ??= option.name;
            if (giftCost == 0) giftCost = option.cost;
            break;
          }
        }
      }
      if (svgaAsset == null || svgaAsset.isEmpty) return;
      _triggerGiftEffect(
        fromName: fromName,
        fromAvatar: fromAvatar,
        giftName: giftName ?? 'Quà',
        svgaAsset: svgaAsset,
        cost: giftCost,
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
      await session.setSpeaker(_speakerOn);
    } catch (_) {
      _closePeer(peerId);
    }
  }

  // Đóng kết nối với một người.
  Future<void> _closePeer(String peerId) async {
    final s = _rtcPeers.remove(peerId);
    await s?.dispose();
  }

  // Đóng mọi kết nối thoại khi rời phòng.
  Future<void> _closeAllPeers() async {
    final sessions = Map<String, RtcSession>.of(_rtcPeers);
    _rtcPeers.clear();
    for (final s in sessions.values) {
      await s.dispose();
    }
  }

  // Tải tin nhắn cũ của phòng.
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

  // Thêm tin nhắn vào danh sách và cuộn xuống.
  void _addMessage(RoomMessageModel msg) {
    if (_messages.any((m) => m.id == msg.id)) return;
    setState(() => _messages.add(msg));
  }

  // Tạo hiệu ứng tim bay khi có người thả tim.
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

  // Xếp hàng phát animation quà (quà lớn phát nhiều vòng).
  void _triggerGiftEffect({
    required String fromName,
    required String? fromAvatar,
    required String giftName,
    required String svgaAsset,
    int cost = 0,
  }) {
    // Quà trên 100 Xu chạy thêm 2 vòng nữa (tổng 3 lần) cho hoành tráng hơn.
    final plays = cost > 100 ? 3 : 1;
    final gift = _GiftAnimationData(
      id: UniqueKey().toString(),
      fromName: fromName,
      fromAvatar: fromAvatar,
      giftName: giftName,
      svgaAsset: svgaAsset,
      cost: cost,
      plays: plays,
    );
    // Giữ tối đa 3 banner để nhiều người tặng liên tiếp không làm tràn màn hình.
    setState(() {
      _activeGifts.removeRange(0, math.max(0, _activeGifts.length - 2));
      _activeGifts.add(gift);
    });
    // Dự phòng: nếu animation không báo xong thì vẫn dọn banner. Quà 3 vòng ở
    // tốc độ 0,7 mất khoảng 17s nên hạn này phải rộng hơn hẳn.
    Future.delayed(Duration(seconds: 12 * plays + 8), () {
      if (mounted && _activeGifts.contains(gift)) {
        setState(() => _activeGifts.remove(gift));
      }
    });
  }

  // Dọn hiệu ứng quà đã phát xong.
  void _dismissGift(_GiftAnimationData gift) {
    if (!mounted) return;
    setState(() => _activeGifts.remove(gift));
  }

  // Gửi tin nhắn trong phòng.
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

  // Lấy danh sách quà và giá từ catalog server.
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

  // Mở bảng chọn quà.
  void _showGifts() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // isScrollControlled để sheet không bị giới hạn 9/16 chiều cao màn hình;
      // nội dung vẫn co theo danh sách quà và cuộn được khi màn hình thấp.
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _roomGifts.isEmpty ? 'Danh sách quà trống' : 'Gửi quà',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                // Chiều cao ô cố định: GridView.count ép ô vuông nên trên cửa sổ
                // rộng mỗi hàng cao bằng 1/4 bề ngang và làm tràn sheet.
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisExtent: 108,
                ),
                itemCount: _roomGifts.length,
                itemBuilder: (_, i) {
                  final gift = _roomGifts[i];
                  return InkWell(
                    onTap: () {
                      Navigator.pop(sheetContext);
                      // Server kiểm tra id quà, số dư và trừ Xu trước khi phát broadcast.
                      _socket.emit('room:gift', {
                        'roomId': widget.room.id,
                        'gift': gift.id,
                      });
                    },
                    // Xem trước chính animation sẽ phát trong phòng.
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgaGiftView(asset: gift.svga, size: 64, loop: true),
                        const SizedBox(height: 4),
                        Text(
                          '${gift.cost} Xu',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
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

  // Giao diện phòng: tin nhắn, thành viên, nút quà/mic/tim.
  @override
  Widget build(BuildContext context) {
    // Phòng cập nhật realtime (số thành viên...) qua roomsProvider
    final rooms = ref.watch(roomsProvider);
    final room = rooms.firstWhere(
      (r) => r.id == widget.room.id,
      orElse: () => widget.room,
    );

    final content = Scaffold(
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
                // Hiệu ứng quà được vẽ ở lớp phủ toàn màn hình bên dưới.
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
                    tooltip: _speakerOn ? 'Tắt loa phòng' : 'Bật loa phòng',
                    icon: Icon(_speakerOn ? Icons.volume_up : Icons.volume_off,
                        color: _speakerOn
                            ? AppColors.accent
                            : AppColors.textSecondary),
                    onPressed: () async {
                      setState(() => _speakerOn = !_speakerOn);
                      for (final s in _rtcPeers.values) {
                        await s.setSpeaker(_speakerOn);
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

    // Hiệu ứng quà vẽ ở lớp phủ ngoài Scaffold: phủ trọn cửa sổ (cả AppBar và
    // thanh nhập tin) và FittedBox tự thu nhỏ nên không bao giờ tràn khung.
    return Stack(
      children: [
        content,
        if (_activeGifts.isNotEmpty) _buildGiftOverlay(),
      ],
    );
  }

  // Lớp phủ phát animation quà toàn màn hình.
  Widget _buildGiftOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        // Material trong suốt để văn bản trong banner có style mặc định đúng.
        child: Material(
          type: MaterialType.transparency,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final artSize = math.min(
                (constraints.maxHeight - 110).clamp(88.0, 320.0),
                constraints.maxWidth,
              );
              return Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    // Bề rộng cố định để Row trong banner có ràng buộc ngang.
                    width: math.min(constraints.maxWidth, 380.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _activeGifts
                          .map((g) => _GiftBannerWidget(
                                key: ValueKey(g.id),
                                data: g,
                                artSize: artSize,
                                onFinished: () => _dismissGift(g),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Dữ liệu một trái tim đang bay.
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

// Trái tim bay theo kiểu TikTok.
class _TikTokHeartWidget extends StatelessWidget {
  const _TikTokHeartWidget({super.key, required this.data});
  final _FloatingHeartData data;

  // Vẽ một trái tim bay lên rồi mờ dần.
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

// Một hiệu ứng quà đang chờ/đang phát.
class _GiftAnimationData {
  _GiftAnimationData({
    required this.id,
    required this.fromName,
    required this.fromAvatar,
    required this.giftName,
    required this.svgaAsset,
    this.cost = 0,
    this.plays = 1,
  });
  final String id;
  final String fromName;
  final String? fromAvatar;
  final String giftName;
  final String svgaAsset;
  final int cost;

  /// Số vòng phát animation (quà trên 100 Xu phát 3 vòng).
  final int plays;
}

/// Tốc độ phát animation quà: 0.7 = chậm hơn bản gốc 30%.
const double _giftAnimationSpeed = 0.7;

// Khung phát một animation SVGA.
class _GiftBannerWidget extends StatefulWidget {
  const _GiftBannerWidget(
      {super.key,
      required this.data,
      required this.artSize,
      required this.onFinished});
  final _GiftAnimationData data;
  final double artSize;
  final VoidCallback onFinished;

  @override
  State<_GiftBannerWidget> createState() => _GiftBannerWidgetState();
}

/// Chạy hiệu ứng vào/ra của khung quà trước khi phát animation.
class _GiftBannerWidgetState extends State<_GiftBannerWidget>
    with TickerProviderStateMixin {
  // Tách thành hai controller thay cho một TweenAnimationBuilder cố định 3s:
  // quà nhiều vòng chạy lâu hơn, nên banner chỉ mờ dần khi animation thực sự
  // chạy xong (tránh việc banner biến mất giữa lúc quà còn đang phát).
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  _GiftAnimationData get data => widget.data;
  VoidCallback get onFinished => widget.onFinished;

  // Báo cho trang biết đã phát xong để dọn.
  Future<void> _handleAnimationDone() async {
    if (!mounted) return;
    await _exit.forward();
    if (mounted) onFinished();
  }

  @override
  void dispose() {
    _enter.dispose();
    _exit.dispose();
    super.dispose();
  }

  // Hiệu ứng vào/ra của khung quà trước khi phát animation.
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _exit]),
      builder: (context, child) {
        final enterT = _enter.value.clamp(0.0, 1.0);
        final exitT = _exit.value.clamp(0.0, 1.0);
        // Vào: phóng to đàn hồi theo easeOutBack (đã clamp t trong [0,1]).
        // Ra: bay lên nhẹ, thu nhỏ và mờ dần.
        final scale =
            (0.3 + 0.7 * Curves.easeOutBack.transform(enterT)) *
                (1.0 - 0.2 * exitT);
        final fade = Curves.easeIn.transform(exitT);
        final opacity = (enterT * (1.0 - fade)).clamp(0.0, 1.0);
        final dy = -50.0 * fade;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animation SVGA của quà, phát đủ số vòng rồi báo về phòng dọn banner.
          SvgaGiftView(
            asset: data.svgaAsset,
            size: widget.artSize,
            plays: data.plays,
            speed: _giftAnimationSpeed,
            onCompleted: _handleAnimationDone,
          ),
          Container(
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
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 4)
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'vừa tặng ${data.giftName} cho cả phòng!',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
