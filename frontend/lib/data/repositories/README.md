# `frontend/lib/data/repositories/` — state và nghiệp vụ phía client

**Vai trò:** giữ state dùng chung, gọi API/socket, áp dụng optimistic update và đồng bộ realtime. Đây là nơi "nghiệp vụ client" sống.
**Ai gọi tới:** mọi màn hình trong `features/`, `main.dart` (invalidate khi đăng xuất), `core/network/outbox.dart`.
**Gọi đi:** `data/api/api_client.dart`, `data/api/socket_client.dart`, `data/models/models.dart`.

## File trong thư mục

| File | Provider / class | Dữ liệu |
|---|---|---|
| `auth_repository.dart` | `authProvider` (`AuthNotifier`, `AuthState`), `currentUserProvider` | Phiên đăng nhập: `restore()`, `login()`, `register()`, `logout()`, `completeProfile()`, `changePassword()`, `applyUser()`, `applyWallet()`, `sessionExpired()` |
| `chat_repository.dart` | `chatProvider`, `messagesProvider`, `feedProvider`, `myPostsProvider`, `commentsProvider`, `roomsProvider`, `feedRealtimeProvider` | Chat, feed, bình luận, phòng — xem bảng dưới |
| `social_repository.dart` | `friendsProvider`, `socialRealtimeProvider` | Danh sách bạn bè (`FriendEntry`) |
| `catalog_repository.dart` | `appCatalogProvider` (`AppCatalog`, `RoomGiftOption`, `CoinPackageOption`, `VipBenefitOption`) | Catalog server: avatar, sở thích, quà + giá, gói Xu, VIP, thời lượng game |

## Chi tiết `chat_repository.dart`

| Class | State | Hàm chính |
|---|---|---|
| `ChatNotifier` | `List<ConversationModel>` | `load()`, `applySent()`, `applyIncoming()` (tăng unread, hội thoại lạ thì `load()` lại), `clearUnread()`, `applyPresence()` |
| `MessagesNotifier` | `List<MessageModel>` | `load()`, `loadMore()` (cursor `before`), `send()` (optimistic `local_<ts>` → thay bằng bản thật), `applyIncoming(ChatSocketMessage)`, `applyEdited()`, `applyDeleted()` |
| `ChatSocketMessage` | — | Gói payload `{conversationId, message, clientMessageId}` |
| `FeedNotifier` | `List<PostModel>` | `load()`, `loadMore()` (cursor), `addPost()`, `toggleLike()` (optimistic + rollback), `sharePost()`, `applyRealtime()`, `applyStats()`, `removePost()` |
| `MyPostsNotifier` | `List<PostModel>` | `load(userId)` — bài của chính mình cho trang Cá nhân |
| `CommentsNotifier` | `AsyncValue<List<CommentModel>>` | `load()`, `add()`, `edit()`, `remove()`, `applyAdded()/applyUpdated()/applyDeleted()`, `_mergeLoaded()` giữ comment đến trong lúc tải |
| `RoomsNotifier` | `List<RoomModel>` | `load()`, `prepend()`, `applyPresence()` |
| `feedRealtimeProvider` | `void` (side-effect) | Đăng ký `feed:*`, `feed:comment:*`, `connect`; đăng ký 1 lần ở `HomePage` |

## Luồng chat (phía client)

```text
chat_list_page.dart  →  chatProvider.notifier.load()          → GET /api/conversations
        │ bấm một hội thoại
        ▼
chat_detail_page.dart: initState()
   ├── messagesProvider(id).notifier.load()                   → GET /api/conversations/:id/messages
   ├── chatProvider.notifier.clearUnread(id)
   └── socket.on('chat:message' / '-edited' / '-deleted' / 'chat:typing')

người dùng bấm gửi
   ▼
_send()  →  ensureOnline()  →  MessagesNotifier.send()
   ├── state = [...state, tin tạm]                            (optimistic)
   ├── POST /api/conversations/:id/messages  {clientMessageId}
   │      └── server lưu DB rồi emit chat:message cho cả hai bên
   ├── phản hồi HTTP: thay tin tạm bằng tin thật
   └── socket tới: applyIncoming() — khớp clientMessageId thì thay, trùng id thì bỏ qua
thất bại → chat_detail_page.dart: outbox.enqueue()             (core/network/outbox.dart)
```

## Luồng đồng bộ realtime

| Event | Notifier nhận | Kết quả |
|---|---|---|
| `chat:message` | `MessagesNotifier.applyIncoming` + `ChatNotifier.applyIncoming` | Tin mới hiện ngay, danh sách chat đổi "tin cuối" |
| `chat:message-edited/deleted` | `MessagesNotifier` | Sửa/xoá bong bóng đang mở |
| `presence:changed` | `ChatNotifier.applyPresence` | Chấm online/offline |
| `conversations:changed` | `ChatListPage` → `chatProvider.load()` | Hội thoại mới xuất hiện |
| `friends:changed` | `socialRealtimeProvider` → `friends.load()` | Danh sách bạn bè cập nhật |
| `feed:*`, `feed:comment:*` | `feedRealtimeProvider` | Feed/bình luận cập nhật ở mọi màn hình |
| `user:updated`, `user:wallet` | `main.dart` → `AuthNotifier.applyUser/applyWallet` | Hồ sơ, số Xu đồng bộ |

## Quy ước

1. **Provider đặt cạnh notifier**, tên `xxxProvider`; provider cần tham số dùng `.family` (`messagesProvider(id)`, `commentsProvider(postId)`).
2. **Optimistic phải có rollback**: giữ state trước, lỗi thì khôi phục (xem `FeedNotifier.toggleLike`).
3. **Khử trùng theo `id`** trước khi thêm phần tử từ socket.
4. **Không gọi `Navigator`/`BuildContext` trong notifier** — chỉ trả lỗi hoặc `bool` cho UI quyết định.
5. **Hủy subscription** trong `ref.onDispose` (provider side-effect) hoặc `dispose()` của màn hình.
