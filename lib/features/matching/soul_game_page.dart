import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/network/connectivity_service.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/api/socket_client.dart';
import 'package:dating_app/data/models/models.dart';
import 'package:dating_app/data/repositories/chat_repository.dart';
import 'package:dating_app/data/repositories/catalog_repository.dart';
import 'package:dating_app/features/chat/chat_detail_page.dart';
import 'package:dating_app/shared/widgets/app_widgets.dart';

enum _SoulStatus { searching, matched, ended }

class SoulGamePage extends ConsumerStatefulWidget {
  const SoulGamePage({super.key});

  @override
  ConsumerState<SoulGamePage> createState() => _SoulGamePageState();
}

class _SoulGamePageState extends ConsumerState<SoulGamePage> {
  int _totalSeconds = 0;
  DateTime? _endsAt;
  int _remaining = 0;
  Timer? _timer;

  _SoulStatus _status = _SoulStatus.searching;
  String? _sessionId;
  // Đối phương ẩn danh: chỉ avatar/tuổi/giới tính cho tới khi hiện danh tính
  String _strangerAvatar = '🙂';
  final TextEditingController _controller = TextEditingController();
  final List<_ChatBubble> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final List<StreamSubscription<dynamic>> _subs = [];
  bool _leaving = false;
  bool _endSheetOpen = false;
  bool _heartAvailable = false;
  bool _liked = false;
  bool _likePending = false;
  bool _partnerLiked = false;
  SocketService? _socket;

  @override
  void initState() {
    super.initState();
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
      socket.on('soul:matched').listen((data) {
        if (!mounted) return;
        final map = data as Map;
        setState(() {
          _sessionId = map['sessionId'] as String?;
          _endsAt = DateTime.tryParse(map['endsAt']?.toString() ?? '');
          final stranger = (map['stranger'] ?? {}) as Map;
          _strangerAvatar = (stranger['avatar'] ?? '🙂').toString();
          _status = _SoulStatus.matched;
          _remaining = _totalSeconds;
          _messages.clear();
          _heartAvailable = false;
          _liked = false;
          _likePending = false;
          _partnerLiked = false;
          _leaving = false;
        });
        _startTimer();
      }),
    );

    _subs.add(
      socket.on('soul:message').listen((data) {
        if (!mounted) return;
        final map = data as Map;
        if (map['sessionId'] != _sessionId) return;
        setState(
          () => _messages.add(
            _ChatBubble(
              content: (map['content'] ?? '').toString(),
              isMine: false,
            ),
          ),
        );
        _scrollToBottom();
      }),
    );

    _subs.add(
      socket.on('soul:heart-available').listen((data) {
        if (!mounted) return;
        final map = data as Map;
        if (map['sessionId'] != _sessionId) return;
        setState(() => _heartAvailable = true);
      }),
    );

    _subs.add(
      socket.on('soul:like:sent').listen((data) {
        if (!mounted) return;
        final map = data as Map;
        if (map['sessionId'] != _sessionId) return;
        setState(() {
          _liked = true;
          _likePending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bạn đã gửi lời thích 💜')),
        );
      }),
    );

    _subs.add(
      socket.on('soul:like:received').listen((data) {
        if (!mounted) return;
        final map = data as Map;
        if (map['sessionId'] != _sessionId) return;
        setState(() => _partnerLiked = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đối phương đã thích bạn 💜')),
        );
      }),
    );

    _subs.add(
      socket.on('soul:like:error').listen((data) {
        if (!mounted) return;
        final map = data as Map;
        if (map['sessionId'] != _sessionId) return;
        setState(() => _likePending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa mở lượt thả tim — hãy trò chuyện thêm'),
          ),
        );
      }),
    );

    _subs.add(
      socket.on('soul:mutual-like').listen((data) {
        if (!mounted || _leaving) return;
        final map = (data as Map).cast<String, dynamic>();
        if (map['sessionId'] != _sessionId) return;
        final user = UserModel.fromJson(map['user'] as Map<String, dynamic>);
        final conversationId = map['conversationId'] as String?;
        _leaving = true;
        _timer?.cancel();
        ref.read(chatProvider.notifier).load();
        Future.microtask(() {
          if (!mounted) return;
          final navigator = Navigator.of(context);
          if (_endSheetOpen) navigator.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hai bạn đã thích nhau! Chat không giới hạn 💜'),
            ),
          );
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
      socket.on('soul:revealed').listen((data) {
        if (!mounted) return;
        final map = (data as Map).cast<String, dynamic>();
        final user = UserModel.fromJson(map['user'] as Map<String, dynamic>);
        final conversationId = map['conversationId'] as String?;
        if (_leaving) return;
        _leaving = true;
        _timer?.cancel();
        ref.read(chatProvider.notifier).load();
        Future.microtask(() {
          if (!mounted) return;
          final navigator = Navigator.of(context);
          if (_endSheetOpen) navigator.pop(); // đóng sheet
          navigator.pop(); // đóng Soul Game
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

    _subs.add(        socket.on('soul:time-ended').listen((data) {
          if (!mounted || (data as Map)['sessionId'] != _sessionId) return;
          _timer?.cancel();
          setState(() {
            _remaining = 0;
            _endsAt = null;
            _status = _SoulStatus.ended;
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
          _status = _SoulStatus.matched;
          _remaining = (map['durationSeconds'] as num?)?.toInt() ?? _totalSeconds;
          _endsAt = DateTime.tryParse(map['endsAt']?.toString() ?? '');
        });
        _startTimer();
        if (_endSheetOpen) Navigator.of(context).pop();
      }),
    );

    _subs.add(
      socket.on('soul:continue:error').listen((data) {
        if (!mounted || (data is Map && data['sessionId'] != _sessionId)) {
          return;
        }
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
      socket.on('soul:partner-left').listen((data) {
        if (!mounted || _leaving) return;
        _timer?.cancel();        setState(() {          _status = _SoulStatus.searching;
          _sessionId = null;
          _endsAt = null;
          _messages.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đối phương đã rời đi — đang tìm người mới...'),
          ),
        );
        socket.emit('soul:queue');
      }),
    );

    _subs.add(
      socket.on('connect').listen((connected) {
        // socket vừa reconnect -> vào lại hàng đợi để tiếp tục chơi
        if (connected == true &&
            mounted &&
            _status != _SoulStatus.matched &&
            !_leaving) {
          if (_totalSeconds > 0) socket.emit('soul:queue');
        }
      }),
    );

    // Chờ catalog từ server để dùng thời lượng ghép đôi do backend quản lý.
    Future.microtask(_loadOptionsAndQueue);
  }

  Future<void> _loadOptionsAndQueue() async {
    try {
      final catalog = await ref.read(appCatalogProvider.future);
      if (!mounted) return;
      setState(() {
        _totalSeconds = catalog.textSeconds;
        _remaining = _totalSeconds;
      });
      _socket?.emit('soul:queue');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tải được cấu hình từ máy chủ')),
      );
      Navigator.of(context).pop();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _status != _SoulStatus.matched) return;
      // Đồng hồ UI tính từ mốc hết hạn server gửi, không tự làm chủ thời lượng trận.
      final endsAt = _endsAt;
      final secondsLeft = endsAt == null
          ? (_remaining - 1).clamp(0, _totalSeconds)
          : endsAt.difference(DateTime.now()).inSeconds.clamp(0, _totalSeconds);
      setState(() => _remaining = secondsLeft);
      if (_remaining <= 0) {
        _timer?.cancel();
        _socket?.emit('soul:finish', {'sessionId': _sessionId});
        // Chỉ event soul:time-ended từ server mới chuyển trạng thái và mở bảng lựa chọn.
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sessionId == null) return;
    if (!await ensureOnline(context, ref)) return;
    setState(() {
      _messages.add(_ChatBubble(content: text, isMine: true));
      _controller.clear();
    });
    ref.read(socketProvider).emit('soul:message', {
      'sessionId': _sessionId,
      'content': text,
    });
    _scrollToBottom();
  }

  Future<void> _reveal() async {
    if (_sessionId == null) return;
    if (!await ensureOnline(context, ref)) return;
    if (!mounted) return;
    ref.read(socketProvider).emit('soul:reveal', {'sessionId': _sessionId});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đang yêu cầu hiện danh tính...')),
    );
  }

  Future<void> _like() async {
    if (_sessionId == null || !_heartAvailable || _liked || _likePending) {
      return;
    }
    if (!await ensureOnline(context, ref) || !mounted) return;
    final socket = ref.read(socketProvider);
    if (!socket.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mất kết nối máy chủ — vui lòng thử lại')),
      );
      return;
    }
    setState(() => _likePending = true);
    socket.emit('soul:like', {'sessionId': _sessionId});
  }

  Future<void> _continueChat() async {
    if (_sessionId == null || !await ensureOnline(context, ref)) return;
    if (!mounted) return;
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
    setState(() {
      _status = _SoulStatus.searching;
      _sessionId = null;
      _endsAt = null;
      _messages.clear();
      _remaining = _totalSeconds;
      _heartAvailable = false;
      _liked = false;
      _likePending = false;
      _partnerLiked = false;
      _leaving = false;
    });

    socket.emit('soul:queue');
    if (_endSheetOpen) Navigator.of(context).pop();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
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
            if (_heartAvailable) ...[
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _liked || _likePending ? null : _like,
                  icon: const Icon(Icons.favorite),
                  label: Text(
                    _liked
                        ? 'Bạn đã thả tim'
                        : _likePending
                        ? 'Đang gửi...'
                        : 'Thả tim người ấy',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
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
                if (_sessionId == null || !await ensureOnline(context, ref)) {
                  return;
                }
                if (!mounted) return;
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
    _socket?.emit('soul:leave');
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    const SizedBox(width: 8),
                    if (_status == _SoulStatus.matched) ...[
                      AppAvatar(avatar: _strangerAvatar, size: 44),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        switch (_status) {
                          _SoulStatus.searching => 'Đang tìm người...',
                          _SoulStatus.matched => 'Người lạ',
                          _SoulStatus.ended => 'Đã hết thời gian',
                        },
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_status == _SoulStatus.matched)
                      IconButton(
                        onPressed: _reveal,
                        icon: const Icon(Icons.visibility, color: Colors.white),
                        tooltip: 'Hiện danh tính',
                      ),
                    if (_status == _SoulStatus.matched)
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
                              '$_remaining',
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
              if (_status == _SoulStatus.searching) ...[
                const Spacer(),
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 24),
                const Text(
                  'Đang ghép bạn với người lạ...\n(Lập 2 điện thoại cùng chơi để test)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const Spacer(),
              ] else ...[
                if (_status == _SoulStatus.matched) ...[
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: _remaining / _totalSeconds,
                          strokeWidth: 6,
                          color: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                        ),
                        Text(
                          '$_remaining',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_heartAvailable)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ElevatedButton.icon(
                      onPressed: _liked || _likePending ? null : _like,
                      icon: Icon(
                        _liked ? Icons.favorite : Icons.favorite_border,
                      ),
                      label: Text(
                        _liked
                            ? 'Bạn đã thả tim'
                            : _likePending
                            ? 'Đang gửi...'
                            : 'Thả tim người ấy',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (_partnerLiked)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Đối phương đã thích bạn 💜',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'Hãy bắt đầu trò chuyện 💜',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final m = _messages[index];
                            return Align(
                              alignment: m.isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.72,
                                ),
                                decoration: BoxDecoration(
                                  color: m.isMine
                                      ? AppColors.bubbleMine
                                      : AppColors.bubbleOther,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  m.content,
                                  style: TextStyle(
                                    color: m.isMine
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  color: Colors.white.withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: _status == _SoulStatus.matched,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Nhắn tin ẩn danh...',
                            hintStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(
                          onPressed: _status == _SoulStatus.matched
                              ? _send
                              : null,
                          icon: const Icon(
                            Icons.send,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatBubble {
  final String content;
  final bool isMine;
  _ChatBubble({required this.content, required this.isMine});
}
