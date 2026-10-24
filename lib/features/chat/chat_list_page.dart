import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/api/socket_client.dart';
import 'package:dating_app/data/repositories/auth_repository.dart';
import 'package:dating_app/data/repositories/chat_repository.dart';
import 'package:dating_app/shared/widgets/app_widgets.dart';
import 'package:dating_app/features/chat/chat_detail_page.dart';
import 'package:dating_app/features/chat/friends_page.dart';
import 'package:dating_app/features/chat/search_users_page.dart';

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  StreamSubscription<dynamic>? _msgSub;
  StreamSubscription<dynamic>? _presenceSub;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(chatProvider.notifier).load();
    });
    // Tin nhắn đến realtime (kể cả tin mình vừa gửi từ màn khác/outbox)
    _msgSub = ref.read(socketProvider).on('chat:message').listen((data) {
      if (!mounted) return;
      final payload = MessagesNotifier.parseSocketPayload(
          (data as Map).cast<String, dynamic>());
      final conversationId = data['conversationId'] as String? ?? '';
      final currentId = ref.read(currentUserProvider).id;
      ref.read(chatProvider.notifier).applyIncoming(
            conversationId,
            payload.message,
            fromMe: payload.message.senderId == currentId,
          );
    });
    // Thay đổi trạng thái online/offline của bạn chat
    _presenceSub =
        ref.read(socketProvider).on('presence:changed').listen((data) {
      if (!mounted) return;
      final map = data as Map;
      ref.read(chatProvider.notifier).applyPresence(
            map['userId'] as String? ?? '',
            map['online'] == true,
          );
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _presenceSub?.cancel();
    super.dispose();
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút';
    if (diff.inHours < 24) return '${diff.inHours} giờ';
    return '${diff.inDays} ngày';
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(chatProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tin nhắn'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            tooltip: 'Tìm kiếm',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchUsersPage()),
            ),
          ),
          IconButton(
            tooltip: 'Bạn bè',
            icon: const Icon(Icons.people_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FriendsPage()),
            ),
          ),
        ],
      ),
      body: conversations.isEmpty
          ? const EmptyState(message: 'Chưa có cuộc trò chuyện nào', emoji: '💬')
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: conversations.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                indent: 76,
                color: AppColors.divider,
              ),
              itemBuilder: (context, index) {
                final c = conversations[index];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: AppAvatar(
                    avatar: c.partnerAvatar,
                    size: 56,
                    isOnline: c.isOnline,
                  ),
                  title: Text(
                    c.partnerName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      isNetworkAvatar(c.lastMessage)
                          ? '📷 Đã gửi ảnh'
                          : c.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTime(c.lastMessageAt),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      if (c.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${c.unreadCount}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        )
                      else
                        const SizedBox(height: 18),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatDetailPage(
                          conversationId: c.id,
                          partnerId: c.partnerId,
                          partnerName: c.partnerName,
                          partnerAvatar: c.partnerAvatar,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
