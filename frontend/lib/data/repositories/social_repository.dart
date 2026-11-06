// social_repository.dart — Dữ liệu bạn bè.
//
// Vai trò: tải /api/friends thành danh sách FriendEntry, và lắng nghe
// friends:changed để trang Bạn bè / trang Cá nhân cập nhật ngay khi có
// người mới kết bạn.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/data/api/api_client.dart';
import 'package:dating_app/data/api/socket_client.dart';
import 'package:dating_app/data/models/models.dart';

/// Một người bạn lấy từ bảng `friendships` trong database.
/// Không có danh sách mẫu: chưa kết bạn thì danh sách rỗng.
class FriendEntry {
  const FriendEntry({
    required this.user,
    this.conversationId,
    this.friendsSince,
  });

  final UserModel user;
  final String? conversationId;
  final DateTime? friendsSince;

  factory FriendEntry.fromJson(Map<String, dynamic> json) {
    return FriendEntry(
      user: UserModel.fromJson(json),
      conversationId: json['conversationId']?.toString(),
      friendsSince: DateTime.tryParse('${json['friendsSince'] ?? ''}'),
    );
  }
}

/// Nguồn duy nhất cho danh sách bạn bè trong app.
/// Dữ liệu lấy từ `GET /api/friends` và được làm mới mỗi khi server phát
/// `friends:changed` (khi hai bên vừa kết bạn qua Soul Game).
class FriendsNotifier extends StateNotifier<List<FriendEntry>> {
  FriendsNotifier(this._api) : super(const []);
  final ApiClient _api;

  bool _loading = false;
  bool get isLoading => _loading;

  // Tải danh sách bạn bè từ /api/friends.
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      final data = await _api.get('/api/friends');
      state = (data['friends'] as List)
          .map((e) => FriendEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Mất mạng: giữ danh sách cũ thay vì xoá trắng màn hình.
    } finally {
      _loading = false;
    }
  }
}

final friendsProvider =
    StateNotifierProvider<FriendsNotifier, List<FriendEntry>>(
  (ref) => FriendsNotifier(ref.watch(apiClientProvider)),
);

/// Giữ danh sách bạn bè đồng bộ realtime. Được watch một lần ở HomePage.
final socialRealtimeProvider = Provider<void>((ref) {
  final socket = ref.read(socketProvider);
  final friends = ref.read(friendsProvider.notifier);
  friends.load();

  final subs = <StreamSubscription<dynamic>>[
    socket.on('friends:changed').listen((_) => friends.load()),
    socket.on('conversations:changed').listen((_) => friends.load()),
  ];
  ref.onDispose(() {
    for (final s in subs) {
      s.cancel();
    }
  });
});
