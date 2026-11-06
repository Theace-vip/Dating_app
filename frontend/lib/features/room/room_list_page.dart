// room_list_page.dart — Danh sách phòng tiệc.
//
// Vai trò: tải /api/rooms, hiển thị số người trong từng phòng, cho phép tạo
// phòng mới và tự cập nhật khi có rooms:changed.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/network/connectivity_service.dart';
import 'package:dating_app/data/api/socket_client.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/api/api_client.dart';
import 'package:dating_app/data/models/models.dart';
import 'package:dating_app/data/repositories/chat_repository.dart';
import 'package:dating_app/shared/widgets/app_widgets.dart';
import 'package:dating_app/features/room/room_detail_page.dart';

// Danh sách phòng đang mở.
class RoomListPage extends ConsumerStatefulWidget {
  const RoomListPage({super.key});

  @override
  ConsumerState<RoomListPage> createState() => _RoomListPageState();
}

/// Tải danh sách phòng và lắng nghe rooms:changed.
class _RoomListPageState extends ConsumerState<RoomListPage> {
  StreamSubscription<dynamic>? _roomsSub;

  // Tải danh sách và nghe rooms:changed.
  @override
  void initState() {
    super.initState();
    // Server phát `rooms:changed` khi có phòng mới hoặc số người online đổi,
    // nên danh sách phòng luôn đồng bộ realtime mà không cần kéo làm mới.
    _roomsSub = ref.read(socketProvider).on('rooms:changed').listen((_) {
      if (mounted) ref.read(roomsProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _roomsSub?.cancel();
    super.dispose();
  }

  // Lưới/danh sách phòng + nút tạo phòng.
  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(roomsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phòng tiệc'),
        actions: [
          IconButton(
            tooltip: 'Tạo phòng mới',
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateRoom(context, ref),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: rooms.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _RoomCard(room: rooms[i]),
      ),
    );
  }
}

// Hộp thoại tạo phòng mới.
Future<void> _showCreateRoom(BuildContext context, WidgetRef ref) async {
  final nameCtrl = TextEditingController();
  final topicCtrl = TextEditingController();
  String emoji = '🎉';

  final created = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Tạo phòng mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Tên phòng'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: topicCtrl,
              decoration: const InputDecoration(hintText: 'Chủ đề (không bắt buộc)'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['🎉', '🌙', '🎮', '🌿', '🎧', '📚', '🍕', '💜']
                  .map((e) => GestureDetector(
                        onTap: () => setDialogState(() => emoji = e),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: emoji == e
                                ? AppColors.accentSoft
                                : AppColors.bubbleOther,
                            border: emoji == e
                                ? Border.all(color: AppColors.primary)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(e,
                              style: const TextStyle(fontSize: 20)),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tạo',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    ),
  );

  if (created != true) return;
  if (!context.mounted) return;
  final name = nameCtrl.text.trim();
  if (name.length < 2) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tên phòng cần ít nhất 2 ký tự')));
    return;
  }
  if (!await ensureOnline(context, ref)) return;
  if (!context.mounted) return;
  try {
    final data = await ref.read(apiClientProvider).post('/api/rooms', data: {
      'name': name,
      'topic': topicCtrl.text.trim(),
      'backgroundEmoji': emoji,
    });
    final room = RoomModel.fromJson(data['room'] as Map<String, dynamic>);
    ref.read(roomsProvider.notifier).prepend(room);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã tạo phòng "${room.name}"')));
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

// Thẻ hiển thị một phòng và số người.
class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room});
  final RoomModel room;

  // Thẻ một phòng: ảnh bìa, tên phòng, số người đang ở.
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.bubbleOther,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(room.backgroundEmoji ?? '🎉',
                style: const TextStyle(fontSize: 36)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Chủ phòng: ${room.hostName}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ...room.memberAvatars.take(4).map((a) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: AppAvatar(avatar: a, size: 24),
                        )),
                    Text('${room.memberCount} tham gia',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Bắt buộc khống chế chiều rộng: AppButton dùng width=infinity,
          // đặt thẳng trong Row sẽ nuốt toàn bộ bề ngang, cột chữ bị bóp về 0
          // nên mỗi ký tự bị xếp thành 1 hàng.
          SizedBox(
            width: 108,
            child: AppButton(
              label: 'Tham gia',
              height: 38,
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => RoomDetailPage(room: room))),
            ),
          ),
        ],
      ),
    );
  }
}
