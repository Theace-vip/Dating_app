import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/data/api/api_client.dart';
import 'package:dating_app/data/api/socket_client.dart';
import 'package:dating_app/data/models/models.dart';

// ===== Chat: danh sách hội thoại =====
class ChatNotifier extends StateNotifier<List<ConversationModel>> {
  ChatNotifier(this._api) : super(const []);
  final ApiClient _api;

  Future<bool> load() async {
    try {
      final data = await _api.get('/api/conversations');
      state = (data['conversations'] as List)
          .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cập nhật tin cuối khi người dùng vừa gửi (server cũng đã lưu).
  void applySent(String conversationId, String content) {
    state = [
      for (final c in state)
        if (c.id == conversationId)
          c.copyWithLast(content, DateTime.now())
        else
          c,
    ];
  }

  /// Tin nhắn đến realtime từ socket.
  void applyIncoming(
    String conversationId,
    MessageModel message, {
    bool fromMe = false,
  }) {
    final index = state.indexWhere((c) => c.id == conversationId);
    if (index < 0) {
      // Hội thoại mới (vd: sau khi kết bạn qua Soul Game) -> tải lại danh sách.
      // Socket events can arrive while Flutter is building a frame; wait until
      // the current synchronous callback/frame has completed before loading.
      Future<void>.delayed(Duration.zero, load);
      return;
    }
    var updated = state[index].copyWithLast(message.content, message.createdAt);
    if (!fromMe) {
      updated = updated.copyWithUnread(state[index].unreadCount + 1);
    }
    state = [
      for (final c in state)
        if (c.id == conversationId) updated else c,
    ];
  }

  void clearUnread(String conversationId) {
    state = [
      for (final c in state)
        if (c.id == conversationId) c.copyWithUnread(0) else c,
    ];
  }

  /// Cập nhật trạng thái online/offline của bạn chat từ sự kiện presence.
  void applyPresence(String userId, bool online) {
    state = [
      for (final c in state)
        if (c.partnerId == userId) c.copyWithOnline(online) else c,
    ];
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, List<ConversationModel>>(
      (ref) => ChatNotifier(ref.watch(apiClientProvider)),
    );

// ===== Tin nhắn 1-1 =====
class MessagesNotifier extends StateNotifier<List<MessageModel>> {
  MessagesNotifier(this._api, this.conversationId) : super(const []);
  final ApiClient _api;
  final String conversationId;

  static ChatSocketMessage parseSocketPayload(Map<String, dynamic> data) {
    return ChatSocketMessage(
      message: MessageModel.fromJson(data['message'] as Map<String, dynamic>),
      clientMessageId: data['clientMessageId'] as String?,
    );
  }

  Future<void> load() async {
    try {
      final data = await _api.get(
        '/api/conversations/$conversationId/messages',
      );
      _hasMore = data['hasMore'] == true;
      state = (data['messages'] as List)
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // giữ nguyên danh sách cũ nếu lỗi mạng
    }
  }

  bool _loadingMore = false;
  bool get hasMore => _hasMore;
  bool _hasMore = true;
  bool get isLoadingMore => _loadingMore;

  /// Tải thêm tin CŨ hơn (phân trang khi kéo lên đầu).
  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore || state.isEmpty) return;
    _loadingMore = true;
    try {
      final before = state.first.createdAt.toIso8601String();
      final data = await _api.get(
        '/api/conversations/$conversationId/messages',
        query: {'before': before, 'limit': 50},
      );
      _hasMore = data['hasMore'] == true;
      final older = (data['messages'] as List)
          .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = [...older, ...state];
    } catch (_) {
      // giữ nguyên
    } finally {
      _loadingMore = false;
    }
  }

  /// Gửi tin: hiển thị ngay (optimistic) -> xác nhận từ server.
  Future<bool> send(
    String content, {
    MessageType type = MessageType.text,
  }) async {
    final tempId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = MessageModel(
      id: tempId,
      conversationId: conversationId,
      senderId: 'u_me',
      content: content,
      type: type,
      createdAt: DateTime.now(),
    );
    state = [...state, optimistic];
    try {
      final data = await _api.post(
        '/api/conversations/$conversationId/messages',
        data: {
          'content': content,
          'type': type.name,
          'clientMessageId': tempId,
        },
      );
      final server = MessageModel.fromJson(
        data['message'] as Map<String, dynamic>,
      );
      state = [
        for (final m in state)
          if (m.id == tempId || m.id == server.id)
            (m.id == tempId ? server : m)
          else
            m,
      ];
      // tránh trùng nếu server echo tới (cùng id)
      final seen = <String>{};
      state = [
        for (final m in state)
          if (seen.add(m.id)) m,
      ];
      return true;
    } catch (_) {
      state = [
        for (final m in state)
          if (m.id != tempId) m,
      ];
      return false;
    }
  }

  /// Tin đến từ socket:
  /// - có clientMessageId khớp tin local -> thay thế (xác nhận từ server)
  /// - đã tồn tại id -> bỏ qua; còn lại -> thêm mới
  void applyIncoming(ChatSocketMessage incoming) {
    if (state.any((m) => m.id == incoming.message.id)) return;
    final clientId = incoming.clientMessageId;
    if (clientId != null && state.any((m) => m.id == clientId)) {
      state = [
        for (final m in state)
          if (m.id == clientId) incoming.message else m,
      ];
      return;
    }
    state = [...state, incoming.message];
  }

  /// Sửa tin (từ socket hoặc sau khi PATCH thành công)
  void applyEdited(String messageId, String content) {
    state = [
      for (final m in state)
        if (m.id == messageId)
          MessageModel(
            id: m.id,
            conversationId: m.conversationId,
            senderId: m.senderId,
            content: content,
            type: m.type,
            createdAt: m.createdAt,
            isRead: m.isRead,
            durationSeconds: m.durationSeconds,
          )
        else
          m,
    ];
  }

  /// Xóa tin
  void applyDeleted(String messageId) {
    state = [
      for (final m in state)
        if (m.id != messageId) m,
    ];
  }
}

/// Tín hiệu socket chat:message gộp payload
/// {conversationId, message, clientMessageId?}
class ChatSocketMessage {
  final MessageModel message;
  final String? clientMessageId;
  const ChatSocketMessage({required this.message, this.clientMessageId});
}

final messagesProvider = StateNotifierProvider.autoDispose
    .family<MessagesNotifier, List<MessageModel>, String>(
      (ref, conversationId) =>
          MessagesNotifier(ref.watch(apiClientProvider), conversationId),
    );

// ===== Feed =====
class FeedNotifier extends StateNotifier<List<PostModel>> {
  FeedNotifier(this._api) : super(const []);
  final ApiClient _api;

  bool _loadingMore = false;
  bool _hasMore = true;
  bool get isLoadingMore => _loadingMore;
  bool get hasMore => _hasMore;

  Future<bool> load() async {
    try {
      final data = await _api.get('/api/feed');
      _hasMore = (data['posts'] as List).length >= 30;
      state = (data['posts'] as List)
          .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Tải thêm bài cũ (phân trang vô tận).
  /// Dùng cursor [before] = thời điểm bài CUỐI CÙNG trong danh sách thay vì offset:
  /// bài mới từ realtime được thêm vào đầu làm offset nhảy số -> bỏ sót bài cũ.
  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore || state.isEmpty) return;
    _loadingMore = true;
    try {
      final cursor = state.last.createdAt.toIso8601String();
      final data = await _api.get(
        '/api/feed',
        query: {'before': cursor, 'limit': 30},
      );
      final more = (data['posts'] as List)
          .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _hasMore = more.length >= 30;
      // Cursor dùng <= nên mốc có thể trả lại bài đã có -> loại trùng
      final seen = {for (final p in state) p.id};
      final fresh = [
        for (final p in more)
          if (seen.add(p.id)) p,
      ];
      state = [...state, ...fresh];
    } catch (_) {
      // giữ nguyên
    } finally {
      _loadingMore = false;
    }
  }

  /// Cập nhật bài sau khi sửa (hoặc server trả về mới).
  void updatePost(PostModel post) {
    state = [
      for (final p in state)
        if (p.id == post.id) post else p,
    ];
  }

  /// Bài realtime từ server (feed:new / feed:updated).
  void applyRealtime(PostModel post) {
    final i = state.indexWhere((p) => p.id == post.id);
    if (i < 0) {
      state = [post, ...state]; // bài mới -> lên đầu
      return;
    }
    // Bài đã có: server gửi likedByMe theo góc nhìn người sửa bài -> giữ của mình
    state = [
      for (final p in state)
        if (p.id == post.id) post.copyWith(likedByMe: p.likedByMe) else p,
    ];
  }

  /// Đồng bộ số liệu (like/bình luận/chia sẻ) từ các thiết bị khác.
  void applyStats(String postId, {int? likes, int? comments, int? shares}) {
    state = [
      for (final p in state)
        if (p.id == postId)
          p.copyWith(
            likes: likes ?? p.likes,
            comments: comments ?? p.comments,
            shares: shares ?? p.shares,
          )
        else
          p,
    ];
  }

  void removePost(String postId) {
    state = [
      for (final p in state)
        if (p.id != postId) p,
    ];
  }

  /// Bật/tắt like và đối chiếu kết quả tối ưu với phản hồi server.
  Future<void> toggleLike(String postId) async {
    final index = state.indexWhere((p) => p.id == postId);
    if (index < 0) return;
    final before = state[index];
    final optimistic = before.copyWith(
      likedByMe: !before.likedByMe,
      likes: before.likedByMe ? before.likes - 1 : before.likes + 1,
    );
    state = [
      for (final p in state)
        if (p.id == postId) optimistic else p,
    ];
    try {
      final data = await _api.post('/api/feed/$postId/like');
      final reconciled = optimistic.copyWith(
        likes: (data['likes'] as num?)?.toInt() ?? optimistic.likes,
        likedByMe: data['likedByMe'] == true,
      );
      state = [
        for (final p in state)
          if (p.id == postId) reconciled else p,
      ];
    } catch (_) {
      state = [
        for (final p in state)
          if (p.id == postId) before else p,
      ];
    }
  }

  /// Yêu cầu server ghi nhận một lượt chia sẻ đã thực sự được xác nhận bởi hệ điều hành.
  /// Chia sẻ bên ngoài chỉ ghi nhận sau confirm; repost gửi caption để server tạo post mới.
  Future<String?> sharePost(
    String postId, {
    String? repostContent,
    bool createRepost = false,
    bool confirmed = false,
  }) async {
    try {
      final body = createRepost
          ? {'repostContent': repostContent ?? ''}
          : (confirmed ? {'confirmed': true} : null);
      final data = await _api.post('/api/feed/$postId/share', data: body);
      final shares = (data['shares'] as num?)?.toInt();
      final repostPost = data['repost'];
      state = [
        for (final p in state)
          if (p.id == postId) p.copyWith(shares: shares) else p,
        if (repostPost is Map)
          PostModel.fromJson(Map<String, dynamic>.from(repostPost)),
      ];
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Không thể chia sẻ bài viết — kiểm tra kết nối';
    }
  }

  /// Đăng bài: trả về null nếu thành công, ngược lại là thông báo lỗi.
  Future<String?> addPost(String content, List<String> media) async {
    try {
      final data = await _api.post(
        '/api/feed',
        data: {'content': content, 'media': media},
      );
      final post = PostModel.fromJson(data['post'] as Map<String, dynamic>);
      state = [post, ...state];
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Không thể đăng bài — kiểm tra kết nối';
    }
  }
}

final feedProvider = StateNotifierProvider<FeedNotifier, List<PostModel>>(
  (ref) => FeedNotifier(ref.watch(apiClientProvider)),
);

/// Lắng nghe sự kiện feed realtime của Socket.io và đồng bộ [feedProvider].
/// Đăng ký 1 lần ở HomePage; socket mất mạng -> khôi phục sẽ tự tải lại feed
/// (bỏ lỡ sự kiện trong lúc offline).
final feedRealtimeProvider = Provider<void>((ref) {
  final socket = ref.watch(socketProvider);

  PostModel? parsePost(dynamic data) {
    final post = (data as Map?)?['post'];
    if (post is! Map) return null;
    try {
      return PostModel.fromJson(Map<String, dynamic>.from(post));
    } catch (_) {
      return null;
    }
  }

  final subs = [
    socket.on('feed:comment:new').listen((data) {
      final raw = (data as Map?)?['comment'];
      if (raw is! Map) return;
      try {
        final comment = CommentModel.fromJson(Map<String, dynamic>.from(raw));
        ref.read(commentsProvider(comment.postId).notifier).applyAdded(comment);
      } catch (_) {
        // Payload không đúng schema: bỏ sự kiện, lần tải kế tiếp sẽ đồng bộ lại.
      }
    }),
    socket.on('feed:comment:updated').listen((data) {
      final raw = (data as Map?)?['comment'];
      if (raw is! Map) return;
      try {
        final comment = CommentModel.fromJson(Map<String, dynamic>.from(raw));
        ref
            .read(commentsProvider(comment.postId).notifier)
            .applyUpdated(comment);
      } catch (_) {
        // Payload không đúng schema.
      }
    }),
    socket.on('feed:comment:deleted').listen((data) {
      final map = data as Map?;
      final postId = map?['postId'];
      final commentId = map?['commentId'];
      if (postId is String && commentId is String) {
        ref.read(commentsProvider(postId).notifier).applyDeleted(commentId);
      }
    }),
    socket.on('feed:new').listen((d) {
      final post = parsePost(d);
      if (post != null) ref.read(feedProvider.notifier).applyRealtime(post);
    }),
    socket.on('feed:updated').listen((d) {
      final post = parsePost(d);
      if (post != null) ref.read(feedProvider.notifier).applyRealtime(post);
    }),
    socket.on('feed:deleted').listen((d) {
      final id = (d as Map?)?['postId'];
      if (id is String) ref.read(feedProvider.notifier).removePost(id);
    }),
    socket.on('feed:stats').listen((d) {
      final m = d as Map?;
      final id = m?['postId'];
      if (id is! String) return;
      ref
          .read(feedProvider.notifier)
          .applyStats(
            id,
            likes: (m?['likes'] as num?)?.toInt(),
            comments: (m?['comments'] as num?)?.toInt(),
            shares: (m?['shares'] as num?)?.toInt(),
          );
    }),
    // Kết nối lại sau khi mất mạng: bù các sự kiện đã bỏ lỡ
    socket.on('connect').listen((d) {
      if (d == true) ref.read(feedProvider.notifier).load();
    }),
  ];
  ref.onDispose(() {
    for (final s in subs) {
      s.cancel();
    }
  });
});

// ===== Bình luận =====
/// Nguồn state cho danh sách bình luận của một bài feed.
class CommentsNotifier extends StateNotifier<AsyncValue<List<CommentModel>>> {
  CommentsNotifier(this._api, this.postId, this._ref)
    : super(const AsyncValue.loading());
  final ApiClient _api;
  final String postId;
  final Ref _ref;

  List<CommentModel> get _comments => state.valueOrNull ?? const [];

  void _updateFeedCount(List<CommentModel> comments) {
    _ref
        .read(feedProvider.notifier)
        .applyStats(postId, comments: comments.length);
  }

  /// Khi tải lại, ưu tiên server nhưng không làm mất comment vừa tới realtime.
  List<CommentModel> _mergeLoaded(List<CommentModel> loaded) {
    final byId = <String, CommentModel>{
      for (final comment in _comments) comment.id: comment,
      for (final comment in loaded) comment.id: comment,
    };
    final merged = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = AsyncValue.data(merged);
    _updateFeedCount(merged);
    return merged;
  }

  /// Thêm theo ID để response HTTP và socket không tạo hai comment giống nhau.
  void applyAdded(CommentModel comment) {
    if (comment.postId != postId || _comments.any((c) => c.id == comment.id)) {
      return;
    }
    final next = [..._comments, comment]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = AsyncValue.data(next);
    _updateFeedCount(next);
  }

  void applyUpdated(CommentModel comment) {
    if (comment.postId != postId || !_comments.any((c) => c.id == comment.id)) {
      return;
    }
    final next = [
      for (final current in _comments)
        if (current.id == comment.id) comment else current,
    ];
    state = AsyncValue.data(next);
  }

  void applyDeleted(String commentId) {
    final current = _comments;
    final next = [
      for (final comment in current)
        if (comment.id != commentId) comment,
    ];
    if (next.length == current.length) return;
    state = AsyncValue.data(next);
    _updateFeedCount(next);
  }

  /// Tải comment lưu trữ từ API rồi gộp cùng event socket mới đến trong lúc chờ.
  Future<void> load() async {
    final previous = _comments;
    state = const AsyncValue.loading();
    try {
      final data = await _api.get('/api/feed/$postId/comments');
      final loaded = (data['comments'] as List)
          .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _mergeLoaded([...previous, ...loaded]);
    } on ApiException catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Tạo bình luận ở server; socket và REST response cùng đi qua applyAdded để khử trùng.
  Future<String?> add(String content) async {
    try {
      final data = await _api.post(
        '/api/feed/$postId/comments',
        data: {'content': content},
      );
      final comment = CommentModel.fromJson(
        data['comment'] as Map<String, dynamic>,
      );
      applyAdded(comment);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Không thể bình luận — kiểm tra kết nối';
    }
  }

  /// Sửa bình luận của mình.
  Future<String?> edit(CommentModel comment, String content) async {
    try {
      final data = await _api.patch(
        '/api/feed/$postId/comments/${comment.id}',
        data: {'content': content},
      );
      final updated = CommentModel.fromJson(
        data['comment'] as Map<String, dynamic>,
      );
      applyUpdated(updated);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Không thể sửa bình luận';
    }
  }

  /// Xóa bình luận (của mình, hoặc bài của mình).
  Future<String?> remove(CommentModel comment) async {
    try {
      await _api.delete('/api/feed/$postId/comments/${comment.id}');
      applyDeleted(comment.id);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Không thể xóa bình luận';
    }
  }
}

final commentsProvider = StateNotifierProvider.autoDispose
    .family<CommentsNotifier, AsyncValue<List<CommentModel>>, String>(
      (ref, postId) =>
          CommentsNotifier(ref.watch(apiClientProvider), postId, ref),
    );

// ===== Phòng tiệc =====
class RoomsNotifier extends StateNotifier<List<RoomModel>> {
  RoomsNotifier(this._api) : super(const []);
  final ApiClient _api;

  Future<bool> load() async {
    try {
      final data = await _api.get('/api/rooms');
      state = (data['rooms'] as List)
          .map((e) => RoomModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Thêm phòng vừa tạo lên đầu danh sách.
  void prepend(RoomModel room) {
    state = [room, ...state];
  }

  /// Thành viên realtime từ sự kiện room:presence.
  void applyPresence(String roomId, List<dynamic> members) {
    state = [
      for (final r in state)
        if (r.id == roomId)
          r.copyWithMembers(
            members.length,
            members
                .map((m) => ((m as Map)['avatar'] ?? '🙂').toString())
                .toList(),
          )
        else
          r,
    ];
  }
}

final roomsProvider = StateNotifierProvider<RoomsNotifier, List<RoomModel>>(
  (ref) => RoomsNotifier(ref.watch(apiClientProvider)),
);
