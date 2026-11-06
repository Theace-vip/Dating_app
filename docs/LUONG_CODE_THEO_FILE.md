# Luồng code theo từng file — SoulMate

Tài liệu này trả lời câu hỏi: **một chức năng chạy qua những file nào, theo thứ tự nào, hàm nào gọi hàm nào.**
Mỗi thư mục còn có `README.md` riêng mô tả file trong thư mục đó (xem [`docs/README.md`](README.md)).

Quy ước đọc:

- `file: hàm` — vị trí chính xác của đoạn code.
- `→` — "gọi tới / chuyển sang".
- `[REST]` — đi qua HTTP (Dio); `[WS]` — đi qua Socket.IO; `[DB]` — ghi/đọc SQLite.
- Mọi endpoint `/api/*` (trừ `/api/auth/*`) đều cần `Authorization: Bearer <accessToken>`.

---

## 0. Một request đi qua những file nào

```text
[UI]  frontend/lib/features/<chức năng>/*.dart
        │ ref.read(...).notifier.<hàm>()        ← người dùng bấm nút
        ▼
[STATE] frontend/lib/data/repositories/*.dart   ← StateNotifier giữ danh sách + optimistic
        │ _api.get/post/patch/delete
        ▼
[HTTP]  frontend/lib/data/api/api_client.dart   ← gắn Bearer token, tự refresh khi 401
        │ HTTPS + cert pin (core/network/pinning.dart)
        ▼
[SERVER] backend/src/index.js  → authMiddleware (backend/src/auth.js → security.js)
        │
        ▼
[ROUTE] backend/src/routes.js   ← validate, phân quyền, SQL
        │ db.prepare(...)                      ← helper: backend/src/db.js
        ▼
[DB]    backend/data/soulmate.db (SQLite, schema tạo ở backend/src/db.js)
        │ emitToUserSafe / emitFeedSafe (routes.js) → emitToUser (socket.js)
        ▼
[WS]    Socket.IO room user:<id>  →  frontend/lib/data/api/socket_client.dart
        │ Stream<dynamic> theo tên event
        ▼
[STATE] notifier.apply...()  →  [UI] widget rebuild
```

Chat, feed, phòng tiệc dùng đúng vòng này; khác nhau ở route, tên event và notifier.

---

## 1. Khởi động app

| Bước | Code | Việc xảy ra |
|---|---|---|
| 1 | `frontend/lib/main.dart: main()` | `installCertificatePinning()`, đọc `server_host` từ `SharedPreferences`, `runApp(ProviderScope(...))` |
| 2 | `frontend/lib/main.dart: _MyAppState.initState()` | `outbox.init()` + `flush()` nếu online; nghe `user:wallet`, `user:updated`, `call:invite` |
| 3 | `frontend/lib/app/router.dart: routerProvider` | Đọc `authProvider` → redirect `/splash` → `/login` / `/profile-setup` / `/` |
| 4 | `frontend/lib/data/repositories/auth_repository.dart: AuthNotifier.restore()` | `ApiClient.loadTokens()` → `GET /api/me` |
| 5 | `frontend/lib/main.dart: build()` | `ref.listen(authProvider)`: đăng nhập → `socket.connect()`; đăng xuất → `disconnect()` + `ref.invalidate(chat/feed/rooms/friends)` |

---

## 2. Đăng nhập / đăng xuất

| Bước | Code | Việc xảy ra |
|---|---|---|
| 1 | `frontend/lib/features/auth/login_page.dart: _submit()` | Validate email/mật khẩu → `AuthNotifier.login()` |
| 2 | `frontend/lib/data/repositories/auth_repository.dart: login()` | `ApiClient.login()` → `POST /api/auth/login` |
| 3 | `backend/src/index.js` | Mount `app.use('/api/auth', authRouter)` (không cần token) |
| 4 | `backend/src/auth.js: router.post('/login')` | `getUserByEmail()` (`db.js`) → `verifyPassword()` (`security.js`) → `issueTokenPair()` |
| 5 | `backend/src/security.js` | `signAccessToken()` (JWT 15 phút), `newRefreshTokenValue()` + `hashToken()`; chỉ hash lưu vào bảng `refresh_tokens` |
| 6 | `frontend/lib/data/api/api_client.dart: _saveTokens()` | Lưu access/refresh vào `flutter_secure_storage` |
| 7 | `frontend/lib/data/repositories/auth_repository.dart: AuthState` | `authenticated` + `UserModel` → `router.dart` vào `/` (hoặc `/profile-setup`) |
| 8 | Đăng xuất | `profile_page.dart` → `AuthNotifier.logout()` → `ApiClient.logoutOnServer()` (`POST /api/auth/logout`) → `clearSession()` → socket disconnect |

Token hết hạn giữa chừng: `api_client.dart: onError` gặp 401 → `_refreshTokens()` (single-flight) → `POST /api/auth/refresh` (`backend/src/auth.js`) → gửi lại request gốc **một lần**; thất bại → `onSessionExpired` → `AuthNotifier.sessionExpired()`.

---

## 3. Chat 1-1 (ví dụ đầy đủ nhất)

### 3.1. Mở danh sách hội thoại

| Bước | Code | Việc xảy ra |
|---|---|---|
| 1 | `frontend/lib/features/home/home_page.dart: initState()` | Tab "Tin nhắn" dựng `ChatListPage`, đồng thời gọi `chatProvider.notifier.load()` |
| 2 | `frontend/lib/data/repositories/chat_repository.dart: ChatNotifier.load()` | `ApiClient.get('/api/conversations')` |
| 3 | `frontend/lib/data/api/api_client.dart: _get()` | Gắn `Authorization: Bearer ...` rồi gọi Dio |
| 4 | `backend/src/index.js` | `app.use('/api', authMiddleware, apiRouter)` → xác thực token |
| 5 | `backend/src/routes.js: router.get('/conversations')` | SQL join `conversations` + `users`, subquery đếm `messages.is_read = 0`; `isOnline()` từ `socket.js` |
| 6 | `backend/src/db.js` | Bảng `conversations`, `messages` (schema + index `idx_messages_conv`) |
| 7 | `frontend/lib/data/models/models.dart: ConversationModel.fromJson()` | Parse JSON thành model |
| 8 | `frontend/lib/features/chat/chat_list_page.dart: build()` | `ref.watch(chatProvider)` → render danh sách |

### 3.2. Mở một hội thoại và tải lịch sử

| Bước | Code | Việc xảy ra |
|---|---|---|
| 1 | `chat_list_page.dart` → `Navigator.push` | Mở `ChatDetailPage(conversationId, partnerId, ...)` |
| 2 | `frontend/lib/features/chat/chat_detail_page.dart: initState()` | `messagesProvider(id).notifier.load()`; sau frame đầu gọi `chatProvider.clearUnread(id)` |
| 3 | `chat_repository.dart: MessagesNotifier.load()` | `GET /api/conversations/:id/messages` |
| 4 | `backend/src/routes.js: findConversationFor()` | Chỉ thành viên hội thoại; người ngoài nhận 404 |
| 5 | `backend/src/routes.js: router.get('/conversations/:id/messages')` | `UPDATE messages SET is_read = 1` cho tin đối phương; trả 50 tin mới nhất + `hasMore` |
| 6 | `chat_repository.dart: MessagesNotifier.load()` | Gán `state` = danh sách `MessageModel` |
| 7 | `chat_detail_page.dart: build()` | `ref.watch(messagesProvider(id))` → `ListView.builder` + `_buildBubble()` |

### 3.3. Gửi tin nhắn (optimistic → xác nhận)

| Bước | Code | Việc xảy ra |
|---|---|---|
| 1 | `chat_detail_page.dart: _send()` | `ensureOnline()` (`core/network/connectivity_service.dart`), xoá ô nhập |
| 2 | `chat_repository.dart: MessagesNotifier.send()` | Tạo `tempId = local_<microseconds>`, thêm tin tạm vào `state` (**optimistic**) |
| 3 | `api_client.dart: post()` → `_post()` | `POST /api/conversations/:id/messages` với `{content, type, clientMessageId}` |
| 4 | `backend/src/routes.js: router.post('/conversations/:id/messages')` | Validate nội dung ≤ 2000, ảnh phải `/uploads/...`; `INSERT INTO messages`; `UPDATE conversations.last_message` |
| 5 | `backend/src/routes.js: emitToUserSafe()` | Gửi `chat:message` cho **đối phương** và **chính mình** (kèm `clientMessageId`) |
| 6 | `backend/src/socket.js: emitToUser()` | `io.to('user:<id>').emit('chat:message', payload)` |
| 7 | `frontend/lib/data/api/socket_client.dart: _relay()` | Đẩy payload vào `StreamController` của event `chat:message` |
| 8 | `chat_detail_page.dart` listener `socket.on('chat:message')` | Lọc đúng `conversationId` → `MessagesNotifier.parseSocketPayload()` |
| 9 | `chat_repository.dart: MessagesNotifier.applyIncoming()` | Nếu `clientMessageId` khớp tin tạm → thay bằng tin thật; nếu `id` đã có → bỏ qua |
| 10 | `chat_repository.dart: ChatNotifier.applyIncoming()` | Cập nhật "tin cuối" + tăng `unreadCount` (nếu không phải mình gửi) |

Gửi thất bại: `send()` trả `false` → `chat_detail_page.dart: _send()` gọi `outboxProvider.enqueue()` (`core/network/outbox.dart`).
Khi mạng trở lại: `main.dart` (`ref.listen(connectivityProvider)`) → `outbox.flush()` → `api.post(...)` cho từng tin, xong thì xoá khỏi `SharedPreferences`.

### 3.4. "Đang gõ", sửa, xoá

| Chức năng | Client | Server | Quay về client |
|---|---|---|---|
| Typing | `chat_detail_page.dart: _notifyTyping()` (giới hạn 2 giây/lần) → `socket.emit('chat:typing')` | `backend/src/socket.js` handler `chat:typing`: kiểm tra thành viên hội thoại → `emitToUser(partner, ...)` | `chat_detail_page.dart` listener → `_partnerTyping = true`, tự tắt sau 3 giây |
| Sửa tin | `chat_detail_page.dart: _editMessage()` → `apiClient.patch(...)` | `routes.js` `PATCH /conversations/:id/messages/:mid` (chỉ người gửi) → `UPDATE messages` → `chat:message-edited` | `MessagesNotifier.applyEdited()` |
| Xoá tin | `chat_detail_page.dart: _deleteMessage()` → `apiClient.delete(...)` | `routes.js` `DELETE .../:mid` → `DELETE FROM messages` → `chat:message-deleted` | `MessagesNotifier.applyDeleted()` |

### 3.5. Gửi ảnh

`chat_detail_page.dart: _sendImage()` → `frontend/lib/shared/image_tools.dart: pickAndUploadImage()` (nén ảnh)
→ `api_client.dart: uploadImage()` → `POST /api/upload` (`backend/src/routes.js`, ghi file vào `backend/uploads/`)
→ trả `{url: "/uploads/..."}` → `MessagesNotifier.send(url, type: MessageType.image)` → cùng luồng 3.3.
Hiển thị: `AppConfig.absoluteUrl()` (`core/constants/app_config.dart`) + `Image.network`.

### 3.6. Người khác mở chat với mình

`routes.js: POST /conversations/ensure` → `ensureConversation()` (`db.js`) → `emitToUserSafe(partnerId, 'conversations:changed')`
→ `chat_list_page.dart` listener → `chatProvider.notifier.load()`.

---

## 4. Feed, like, bình luận

| Bước | Code | Việc xảy ra |
|---|---|---|
| Tải feed | `home_page.dart` → `feedProvider.notifier.load()` (`chat_repository.dart`) → `GET /api/feed` (`routes.js:436`) → SQL `posts` + `post_likes` + `comments` | `FeedNotifier.state` |
| Đăng bài | `features/feed/create_post_page.dart: _post()` → `FeedNotifier.addPost()` → `POST /api/feed` → `INSERT posts` → `emitFeedSafe('feed:new')` | Bài lên đầu danh sách ở mọi client |
| Like | `features/feed/feed_page.dart: _PostCard` → `FeedNotifier.toggleLike()` (optimistic) → `POST /api/feed/:id/like` → toggle `post_likes` → `feed:stats` | Đối chiếu `likes` / `likedByMe`, lỗi thì rollback |
| Bình luận | `feed_page.dart: CommentsSheet` → `CommentsNotifier.load()` → `GET /api/feed/:id/comments`; gửi: `CommentsNotifier.add()` → `POST /api/feed/:id/comments` → `INSERT comments` → `feed:comment:new` + `feed:stats` | `applyAdded()` khử trùng theo `id` (REST và socket cùng đi qua đây) |
| Sửa/xoá bài | `feed_page.dart` dialog → `PATCH/DELETE /api/feed/:id` → `feed:updated` / `feed:deleted` | `FeedNotifier.updatePost()` / `removePost()` |
| Chia sẻ / repost | `FeedNotifier.sharePost()` → `POST /api/feed/:id/share` → tăng `shares_count`, repost tạo post mới | `feed:new` + `feed:stats` |

Nơi nhận sự kiện: `chat_repository.dart: feedRealtimeProvider` (đăng ký một lần ở `HomePage`).
Bài của chính mình ở trang Cá nhân: `MyPostsNotifier` (`myPostsProvider`) tải `GET /api/feed?userId=<mình>`.

---

## 5. Bạn bè

`frontend/lib/data/repositories/social_repository.dart: FriendsNotifier.load()` → `GET /api/friends` (`routes.js:187`)
→ `rows` từ bảng `friendships` + `ensureConversation()` để có `conversationId`.
Kết bạn xảy ra ở server khi Soul Game reveal / mutual-like (`socket.js`): `addFriendship()` (`db.js`) + `emitToUser('friends:changed')`.
Client: `social_realtime` trong `social_repository.dart: socialRealtimeProvider` → `friends.load()` lại.

---

## 6. Phòng tiệc và quà

| Bước | Code | Việc xảy ra |
|---|---|---|
| Danh sách phòng | `features/room/room_list_page.dart` → `RoomsNotifier.load()` (`chat_repository.dart`) → `GET /api/rooms` (`routes.js:674`) | `memberCount` lấy từ `roomMembers` trong `socket.js` |
| Vào phòng | `features/room/room_detail_page.dart: initState()` → `GET /api/rooms/:id/messages` rồi `socket.emit('room:join')` | `socket.js` join `room:<id>`, phát `room:presence` + `rooms:changed` |
| Gửi tin phòng | `room_detail_page.dart: _send()` → `POST /api/rooms/:id/messages` (`routes.js:738`) → `INSERT room_messages` → `room:message` | Khử trùng theo `id` |
| Thả tim | `room_detail_page.dart` → `socket.emit('room:heart')` → `socket.js` relay cho người khác | Hiệu ứng `_TikTokHeartWidget` |
| Tặng quà | `room_detail_page.dart` → `socket.emit('room:gift')` → `socket.js` → `backend/src/catalog.js: chargeRoomGift()` (tra giá trong catalog, trừ Xu atomic) → `user:wallet` + `room:gift` | `main.dart` nghe `user:wallet` → `AuthNotifier.applyWallet()`; phòng phát `SvgaGiftView` |
| Mic trong phòng | `room:rtc:join` → `socket.js` trả `room:rtc:peers` → `room_detail_page.dart` tạo `RtcSession` cho từng peer | SDP/ICE qua `room:rtc:signal` |

---

## 7. Soul Game / Voice Game

| Bước | Code | Việc xảy ra |
|---|---|---|
| Vào hàng đợi | `features/matching/soul_game_page.dart` → `socket.emit('soul:queue', {mode:'text'})` | `backend/src/socket.js` handler `soul:queue` |
| Ghép đôi | `socket.js` tìm người cùng `mode` trong `queue` → tạo `soulSessions` → `soul:matched` (kèm `durationSeconds`, `endsAt` do server tính từ `catalog.js`) | Client nhận `sessionId`, `initiator` |
| Chat ẩn danh | `soul:message` → `socket.js` relay trong room `soul:<id>`, đếm tin | Đủ 5 tin → `soul:heart-available` |
| Thả tim | `soul:like` → `socket.js` kiểm tra `heartAvailable`, ghi `session.likes` | Đủ 2 lượt → `ensureConversation()` + `addFriendship()` → `soul:mutual-like` |
| Hiện danh tính | `soul:reveal` → `socket.js` tạo hội thoại + bạn bè → `soul:revealed` | Client chuyển sang `ChatDetailPage` |
| Hết giờ | timer của `socket.js` → `soul:time-ended`; `soul:continue` chỉ hợp lệ sau khi hết giờ | `soul_game_page.dart` hiện sheet gia hạn |
| Voice Game | `voice_game_page.dart` dùng cùng handler với `mode:'voice'`; SDP/ICE qua `soul:rtc:signal` → `RtcSession` | Thời lượng lấy từ `catalog.js: matching.voiceSeconds` |

---

## 8. Gọi thoại / video

| Bước | Code | Việc xảy ra |
|---|---|---|
| Gọi đi | `chat_detail_page.dart` / `public_profile_page.dart` → `CallPage(callId, isVideo)` → `features/call/call_page.dart: _invite()` → `socket.emit('call:invite')` | `socket.js`: kiểm tra online/bận, lưu `activeCalls`, hẹn giờ chuông |
| Nhận cuộc gọi | `main.dart` listener `call:invite` → push `CallPage(incoming: true)` lên `rootNavigatorKey` | Bấm nghe → `call:accept` |
| Kết nối media | `call_page.dart` tạo `features/call/rtc_session.dart: RtcSession` (offer/answer/ICE) → `socket.emit('rtc:signal')` | `socket.js` chỉ relay khi cuộc gọi `accepted` và đúng cặp user |
| Kết thúc | `call:reject` / `call:hangup` / timeout chuông / `disconnecting` | `call:rejected` / `call:ended` → `CallPage` đóng |

---

## 9. Hồ sơ, ví, VIP

| Chức năng | Client | Server |
|---|---|---|
| Xem hồ sơ mình | `features/profile/profile_page.dart` đọc `currentUserProvider` + `myPostsProvider` + `friendsProvider` | `GET /api/me`, `GET /api/feed?userId=`, `GET /api/friends` |
| Sửa hồ sơ | `features/profile/edit_profile_page.dart: _save()` → `AuthNotifier.completeProfile()` → `ApiClient.updateMe()` | `PATCH /api/me` (`validateProfileOptions` → `UPDATE users`) → `user:updated` |
| Hồ sơ người khác | `features/profile/public_profile_page.dart` → `GET /api/users/:id` | Trả `isFriend`, `isOnline` |
| Tìm người | `features/chat/search_users_page.dart` (debounce) → `GET /api/users?q=` | |
| Ví | `features/profile/wallet_page.dart` đọc `appCatalogProvider` + `authProvider` | `GET /api/catalog`; số dư thật cập nhật qua `user:wallet` |
| VIP | `features/profile/vip_page.dart` | `GET /api/catalog` → `vip` (mua chưa bật) |
| Đổi mật khẩu | `profile_page.dart` dialog → `AuthNotifier.changePassword()` | `POST /api/me/password`: revoke toàn bộ refresh token cũ, trả cặp token mới |

---

## 10. Tải catalog (một lần cho toàn app)

`frontend/lib/data/repositories/catalog_repository.dart: appCatalogProvider` → `GET /api/catalog`
→ `backend/src/routes.js: sendCatalog()` trả `APP_CATALOG` (`backend/src/catalog.js`)
→ `AppCatalog.fromJson()`.
Mọi giá quà, gói Xu, thời lượng Soul Game, thời gian đổ chuông đều đọc từ đây — **không hard-code ở UI**.

---

## 11. Presence (online/offline)

| Bước | Code | Việc xảy ra |
|---|---|---|
| 1 | `backend/src/socket.js: io.on('connection')` | Thêm socket vào `presence: Map<userId, Set<socketId>>`, join `user:<id>` |
| 2 | `socket.js` | Socket đầu tiên của user → `io.emit('presence:changed', {online:true})` |
| 3 | `chat_list_page.dart` listener | `ChatNotifier.applyPresence()` → chấm xanh cạnh avatar |
| 4 | `socket.js: 'disconnect'` | Xoá socket khỏi `presence`, socket cuối cùng → `online:false` |

---

## 12. Bảng tra nhanh: muốn sửa X thì đọc file nào

| Muốn sửa | Đọc theo thứ tự |
|---|---|
| Nội dung tin nhắn chat | `chat_detail_page.dart` → `chat_repository.dart (MessagesNotifier)` → `routes.js` nhóm hội thoại → `db.js` bảng `messages` |
| Cách hiển thị danh sách chat | `chat_list_page.dart` → `chat_repository.dart (ChatNotifier)` → `routes.js` `GET /conversations` |
| Thêm loại tin nhắn mới | `models.dart (MessageType)` → `routes.js` (validate `type`) → `chat_detail_page.dart` (`_buildBubble`) |
| Sự kiện realtime mới | `socket.js` (emit) → `socket_client.dart` (thêm tên event) → notifier/trang lắng nghe |
| Giá quà / quà mới | `catalog.js` → `assets/svga/` → `room_detail_page.dart` |
| Luật Soul Game | `socket.js` (nhóm Soul Game) → `catalog.js` (`matching`) → `soul_game_page.dart` |
| Quyền truy cập dữ liệu | `routes.js` (`findConversationFor`, `validateProfileOptions`) + `auth.js` (`authMiddleware`) |
