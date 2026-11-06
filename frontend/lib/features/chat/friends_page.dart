// friends_page.dart — Danh sách bạn bè.
//
// Vai trò: đọc friendsProvider để hiển thị bạn bè thật (tạo ra từ Soul Game),
// bấm vào một người để mở ngay cuộc trò chuyện.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/repositories/social_repository.dart';
import 'package:dating_app/shared/widgets/app_widgets.dart';
import 'package:dating_app/features/chat/chat_detail_page.dart';

/// Danh sách bạn bè — đọc từ [friendsProvider] (bảng `friendships`).
/// Danh sách tự cập nhật realtime nhờ `friends:changed`; không có dữ liệu mẫu,
/// chưa kết bạn thì hiện trạng thái rỗng.
class FriendsPage extends ConsumerStatefulWidget {
  const FriendsPage({super.key});

  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

/// Tải danh sách bạn bè khi mở trang.
class _FriendsPageState extends ConsumerState<FriendsPage> {
  // Tải danh sách bạn bè khi mở trang.
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(friendsProvider.notifier).load();
    });
  }

  void _openChat(FriendEntry f) {
    final conversationId = f.conversationId;
    if (conversationId == null || conversationId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          conversationId: conversationId,
          partnerId: f.user.id,
          partnerName: f.user.name,
          partnerAvatar: f.user.avatar,
        ),
      ),
    );
  }

  // Hiển thị danh sách hoặc trạng thái rỗng.
  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    final notifier = ref.read(friendsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('Bạn bè (${friends.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.load(),
          ),
        ],
      ),
      body: friends.isEmpty
          ? const EmptyState(
              message: 'Chưa có bạn bè — hãy chơi Trò chơi tâm giao để kết bạn',
              emoji: '💜',
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: notifier.load,
              child: ListView.separated(
                itemCount: friends.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 76),
                itemBuilder: (_, i) {
                  final f = friends[i];
                  return ListTile(
                    leading: AppAvatar(
                      avatar: f.user.avatar,
                      size: 52,
                      isOnline: f.user.isOnline,
                    ),
                    title: Text(
                      f.user.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    subtitle: Text(
                      'Kết bạn từ ${_formatDate(f.friendsSince)}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    trailing: const Icon(Icons.chat_bubble_outline,
                        color: AppColors.primary),
                    onTap: () => _openChat(f),
                  );
                },
              ),
            ),
    );
  }

  // Rút gọn ngày kết bạn để hiển thị.
  String _formatDate(DateTime? d) {
    if (d == null) return 'Soul Game';
    return '${d.day}/${d.month}/${d.year}';
  }
}
