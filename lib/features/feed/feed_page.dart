import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dating_app/core/constants/app_config.dart';
import 'package:dating_app/core/network/connectivity_service.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/api/api_client.dart';
import 'package:dating_app/data/api/socket_client.dart';
import 'package:dating_app/data/models/models.dart';
import 'package:dating_app/data/repositories/auth_repository.dart';
import 'package:dating_app/data/repositories/chat_repository.dart';
import 'package:dating_app/shared/widgets/app_widgets.dart';
import 'package:dating_app/features/feed/create_post_page.dart';
import 'package:dating_app/features/profile/public_profile_page.dart';

class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng tin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CreatePostPage())),
          ),
        ],
      ),
      body: posts.isEmpty
          ? const EmptyState(message: 'Chưa có bài viết nào', emoji: '📭')
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.read(feedProvider.notifier).load(),
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  // Gần cuối trang -> tải thêm bài cũ
                  if (n.metrics.extentAfter < 400) {
                    ref.read(feedProvider.notifier).loadMore();
                  }
                  return false;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: posts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _PostCard(post: posts[i]),
                ),
              ),
            ),
    );
  }
}

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post});
  final PostModel post;

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(currentUserProvider).id;
    final isMine = post.userId == myId;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _openProfile(context),
                child: AppAvatar(avatar: post.userAvatar, size: 44),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openProfile(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _timeAgo(post.createdAt),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isMine)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onSelected: (v) {
                    if (v == 'edit') {
                      _editPost(context, ref);
                    } else {
                      _deletePost(context, ref);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Sửa bài viết')),
                    PopupMenuItem(value: 'delete', child: Text('Xóa bài viết')),
                  ],
                ),
            ],
          ),
          if (post.originalPost != null) ...[
            if (post.repostCaption.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                post.repostCaption,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
            const SizedBox(height: 10),
            _OriginalPostCard(post: post.originalPost!),
          ] else if (post.content != null && post.content!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              post.content!,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
          if (post.originalPost == null && post.media.isNotEmpty) ...[
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: post.media.length == 1 ? 1 : 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: post.media.map(_mediaTile).toList(),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              _Action(
                icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
                color: post.likedByMe
                    ? AppColors.accent
                    : AppColors.textSecondary,
                label: '${post.likes}',
                onTap: () async {
                  if (!await ensureOnline(context, ref)) return;
                  ref.read(feedProvider.notifier).toggleLike(post.id);
                },
              ),
              _Action(
                icon: Icons.comment_outlined,
                label: '${post.comments}',
                onTap: () => _showComments(context, ref),
              ),
              _Action(
                icon: Icons.share_outlined,
                label: '${post.shares}',
                onTap: () => _showShareOptions(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showShareOptions(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.ios_share, color: AppColors.primary),
              title: const Text('Chia sẻ ra ứng dụng khác'),
              onTap: () => Navigator.pop(sheetContext, 'external'),
            ),
            ListTile(
              leading: const Icon(Icons.repeat, color: AppColors.primary),
              title: const Text('Đăng lại lên Feed'),
              onTap: () => Navigator.pop(sheetContext, 'repost'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (!await ensureOnline(context, ref) || !context.mounted) return;
    if (action == 'external') {
      // Link này định danh bài trong app; trang web public/deep link sẽ được bổ sung riêng.
      final url = '${AppConfig.apiBaseUrl}/feed/${post.id}';
      final text = [
        if ((post.content ?? '').trim().isNotEmpty) post.content!.trim(),
        'Bài viết của ${post.userName} trên SoulMate: $url',
      ].join('\n\n');
      final box = context.findRenderObject() as RenderBox?;
      try {
        final result = await SharePlus.instance.share(
          ShareParams(
            text: text,
            title: 'Chia sẻ bài viết',
            sharePositionOrigin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          ),
        );
        // SharePlus trả thành công khi share sheet hoàn tất; dismissed/cancelled không tính lượt.
        if (!context.mounted || result.status != ShareResultStatus.success) {
          return;
        }
        final error = await ref
            .read(feedProvider.notifier)
            .sharePost(post.id, confirmed: true);
        if (error != null && context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error)));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không mở được bảng chia sẻ')),
          );
        }
      }
      return;
    }

    final captionController = TextEditingController();
    final caption = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng lại bài viết'),
        content: TextField(
          controller: captionController,
          autofocus: true,
          maxLines: 3,
          maxLength: 280,
          decoration: const InputDecoration(hintText: 'Thêm lời nhắn...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, captionController.text.trim()),
            child: const Text('Đăng lại'),
          ),
        ],
      ),
    );
    captionController.dispose();
    if (caption == null || !context.mounted) return;
    final error = await ref
        .read(feedProvider.notifier)
        .sharePost(post.id, repostContent: caption, createRepost: true);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void _openProfile(BuildContext context) {
    if (post.userId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PublicProfilePage(userId: post.userId)),
    );
  }

  Widget _mediaTile(String e) {
    if (isNetworkAvatar(e)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          AppConfig.absoluteUrl(e),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: AppColors.bubbleOther,
            alignment: Alignment.center,
            child: const Text('🖼️', style: TextStyle(fontSize: 40)),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bubbleOther,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(e, style: const TextStyle(fontSize: 48)),
    );
  }

  Future<void> _editPost(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: post.content ?? '');
    final newText = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sửa bài viết'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Nội dung...'),
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
    if (newText == null || !context.mounted) return;
    if (newText.isEmpty && post.media.isEmpty) return;
    if (!await ensureOnline(context, ref)) return;
    if (!context.mounted) return;
    try {
      final data = await ref
          .read(apiClientProvider)
          .patch('/api/feed/${post.id}', data: {'content': newText});
      final updated = PostModel.fromJson(data['post'] as Map<String, dynamic>);
      ref.read(feedProvider.notifier).updatePost(updated);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _deletePost(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa bài viết?'),
        content: const Text('Bài viết sẽ bị xóa vĩnh viễn.'),
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
    if (confirm != true || !context.mounted) return;
    if (!await ensureOnline(context, ref)) return;
    if (!context.mounted) return;
    try {
      await ref.read(apiClientProvider).delete('/api/feed/${post.id}');
      ref.read(feedProvider.notifier).removePost(post.id);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _showComments(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // Không bọc padding theo bàn phím ở đây: builder chỉ chạy lúc mở sheet,
      // nên viewInsets lúc đó bằng 0 và ô nhập sẽ nằm dưới bàn phím.
      // Việc né bàn phím được xử lý bên trong _CommentsSheet (nơi rebuild theo MediaQuery).
      builder: (_) => _CommentsSheet(postId: post.id),
    );
  }
}

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.postId});
  final String postId;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

/// Quản lý tải/gửi/sửa/xóa comment và áp dụng event realtime cho post đang mở.
class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _controller = TextEditingController();
  final _listController = ScrollController();
  final List<StreamSubscription<dynamic>> _commentSubscriptions = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(commentsProvider(widget.postId).notifier).load(),
    );

    final socket = ref.read(socketProvider);
    _commentSubscriptions.add(
      socket.on('feed:comment:new').listen((data) {
        if (!mounted) return;
        final raw = (data as Map?)?['comment'];
        if (raw is! Map || raw['postId'] != widget.postId) return;
        final comment = CommentModel.fromJson(Map<String, dynamic>.from(raw));
        ref.read(commentsProvider(widget.postId).notifier).applyAdded(comment);
        _scrollToLatest();
      }),
    );
    _commentSubscriptions.add(
      socket.on('feed:comment:updated').listen((data) {
        if (!mounted) return;
        final raw = (data as Map?)?['comment'];
        if (raw is! Map || raw['postId'] != widget.postId) return;
        ref
            .read(commentsProvider(widget.postId).notifier)
            .applyUpdated(
              CommentModel.fromJson(Map<String, dynamic>.from(raw)),
            );
      }),
    );
    _commentSubscriptions.add(
      socket.on('feed:comment:deleted').listen((data) {
        if (!mounted) return;
        final map = data as Map?;
        if (map?['postId'] != widget.postId) return;
        final id = map?['commentId'];
        if (id is String) {
          ref.read(commentsProvider(widget.postId).notifier).applyDeleted(id);
        }
      }),
    );
  }

  @override
  void dispose() {
    for (final subscription in _commentSubscriptions) {
      subscription.cancel();
    }
    _listController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_listController.hasClients) return;
      _listController.animateTo(
        _listController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  /// Đọc nội dung đang gõ rồi lưu qua repository; socket/HTTP đồng bộ danh sách.
  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitting) return;
    if (!await ensureOnline(context, ref)) return;
    if (!mounted) return;
    setState(() => _submitting = true);
    final error = await ref
        .read(commentsProvider(widget.postId).notifier)
        .add(text);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error == null) {
      _controller.clear();
      _scrollToLatest();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<String?> _editDialog(String initial) async {
    final ctrl = TextEditingController(text: initial);
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sửa bình luận'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          maxLength: 500,
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
    ctrl.dispose();
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(commentsProvider(widget.postId));
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    // Bottom sheet luôn neo ở đáy màn hình, nên chỉ giảm chiều cao là chưa đủ:
    // phải đẩy toàn bộ nội dung lên đúng bằng chiều cao bàn phím để ô nhập
    // luôn nằm phía trên bàn phím. Đặt padding bên trong sheet để nó cập nhật
    // lại mỗi khi bàn phím mở/đóng.
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SizedBox(
        height: (media.size.height - keyboardInset) * 0.9,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Bình luận',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: comments.when(
                loading: () => const LoadingWidget(),
                error: (_, _) => const EmptyState(
                  message: 'Không tải được bình luận',
                  emoji: '😕',
                ),
                data: (list) => list.isEmpty
                    ? const EmptyState(
                        message: 'Chưa có bình luận nào',
                        emoji: '💬',
                      )
                    : ListView.builder(
                        controller: _listController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final c = list[i];
                          final myId = ref.watch(currentUserProvider).id;
                          final isMine = c.userId == myId;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppAvatar(avatar: c.userAvatar, size: 34),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.userName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        c.content,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isMine)
                                  PopupMenuButton<String>(
                                    icon: const Icon(
                                      Icons.more_vert,
                                      size: 18,
                                      color: AppColors.textSecondary,
                                    ),
                                    onSelected: (v) async {
                                      final notifier = ref.read(
                                        commentsProvider(widget.postId)
                                            .notifier,
                                      );
                                      if (v == 'edit') {
                                        final text = await _editDialog(
                                          c.content,
                                        );
                                        if (text == null || text.isEmpty) {
                                          return;
                                        }
                                        final error = await notifier.edit(
                                          c,
                                          text,
                                        );
                                        if (error != null && context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                SnackBar(content: Text(error)),
                                              );
                                        }
                                      } else {
                                        final error = await notifier.remove(c);
                                        if (error != null && context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                SnackBar(content: Text(error)),
                                              );
                                        }
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Sửa bình luận'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Xóa bình luận'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
            Container(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 8,
                bottom: MediaQuery.of(context).padding.bottom + 8,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Viết bình luận...',
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
                        counterText: '',
                      ),
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hiển thị nội dung bài gốc được trích dẫn trong một bài repost.
class _OriginalPostCard extends StatelessWidget {
  const _OriginalPostCard({required this.post});
  final OriginalPostModel post;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bubbleOther,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(avatar: post.userAvatar, size: 30),
              const SizedBox(width: 8),
              Text(
                post.userName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if ((post.content ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(post.content!, maxLines: 5, overflow: TextOverflow.ellipsis),
          ],
          if (post.media.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: post.media.length == 1
                  ? _OriginalMedia(url: post.media.first)
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: post.media.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, index) => SizedBox(
                        width: 150,
                        child: _OriginalMedia(url: post.media[index]),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OriginalMedia extends StatelessWidget {
  const _OriginalMedia({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (!isNetworkAvatar(url)) {
      return Center(child: Text(url, style: const TextStyle(fontSize: 44)));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        AppConfig.absoluteUrl(url),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Center(child: Text('🖼️')),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
