import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/constants/app_config.dart';
import 'package:dating_app/core/network/connectivity_service.dart';
import 'package:dating_app/core/network/outbox.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/api/api_client.dart';
import 'package:dating_app/data/api/socket_client.dart';
import 'package:dating_app/data/models/models.dart';
import 'package:dating_app/data/repositories/auth_repository.dart';
import 'package:dating_app/data/repositories/chat_repository.dart';
import 'package:dating_app/shared/image_tools.dart';
import 'package:dating_app/shared/widgets/app_widgets.dart';
import 'package:dating_app/features/call/call_page.dart';

/// Màn hình chat 1-1.
/// Luồng chính: tải lịch sử -> nghe socket cho tin mới/sửa/xóa/typing -> gửi tin.
/// Tin gửi lỗi được đưa vào outbox để tự gửi lại khi có mạng; cuộn lên đầu
/// sẽ nạp thêm tin cũ và giữ nguyên vị trí đang đọc.
class ChatDetailPage extends ConsumerStatefulWidget {
  final String conversationId;
  final String partnerId;
  final String partnerName;
  final String partnerAvatar;

  const ChatDetailPage({
    super.key,
    required this.conversationId,
    required this.partnerId,
    required this.partnerName,
    required this.partnerAvatar,
  });

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _typingHideTimer;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _partnerTyping = false;

  @override
  void initState() {
    super.initState();
    // ===== Tải lịch sử và đánh dấu đã đọc =====
    final notifier = ref.read(messagesProvider(widget.conversationId).notifier);
    notifier.load();
    // Pushing this route can happen while the previous page is building. Defer
    // the shared chat-list provider update until the first frame has completed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(chatProvider.notifier).clearUnread(widget.conversationId);
    });

    // ===== Đồng bộ tin nhắn realtime =====
    final socket = ref.read(socketProvider);
    final myId = ref.read(currentUserProvider).id;

    // Server echo lại cả tin mình gửi, nhờ vậy bản optimistic được thay bằng bản thật.
    _subs.add(
      socket.on('chat:message').listen((data) {
        if (!mounted) return;
        final map = (data as Map).cast<String, dynamic>();
        if (map['conversationId'] != widget.conversationId) return;
        final payload = MessagesNotifier.parseSocketPayload(map);
        ref
            .read(messagesProvider(widget.conversationId).notifier)
            .applyIncoming(payload);
        if (payload.message.senderId != myId) {
          ref.read(chatProvider.notifier).clearUnread(widget.conversationId);
        }
      }),
    );

    _subs.add(
      socket.on('chat:message-edited').listen((data) {
        if (!mounted) return;
        final map = data as Map;
        if (map['conversationId'] != widget.conversationId) return;
        ref
            .read(messagesProvider(widget.conversationId).notifier)
            .applyEdited(
              map['messageId'] as String? ?? '',
              map['content'] as String? ?? '',
            );
      }),
    );

    _subs.add(
      socket.on('chat:message-deleted').listen((data) {
        if (!mounted) return;
        final map = data as Map;
        if (map['conversationId'] != widget.conversationId) return;
        ref
            .read(messagesProvider(widget.conversationId).notifier)
            .applyDeleted(map['messageId'] as String? ?? '');
      }),
    );

    // ===== Trạng thái "đang gõ" =====
    // Tự tắt sau 3 giây nếu không nhận thêm sự kiện, tránh treo chữ "đang gõ...".
    _subs.add(
      socket.on('chat:typing').listen((data) {
        if (!mounted) return;
        final map = data as Map;
        if (map['conversationId'] != widget.conversationId) return;
        if (map['from'] == myId) return;
        setState(() => _partnerTyping = true);
        _typingHideTimer?.cancel();
        _typingHideTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _partnerTyping = false);
        });
      }),
    );

    _scrollController.addListener(_onScroll);
  }

  /// Cuộn gần đầu danh sách thì nạp thêm tin cũ.
  /// Sau khi chèn tin vào đầu, bù lại scroll offset để màn hình không bị nhảy.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels > 200) return;
    final notifier = ref.read(messagesProvider(widget.conversationId).notifier);
    if (!notifier.hasMore || notifier.isLoadingMore) return;
    final oldMax = _scrollController.position.maxScrollExtent;
    notifier.loadMore().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final delta = _scrollController.position.maxScrollExtent - oldMax;
        if (delta > 0) {
          _scrollController.jumpTo(_scrollController.position.pixels + delta);
        }
      });
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _typingHideTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Gửi tín hiệu "đang gõ" tối đa 2 giây một lần để không spam socket.
  void _notifyTyping() {
    final text = _controller.text;
    final now = DateTime.now();
    if (text.isEmpty ||
        now.difference(_lastTypingSent) < const Duration(seconds: 2)) {
      return;
    }
    _lastTypingSent = now;
    ref.read(socketProvider).emit('chat:typing', {
      'conversationId': widget.conversationId,
    });
  }

  /// Gửi tin: xóa ô nhập ngay, gửi qua repository; thất bại thì đưa vào outbox
  /// để tự động gửi lại khi mạng trở lại.
  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (!await ensureOnline(context, ref)) return;
    if (!mounted) return;
    _controller.clear();

    final notifier = ref.read(messagesProvider(widget.conversationId).notifier);
    final ok = await notifier.send(text);
    if (ok) {
      ref.read(chatProvider.notifier).applySent(widget.conversationId, text);
    } else {
      // Giữ tin trong hàng đợi offline -> tự gửi lại khi có mạng
      await ref.read(outboxProvider).enqueue(widget.conversationId, text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mất kết nối — tin nhắn sẽ tự gửi lại khi có mạng'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  /// Chọn ảnh -> nén/upload -> gửi tin loại image; ảnh dùng URL do server trả về.
  Future<void> _sendImage() async {
    if (!await ensureOnline(context, ref)) return;
    if (!mounted) return;
    try {
      final url = await pickAndUploadImage(ref, maxWidth: 1280, quality: 80);
      if (url == null || !mounted) return;
      final notifier = ref.read(
        messagesProvider(widget.conversationId).notifier,
      );
      final ok = await notifier.send(url, type: MessageType.image);
      if (ok) {
        ref.read(chatProvider.notifier).applySent(widget.conversationId, url);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gửi ảnh thất bại'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _editMessage(MessageModel m) async {
    final ctrl = TextEditingController(text: m.content);
    final newText = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sửa tin nhắn'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Nội dung mới...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
            child: const Text(
              'Lưu',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
    if (newText == null || newText.isEmpty || newText == m.content) return;
    if (!mounted) return;
    if (!await ensureOnline(context, ref)) return;
    if (!mounted) return;
    try {
      final data = await ref
          .read(apiClientProvider)
          .patch(
            '/api/conversations/${widget.conversationId}/messages/${m.id}',
            data: {'content': newText},
          );
      final updated = MessageModel.fromJson(
        data['message'] as Map<String, dynamic>,
      );
      ref
          .read(messagesProvider(widget.conversationId).notifier)
          .applyEdited(updated.id, updated.content);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _deleteMessage(MessageModel m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa tin nhắn?'),
        content: const Text('Tin nhắn sẽ bị xóa phía bạn và đối phương.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    if (!await ensureOnline(context, ref)) return;
    if (!mounted) return;
    try {
      final data = await ref
          .read(apiClientProvider)
          .delete(
            '/api/conversations/${widget.conversationId}/messages/${m.id}',
          );
      ref
          .read(messagesProvider(widget.conversationId).notifier)
          .applyDeleted((data['id'] as String?) ?? m.id);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _showMessageActions(MessageModel m, bool isMine) {
    if (!isMine) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.primary),
              title: const Text('Sửa tin nhắn'),
              onTap: () {
                Navigator.pop(context);
                _editMessage(m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Xóa tin nhắn'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(m);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(MessageModel m, bool isMine, String myId) {
    final content = m.type == MessageType.image
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 220,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(
                  AppConfig.absoluteUrl(m.content),
                  fit: BoxFit.cover,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) {
                          return child;
                        }
                        return const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                  errorBuilder: (_, error, _) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textSecondary,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),
          )
        : Text(
            m.content,
            style: TextStyle(
              color: isMine ? Colors.white : AppColors.textPrimary,
              fontSize: 15,
            ),
          );

    return GestureDetector(
      onLongPress: () => _showMessageActions(m, isMine),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: EdgeInsets.symmetric(
            horizontal: m.type == MessageType.image ? 6 : 14,
            vertical: m.type == MessageType.image ? 6 : 10,
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          decoration: BoxDecoration(
            color: isMine ? AppColors.bubbleMine : AppColors.bubbleOther,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
          ),
          child: content,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.conversationId));
    final myId = ref.watch(currentUserProvider).id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            AppAvatar(avatar: widget.partnerAvatar, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.partnerName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_partnerTyping)
                    const Text(
                      'đang gõ...',
                      style: TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Cả bạn bè lẫn người lạ dùng cùng CallPage; server kiểm tra trạng thái online/bận.
          IconButton(
            tooltip: 'Gọi thoại',
            icon: const Icon(Icons.call, color: AppColors.primary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CallPage(
                    peerId: widget.partnerId,
                    partnerName: widget.partnerName,
                    partnerAvatar: widget.partnerAvatar,
                    isVideo: false,
                    callId: 'call_${DateTime.now().millisecondsSinceEpoch}',
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Gọi video',
            icon: const Icon(Icons.videocam, color: AppColors.primary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CallPage(
                    peerId: widget.partnerId,
                    partnerName: widget.partnerName,
                    partnerAvatar: widget.partnerAvatar,
                    isVideo: true,
                    callId: 'call_${DateTime.now().millisecondsSinceEpoch}',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const EmptyState(
                    message: 'Hãy bắt đầu trò chuyện',
                    emoji: '💬',
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final m = messages[index];
                      final isMine = m.senderId == myId;
                      return _buildBubble(m, isMine, myId);
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            color: AppColors.surface,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.photo_outlined,
                    color: AppColors.primary,
                  ),
                  onPressed: _sendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: (_) => _notifyTyping(),
                    decoration: InputDecoration(
                      hintText: 'Nhắn tin...',
                      filled: true,
                      fillColor: AppColors.bubbleOther,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
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
