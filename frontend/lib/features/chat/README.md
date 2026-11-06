# `frontend/lib/features/chat/` — chat 1-1 và bạn bè

**Vai trò:** 4 màn hình của tab "Tin nhắn": danh sách hội thoại, cửa sổ chat, danh sách bạn bè, tìm người dùng.
**Ai gọi tới:** `features/home/home_page.dart` (tab 1), `chat_list_page.dart` mở 3 màn còn lại, `features/profile/profile_page.dart` mở `FriendsPage`.
**Gọi đi:**
`data/repositories/chat_repository.dart` (`chatProvider`, `messagesProvider`),
`data/repositories/social_repository.dart` (`friendsProvider`),
`data/repositories/auth_repository.dart` (`currentUserProvider`),
`core/network/outbox.dart`, `core/network/connectivity_service.dart`,
`data/api/socket_client.dart`, `shared/image_tools.dart`,
`features/call/call_page.dart`.

## File trong thư mục

| File | Nội dung chính |
|---|---|
| `chat_list_page.dart` | Tải `chatProvider.load()`; nghe `chat:message` (cập nhật tin cuối/unread), `conversations:changed` (tải lại danh sách), `presence:changed` (chấm online); hiển thị thời gian tương đối; nút mở `SearchUsersPage` và `FriendsPage`. |
| `chat_detail_page.dart` | Cửa sổ chat: tải lịch sử + đánh dấu đã đọc, nghe `chat:message/-edited/-deleted/chat:typing`, gửi text/ảnh (optimistic), sửa/xoá tin của mình, cuộn tải thêm lịch sử có bù scroll, nút gọi thoại/video mở `CallPage`. |
| `friends_page.dart` | `friendsProvider.load()` → `GET /api/friends`; hiển thị bạn bè + online + ngày kết bạn; mở chat hoặc hồ sơ công khai. |
| `search_users_page.dart` | Ô tìm kiếm có debounce → `GET /api/users?q=`; mở `PublicProfilePage`. |

## Luồng chat — từ code nào tới code nào

### 1. Mở danh sách

```text
home_page.dart: initState()
   └── chatProvider.notifier.load()                       data/repositories/chat_repository.dart
         └── ApiClient.get('/api/conversations')          data/api/api_client.dart
               └── backend/src/index.js → authMiddleware (backend/src/auth.js)
                     └── backend/src/routes.js: router.get('/conversations')
                           └── backend/src/db.js  (SQL: conversations + users + đếm unread)
                                 └── JSON → ConversationModel.fromJson (data/models/models.dart)
                                       └── chat_list_page.dart: build() → ListView
```

### 2. Mở một hội thoại

```text
chat_list_page.dart → Navigator.push(ChatDetailPage(conversationId, partnerId, ...))
   └── chat_detail_page.dart: initState()
         ├── messagesProvider(id).notifier.load()          → GET /api/conversations/:id/messages
         │     └── routes.js: findConversationFor() (chỉ thành viên)
         │           └── UPDATE messages SET is_read = 1
         │                 └── MessagesNotifier.state = [...]
         ├── chatProvider.notifier.clearUnread(id)          (sau frame đầu)
         └── socket.on('chat:message' / '-edited' / '-deleted' / 'chat:typing')
```

### 3. Gửi tin nhắn

```text
chat_detail_page.dart: _send()
   ├── ensureOnline(context, ref)                          core/network/connectivity_service.dart
   ├── MessagesNotifier.send(text)                          chat_repository.dart
   │     ├── thêm tin tạm `local_<timestamp>` vào state     (optimistic, hiện ngay)
   │     ├── ApiClient.post('/api/conversations/:id/messages', {content, type, clientMessageId})
   │     │     └── routes.js: INSERT messages + UPDATE conversations.last_message
   │     │           └── emitToUserSafe(partnerId) + emitToUserSafe(req.userId) → 'chat:message'
   │     │                 └── socket.js: io.to('user:<id>').emit(...)
   │     └── phản hồi HTTP: thay tin tạm bằng tin thật
   └── socket_client.dart: _relay('chat:message') → chat_detail_page.dart listener
         └── MessagesNotifier.applyIncoming()               (khớp clientMessageId → thay, trùng id → bỏ)
               └── ChatNotifier.applyIncoming()             (tin cuối + unread ở danh sách)
```

Gửi lỗi: `send()` trả `false` → `outboxProvider.enqueue()` (`core/network/outbox.dart`) → khi mạng trở lại `main.dart` gọi `outbox.flush()` → gửi lại tuần tự.

### 4. Đang gõ / sửa / xoá

| Thao tác | Code client | Server | Quay về |
|---|---|---|---|
| Đang gõ | `_notifyTyping()` → `socket.emit('chat:typing', {conversationId})` (tối đa 2 giây/lần) | `socket.js` kiểm tra thành viên → `emitToUser(partner, 'chat:typing')` | Listener bật "đang gõ...", tự tắt sau 3 giây |
| Sửa | `_editMessage()` → `PATCH /api/conversations/:id/messages/:mid` | `routes.js`: chỉ người gửi → `UPDATE messages` → `chat:message-edited` | `MessagesNotifier.applyEdited()` |
| Xoá | `_deleteMessage()` → `DELETE .../:mid` | `routes.js`: chỉ người gửi → `DELETE` → `chat:message-deleted` | `MessagesNotifier.applyDeleted()` |
| Gửi ảnh | `_sendImage()` → `pickAndUploadImage()` | `POST /api/upload` → `/uploads/...` rồi như gửi text với `type: image` | `_buildBubble()` render `Image.network` |

### 5. Cuộn tải lịch sử

`_onScroll()` (còn < 200px tới đầu) → `MessagesNotifier.loadMore()` → `GET ...messages?before=<createdAt tin đầu>&limit=50`
→ chèn tin cũ vào đầu → `addPostFrameCallback` bù `scroll offset` để không nhảy màn hình.

## Ghi chú

- Nội dung tối đa 2000 ký tự; ảnh phải là URL `/uploads/...` do server trả (server từ chối URL ngoài).
- Không có "xoá hội thoại": lịch sử thuộc database, mở lại vẫn còn.
- Tin nhắn của mình cũng được server phát lại (echo) — nhờ vậy bản optimistic luôn được thay bằng bản thật.
- Tài liệu chức năng chi tiết: [`frontend/docs/03_chat_1_1.md`](../../../docs/03_chat_1_1.md).
