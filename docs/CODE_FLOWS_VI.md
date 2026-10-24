# Luồng chạy code theo chức năng — SoulMate

Tài liệu này mô tả **cách code chạy** cho từng chức năng: bắt đầu từ màn hình nào, gọi hàm/provider nào, đi qua API hay Socket.IO, server xử lý ra sao và cuối cùng cập nhật UI/database thế nào.

Đọc kèm:

- [`README.md`](../README.md) — tổng quan dự án, cách chạy, danh sách API.
- [`docs/FILE_GUIDE_VI.md`](FILE_GUIDE_VI.md) — danh mục từng thư mục/file và nên sửa ở đâu.
- [`docs/PROJECT_GUIDE_VI.md`](PROJECT_GUIDE_VI.md) — cấu trúc thư mục và các luồng lớn.

Quy ước trong tài liệu:

- `lib/...` là Flutter client; `server/src/...` là backend.
- `→` nghĩa là “gọi tới”.
- Mọi endpoint `/api/*` (trừ `/api/auth/*`) đều cần `Authorization: Bearer <accessToken>`.
- Server là nguồn quyết định cuối cùng cho quyền, thời gian phiên, giá quà và trạng thái cuộc gọi.

---

## 1. Sơ đồ tổng quát

```text
Widget / Page
   │  ref.read / ref.watch
   ▼
Riverpod Notifier (ChatNotifier, FeedNotifier, MessagesNotifier, ...)
   │
   ├── ApiClient (Dio) ── HTTPS ──► Express route ──► SQLite
   │                                   │
   │                                   └── Socket.IO emit
   │
   └── SocketService ── WebSocket ──► Socket.IO handler
                                          │
                                          └── emit event
   ▲                                          │
   └──────── stream event → notifier cập nhật state → widget rebuild
```

- Dữ liệu bền vững (tài khoản, hồ sơ, feed, lịch sử chat) đi qua REST.
- Sự kiện tức thời (tin nhắn, presence, ghép đôi, phòng, cuộc gọi) đi qua Socket.IO.
- WebRTC chỉ dùng Socket.IO để trao đổi SDP/ICE; media đi trực tiếp giữa hai thiết bị.

---

## 2. Khởi động app và khôi phục phiên

**File chính:** `lib/main.dart`, `lib/app/router.dart`, `lib/data/api/api_client.dart`, `lib/data/api/socket_client.dart`, `lib/data/repositories/auth_repository.dart`.

### 2.1. Trình tự khởi động

1. `main()` gọi `WidgetsFlutterBinding.ensureInitialized()`.
2. `installCertificatePinning()` cài pin SHA-256 cho HTTPS.
3. Đọc `server_host` từ `SharedPreferences`; nếu có thì `AppConfig.applyServerHost(savedHost)`.
4. `runApp(ProviderScope(child: MyApp()))`.
5. `_MyAppState.initState()`:
   - `outbox.init()` → nếu đang online thì `outbox.flush()`.
   - Nghe `user:wallet` → `AuthNotifier.applyWallet(coins, diamonds)`.
   - Nghe `call:invite` → nếu `gInCall` thì từ chối; ngược lại push `CallPage(incoming: true)` lên `rootNavigatorKey`.
6. `_MyAppState.build()`:
   - `ref.watch(routerProvider)`.
   - `ref.listen(authProvider)`: đăng nhập → `socket.connect()`; đăng xuất → `socket.disconnect()`.
   - `ref.listen(connectivityProvider)`: offline → online thì connect socket và `outbox.flush()`.

### 2.2. Điều hướng theo trạng thái đăng nhập

`routerProvider` trong `lib/app/router.dart` redirect theo thứ tự:

```text
AuthStatus.restoring        → /splash
Chưa đăng nhập              → /login
Đã đăng nhập, thiếu hồ sơ   → /profile-setup
Đã đăng nhập, đủ hồ sơ      → /
```

### 2.3. Khôi phục phiên

`AuthNotifier` khởi tạo sẽ gọi `restore()`:

1. `ApiClient.loadTokens()` đọc access/refresh token từ `FlutterSecureStorage`.
2. Nếu không có token → `AuthStatus.unauthenticated`.
3. Nếu có → `GET /api/me`:
   - thành công → `AuthStatus.authenticated` + `UserModel`.
   - lỗi → `clearSession()` và chuyển `unauthenticated`.

`ApiClient.onSessionExpired` được gán về `AuthNotifier.sessionExpired`; khi refresh thất bại, app tự về màn đăng nhập.

---

## 3. Đăng ký, đăng nhập và quản lý token

**Client:** `lib/features/auth/login_page.dart`, `lib/data/repositories/auth_repository.dart`, `lib/data/api/api_client.dart`.
**Server:** `server/src/auth.js`, `server/src/security.js`, `server/src/db.js`.

### 3.1. Đăng ký

1. `LoginPage._submit()` kiểm tra email, mật khẩu ≥ 8 ký tự, tên ≥ 2 ký tự.
2. `AuthNotifier.register()` → `ApiClient.register()` → `POST /api/auth/register`.
3. Server:
   - validate email/mật khẩu/tên; kiểm tra email trùng.
   - `hashPassword()` dùng scrypt + salt ngẫu nhiên.
   - insert `users` với `profile_completed = 0`.
   - `issueTokenPair()` tạo access JWT 15 phút + refresh token 30 ngày; **chỉ lưu SHA-256 của refresh token** vào `refresh_tokens`.
4. Client lưu cặp token vào secure storage; `AuthState` chuyển `authenticated`.
5. Router thấy `profileCompleted == false` → chuyển `/profile-setup`.

### 3.2. Đăng nhập

1. `POST /api/auth/login` (rate limit 15 lần/15 phút theo IP + email).
2. Server tìm user theo email:
   - không tồn tại → vẫn chạy `hashPassword()` giả để thời gian phản hồi tương đương.
   - đang bị khóa → trả `423 locked`.
   - sai mật khẩu → tăng `failed_attempts`; đủ 5 lần khóa 15 phút.
3. Đúng mật khẩu → reset bộ đếm, cấp token mới, trả user + token.
4. Client lưu token và cập nhật `AuthState`; router vào trang chính.

### 3.3. Làm mới token khi gặp 401

1. `ApiClient` gắn `Authorization: Bearer <accessToken>` ở `onRequest`.
2. Response 401 (không phải endpoint refresh, chưa retry):
   - gọi `_refreshTokens()` một lần duy nhất (single-flight).
   - `POST /api/auth/refresh` với refresh token.
3. Server:
   - hash refresh token, tìm trong `refresh_tokens`.
   - token đã `revoked` → **thu hồi toàn bộ family** (phát hiện dùng lại).
   - token hết hạn → 401.
   - hợp lệ → revoke token cũ, cấp cặp token mới cùng `family_id`.
4. Client lưu token mới và gửi lại request gốc **một lần**.
5. Refresh thất bại → `clearSession()`, gọi `onSessionExpired` → về đăng nhập.

### 3.4. Đăng xuất và đổi mật khẩu

- **Đăng xuất:** `AuthNotifier.logout()` → `POST /api/auth/logout` (revoke refresh token) → xóa token local → `AuthState.unauthenticated` → socket disconnect.
- **Đổi mật khẩu:** `ProfilePage` mở dialog → `AuthNotifier.changePassword()` → `POST /api/me/password`.
  - Server kiểm tra mật khẩu cũ, hash mật khẩu mới, **revoke toàn bộ refresh token cũ**, trả cặp token mới.
  - Client lưu token mới; các thiết bị khác phải đăng nhập lại.

---

## 4. Hồ sơ, avatar và tìm kiếm người dùng

**Client:** `lib/features/auth/profile_setup_page.dart`, `lib/features/profile/edit_profile_page.dart`, `lib/features/profile/public_profile_page.dart`, `lib/features/chat/friends_page.dart`, `lib/features/chat/search_users_page.dart`.
**Server:** `server/src/routes.js` (nhóm hồ sơ/bạn bè), `server/src/catalog.js`, `server/src/db.js`.

### 4.1. Thiết lập/chỉnh sửa hồ sơ

1. Màn hình đọc user hiện tại từ `currentUserProvider` để điền sẵn.
2. `appCatalogProvider` tải `GET /api/catalog` → lấy danh sách avatar/sở thích hợp lệ.
3. Người dùng chọn avatar emoji hoặc upload ảnh; nhập tên, tuổi, giới tính, bio, tags.
4. `AuthNotifier.completeProfile()` → `ApiClient.updateMe()` → `PATCH /api/me`:
   - `validateProfileOptions` kiểm tra avatar/tags/tuổi 16–80/giới tính/photos.
   - server chuẩn hóa và ghi `users`, đặt `profile_completed = 1`.
5. Response trả user mới; `AuthState` cập nhật; router cho vào trang chính.

### 4.2. Upload ảnh

1. `pickAndUploadImage()` mở thư viện ảnh, giới hạn `maxWidth`, nén `quality`.
2. Đọc bytes → `ApiClient.uploadImage()` tạo data URL base64.
3. `POST /api/upload`:
   - chỉ nhận `image/jpeg|png|webp`;
   - giải mã, giới hạn 5 MB;
   - ghi file vào `server/uploads/` với tên ngẫu nhiên;
   - trả `{ url: "/uploads/..." }`.
4. Client lưu URL vào hồ sơ/bài viết/tin nhắn; UI hiển thị qua `AppConfig.absoluteUrl(url)`.

### 4.3. Hồ sơ công khai, tìm kiếm, bạn bè

- **Tìm kiếm:** `SearchUsersPage` debounce nhập liệu → `GET /api/users?q=...` → danh sách user kèm `isOnline`.
- **Hồ sơ công khai:** `PublicProfilePage` nhận `userId` (+ `initial` để render ngay) → `GET /api/users/:id` → user, `isFriend`, `isOnline`.
- **Nhắn tin:** `POST /api/conversations/ensure` → mở `ChatDetailPage`.
- **Gọi:** mở `CallPage` với `callId` mới; server kiểm tra online/bận khi nhận `call:invite`.
- **Bạn bè:** `GET /api/friends` trả bạn bè kèm `conversationId`; bấm vào mở chat.

---

## 5. Feed

**Client:** `lib/features/feed/feed_page.dart`, `lib/features/feed/create_post_page.dart`, `lib/data/repositories/chat_repository.dart` (`FeedNotifier`, `CommentsNotifier`).
**Server:** `server/src/routes.js` (nhóm FEED/BÌNH LUẬN), `server/src/socket.js` (không xử lý feed, chỉ routes phát event).

### 5.1. Tải feed và phân trang

1. `HomePage.initState()` gọi `feedProvider.notifier.load()`.
2. `FeedNotifier.load()` → `GET /api/feed` (mặc định 30 bài).
3. Server lấy danh sách `posts` theo `created_at`/`before`; với mỗi bài gọi `postWithStats()`:
   - đếm like từ `post_likes`;
   - đếm comment từ `comments`;
   - `likedByMe` theo user đang đăng nhập;
   - tách `originalPost` nếu `media[0]` là JSON snapshot của bài repost.
4. `FeedPage` watch `feedProvider` và render `ListView`.
5. Cuộn gần cuối → `loadMore()` dùng cursor `before = bài cuối.createdAt`; server trả trang cũ hơn; client loại trùng theo `id`.

**Vì sao dùng cursor:** bài mới realtime được chèn lên đầu, nếu dùng offset thì các trang sau sẽ bị lệch và bỏ sót bài.

### 5.2. Đăng bài

1. `CreatePostPage` chọn ảnh (upload lấy URL), nhập nội dung.
2. `FeedNotifier.addPost()` → `POST /api/feed`.
3. Server kiểm tra có nội dung hoặc media, tối đa 9 media; insert `posts`; phát `feed:new`.
4. Client thêm bài vào đầu danh sách; máy khác nhận `feed:new` qua `feedRealtimeProvider` và `applyRealtime()`.

### 5.3. Like/unlike

1. `_PostCard` gọi `toggleLike(post.id)`.
2. `FeedNotifier.toggleLike()` cập nhật **optimistic** (đảo `likedByMe`, tăng/giảm số like).
3. `POST /api/feed/:id/like`:
   - server toggle bản ghi trong `post_likes`;
   - trả `likes` và `likedByMe` thật;
   - phát `feed:stats` cho các client khác.
4. Client đối chiếu response; lỗi mạng → rollback về trạng thái trước.

### 5.4. Bình luận

**Mở sheet:**

1. Bấm icon bình luận → `_showComments()` mở `showModalBottomSheet` (`isScrollControlled: true`).
2. `_CommentsSheet.initState()` gọi `commentsProvider(postId).notifier.load()`.
3. `GET /api/feed/:id/comments` trả toàn bộ comment kèm `userName`, `userAvatar`.
4. Sheet subscribe `feed:comment:new/updated/deleted`, lọc theo `postId`.

**Gửi bình luận:**

1. `_submit()` đọc text, kiểm tra mạng, gọi `CommentsNotifier.add(text)`.
2. `POST /api/feed/:id/comments`:
   - validate nội dung 1–500 ký tự;
   - insert `comments`;
   - đếm lại số comment;
   - phát `feed:stats` (số lượng) và `feed:comment:new` (nội dung + tác giả).
3. Response HTTP trả `comment`; client `applyAdded()` (khử trùng theo `id`).
4. Socket event cũng đi qua `applyAdded()`; nếu response về trước thì event bị bỏ qua do trùng `id`.
5. Sheet cuộn tới bình luận mới; số lượng trên feed cập nhật qua `feed:stats`.

**Sửa/xóa:**

- Chỉ chủ bình luận được sửa; chủ bình luận hoặc chủ bài được xóa.
- Server phát `feed:comment:updated` / `feed:comment:deleted`; sheet cập nhật danh sách, xóa thì đếm lại.

**Bàn phím không che ô nhập:**

- `_CommentsSheet.build()` đọc `MediaQuery.viewInsets.bottom`.
- `AnimatedPadding(bottom: keyboardInset)` đẩy nội dung lên; chiều cao sheet = `(screenHeight - keyboardInset) * 0.9`.
- Không đặt padding này ở builder bên ngoài vì builder chỉ chạy lúc mở sheet, khi bàn phím chưa hiện.

### 5.5. Chia sẻ và repost

1. `_showShareOptions()` mở 2 lựa chọn: chia sẻ hệ điều hành hoặc đăng lại.
2. **Chia sẻ ngoài:** `SharePlus.instance.share()`; chỉ khi `ShareResultStatus.success` mới gọi `POST /api/feed/:id/share` với `{ confirmed: true }`.
3. **Repost:** `POST /api/feed/:id/share` với `{ repostContent }`:
   - server tạo bài mới của người đăng lại;
   - lưu snapshot bài gốc dạng JSON trong `media`;
   - tăng `shares_count` bài gốc;
   - phát `feed:new` + `feed:stats`.
4. Client thêm bài repost vào feed; UI render thẻ trích dẫn bài gốc.

### 5.6. Sửa/xóa bài

- Chỉ chủ bài được sửa/xóa.
- `PATCH /api/feed/:id` cập nhật nội dung; `DELETE /api/feed/:id` xóa bài.
- Server phát `feed:updated` / `feed:deleted`; client `updatePost()` / `removePost()`.

### 5.7. Đồng bộ realtime của feed

`feedRealtimeProvider` trong `lib/data/repositories/chat_repository.dart` đăng ký:

| Event | Xử lý |
|---|---|
| `feed:new` | thêm bài mới lên đầu |
| `feed:updated` | thay bài, giữ `likedByMe` của mình |
| `feed:deleted` | xóa bài khỏi danh sách |
| `feed:stats` | cập nhật like/comment/share |
| `feed:comment:*` | cập nhật danh sách comment đang mở |
| `connect` | tải lại feed sau khi mất mạng |

---

## 6. Chat 1-1

**Client:** `lib/features/chat/chat_list_page.dart`, `lib/features/chat/chat_detail_page.dart`, `lib/data/repositories/chat_repository.dart`, `lib/core/network/outbox.dart`.
**Server:** `server/src/routes.js` (nhóm hội thoại/tin nhắn), `server/src/socket.js` (`chat:typing`).

### 6.1. Danh sách hội thoại

1. `HomePage.initState()` gọi `chatProvider.notifier.load()`.
2. `GET /api/conversations`:
   - join user đối phương;
   - lấy `last_message`, `last_message_at`;
   - subquery đếm tin chưa đọc của mình;
   - trả `isOnline` từ bộ nhớ presence.
3. `ConversationModel` render danh sách; `presence:changed` cập nhật chấm online.
4. Tin đến realtime → `ChatNotifier.applyIncoming()` cập nhật tin cuối + tăng unread nếu không phải mình gửi.

### 6.2. Mở chat và tải lịch sử

1. `ChatDetailPage.initState()`:
   - `messagesProvider(conversationId).notifier.load()` → `GET /api/conversations/:id/messages`.
   - server kiểm tra thành viên, đánh dấu `is_read = 1` cho tin của đối phương.
   - client `chatProvider.clearUnread(conversationId)`.
2. Subscribe socket: `chat:message`, `chat:message-edited`, `chat:message-deleted`, `chat:typing`.
3. Cuộn lên đầu → `loadMore()` dùng `before = tin đầu.createdAt`; chèn tin cũ vào đầu và bù scroll offset.

### 6.3. Gửi tin (optimistic + outbox)

1. `_send()` xóa ô nhập ngay, gọi `MessagesNotifier.send(text)`.
2. `send()` tạo tin tạm `local_<timestamp>` và thêm vào state (optimistic).
3. `POST /api/conversations/:id/messages` với `clientMessageId = tempId`.
4. Server:
   - kiểm tra thành viên;
   - validate nội dung;
   - insert `messages`;
   - cập nhật `conversations.last_message`;
   - phát `chat:message` cho **cả hai** user, kèm `clientMessageId`.
5. Client nhận response hoặc socket:
   - thay tin tạm bằng tin thật nếu khớp `clientMessageId`;
   - nếu đã có `id` thật thì bỏ qua để không trùng.
6. Nếu gửi lỗi:
   - xóa tin optimistic;
   - `Outbox.enqueue(conversationId, content)` lưu vào `SharedPreferences`;
   - khi có mạng, `_MyAppState` hoặc connectivity listener gọi `outbox.flush()` → gửi lại tuần tự, thành công thì xóa khỏi hàng đợi.

### 6.4. Nhận tin realtime

1. Server phát `chat:message` với `{ conversationId, message, clientMessageId? }`.
2. `ChatDetailPage` lọc đúng hội thoại → `MessagesNotifier.applyIncoming()`.
3. `ChatNotifier.applyIncoming()` cập nhật danh sách hội thoại (tin cuối, unread, online).
4. Nếu hội thoại chưa có trong danh sách (vừa kết bạn) → gọi lại `load()`.

### 6.5. Typing, sửa, xóa

- **Typing:** `_notifyTyping()` giới hạn 2 giây/lần → `chat:typing` → server relay cho đối phương → UI hiện “đang gõ...”, tự tắt sau 3 giây.
- **Sửa:** `PATCH /api/conversations/:id/messages/:mid` (chỉ người gửi) → server phát `chat:message-edited` → `applyEdited()`.
- **Xóa:** `DELETE .../:mid` → server phát `chat:message-deleted` → `applyDeleted()`.

### 6.6. Gửi ảnh

1. `_sendImage()` → `pickAndUploadImage()` (nén + upload).
2. `MessagesNotifier.send(url, type: MessageType.image)`.
3. Server chỉ chấp nhận URL `/uploads/...` cho tin loại ảnh; trả `type = image`.
4. UI render `Image.network` thay vì text URL.

---

## 7. Gọi thoại/video 1-1

**Client:** `lib/features/call/call_page.dart`, `lib/features/call/rtc_session.dart`, `lib/main.dart`.
**Server:** `server/src/socket.js` (nhóm call signaling), `server/src/catalog.js` (`call.ringingTimeoutSeconds`).

### 7.1. Bắt đầu cuộc gọi

- Từ chat hoặc hồ sơ công khai → mở `CallPage` với `peerId`, `callId`, `isVideo`.
- `CallPage.initState()`:
  - tải cấu hình chuông từ `appCatalogProvider`;
  - subscribe `call:accepted`, `call:rejected`, `call:ended`, `call:error`, `rtc:signal`;
  - nếu là cuộc gọi đến, chờ người dùng bấm nghe/từ chối.

### 7.2. Luồng gọi đi

1. `_invite()` đảm bảo socket đã kết nối (chờ tối đa 8 giây).
2. `emit('call:invite', { to, callId, isVideo })`.
3. Server:
   - kiểm tra `callId` chưa tồn tại, caller/callee không bận, callee đang online;
   - lưu `activeCalls[callId]` với trạng thái `ringing`;
   - đặt timeout theo `ringingTimeoutSeconds` (mặc định 45 giây);
   - phát `call:invite` tới mọi socket của callee.
4. Người nhận bấm nghe → `call:accept`:
   - server kiểm tra đúng cặp caller/callee và trạng thái `ringing`;
   - chuyển `accepted`, hủy timeout;
   - phát `call:accepted` cho caller.
5. Hai bên tạo `RtcSession`:
   - caller `initiator: true` → tạo offer;
   - callee `initiator: false` → chờ offer, tạo answer;
   - SDP/ICE gửi qua `rtc:signal`; server chỉ relay nếu cuộc gọi đã `accepted` và đúng cặp user.
6. `RtcSession` xử lý signaling tuần tự; ICE đến sớm được xếp hàng; khi `connected`, UI chuyển “Đã kết nối”.

### 7.3. Từ chối, cúp máy, timeout

- **Từ chối:** `call:reject` → server xóa `activeCalls`, phát `call:rejected` cho caller.
- **Cúp máy:** `call:hangup` → server xóa cuộc gọi, phát `call:ended` cho đầu kia.
- **Timeout chuông:** server tự xóa và phát `call:ended(reason: timeout)`; client cũng có timer dự phòng và gọi `call:hangup` nếu quá hạn.
- **Mất kết nối:** socket `disconnecting` dọn cuộc gọi và báo đầu còn lại.

### 7.4. Vì sao server giữ trạng thái cuộc gọi?

- Chặn gọi chồng, gọi người offline, giả mạo `callId`.
- Chỉ relay SDP/ICE sau khi người nhận accept.
- Không tin `to`/`callId` do client gửi nếu không khớp cặp đã lưu.

---

## 8. Soul Game (ghép đôi ẩn danh)

**Client:** `lib/features/matching/soul_game_page.dart`.
**Server:** `server/src/socket.js` (nhóm Soul Game), `server/src/catalog.js` (`matching.*`).

### 8.1. Vào hàng đợi và ghép đôi

1. `SoulGamePage.initState()` kiểm tra socket đã kết nối; nếu chưa thì báo và đóng.
2. Tải cấu hình `textSeconds`, `heartUnlockAfterSeconds` từ `appCatalogProvider`.
3. `emit('soul:queue', { mode: 'text' })` (mặc định text).
4. Server:
   - xóa socket khỏi hàng đợi cũ;
   - tìm người cùng `mode`, khác `userId`;
   - nếu có → tạo `sessionId`, room `soul:<id>`, lưu `soulSessions`;
   - đặt timer hết giờ theo `textSeconds` (180 giây);
   - đặt timer mở nút tim sau `heartUnlockAfterSeconds` (10 giây);
   - phát `soul:matched` cho cả hai (một bên `initiator: true`).
5. Nếu chưa có ai → `soul:queued`, chờ.

### 8.2. Chat ẩn danh

- Gửi: `soul:message` → server kiểm tra thành viên/phiên còn hiệu lực → relay cho đối phương.
- Nhận: `soul:message` → thêm bong bóng chat.
- Server đếm số tin; đủ 5 tin → phát `soul:heart-available`.

### 8.3. Nút tim và thích hai chiều

1. UI chỉ bật tim khi nhận `soul:heart-available` (do đủ 5 tin hoặc đủ 10 giây).
2. `soul:like`:
   - server kiểm tra thành viên, phiên chưa kết thúc, tim đã mở;
   - ghi userId vào `session.likes`;
   - phát `soul:like:received` cho đối phương, `soul:like:sent` cho mình.
3. Nếu cả hai đã thích → server:
   - tạo `conversations`, `friendships`;
   - phát `soul:mutual-like` kèm user thật + `conversationId`;
   - client chuyển sang `ChatDetailPage`.

### 8.4. Hết giờ, gia hạn, hiện danh tính

- Hết giờ: server phát `soul:time-ended`; client hiện sheet kết thúc.
- `soul:continue`: chỉ hợp lệ khi phiên đã hết giờ; server đặt lại timer và phát `soul:continued`.
- `soul:reveal`: server kiểm tra thành viên, tạo hội thoại + bạn bè, phát `soul:revealed` kèm thông tin thật.
- `soul:leave` / đóng trang: rời phiên, phát `soul:partner-left` cho đối phương.

### 8.5. Chống gian lận

- Client không thể tự đổi `endsAt`; server giữ mốc thời gian.
- `soul:finish` chỉ có tác dụng khi mốc server đã hết; gửi sớm bị bỏ qua.
- Chỉ thành viên đúng phiên mới gửi tin/thích/reveal.

---

## 9. Voice Game (ghép voice + WebRTC)

**Client:** `lib/features/matching/voice_game_page.dart`.
**Server:** `server/src/socket.js` (queue mode `voice`), `server/src/catalog.js` (`matching.voiceSeconds`).

1. `VoiceGamePage` phát `soul:queue` với `{ mode: 'voice' }`.
2. Server chỉ ghép với người cùng mode `voice`; thời lượng 90 giây.
3. `soul:matched` trả `initiator`; client gọi `_startRtc(initiator: ...)`.
4. SDP/ICE đi qua `soul:rtc:signal`; server kiểm tra đúng thành viên phiên.
5. Hết giờ → `soul:time-ended`; người dùng có thể `soul:continue` hoặc tìm người mới.
6. `soul:revealed` → tạo hội thoại và chuyển sang chat 1-1.
7. Đóng trang → `soul:leave`, dispose `RtcSession` và tắt mic/loa.

---

## 10. Phòng tiệc

**Client:** `lib/features/room/room_list_page.dart`, `lib/features/room/room_detail_page.dart`, `lib/data/repositories/chat_repository.dart` (`RoomsNotifier`).
**Server:** `server/src/routes.js` (nhóm phòng), `server/src/socket.js` (room chat/RTC), `server/src/catalog.js` (quà).

### 10.1. Danh sách và tạo phòng

1. `HomePage` gọi `roomsProvider.notifier.load()` → `GET /api/rooms`.
2. Server trả phòng + `memberCount`/`memberAvatars` từ `roomMembers` (bộ nhớ socket).
3. Tạo phòng: dialog nhập tên/chủ đề/emoji → `POST /api/rooms`.
4. Server validate tên 2–40, chủ đề ≤ 80; insert `rooms`; trả phòng mới; client `roomsProvider.prepend()`.

### 10.2. Vào phòng

1. `RoomDetailPage.initState()`:
   - `_loadHistory()` → `GET /api/rooms/:id/messages` (100 tin gần nhất).
   - sau khi có lịch sử mới `emit('room:join', { roomId })` để không lỡ tin mới.
2. Server thêm user vào `roomMembers`, socket join room `room:<id>`, phát `room:presence` cho cả phòng.
3. Client subscribe `room:message`, `room:presence`, `room:heart`, `room:gift`, `room:error`, `room:rtc:*`.

### 10.3. Gửi tin, thả tim

- **Tin nhắn:** `_send()` → `POST /api/rooms/:id/messages`; server insert `room_messages`, phát `room:message`; client thêm ngay và khử trùng theo `id` khi socket echo về.
- **Thả tim:** `room:heart` → server kiểm tra thành viên → phát `room:heart` cho người khác; client hiện hiệu ứng.

### 10.4. Gửi quà (trừ Xu)

1. `_loadRoomGifts()` tải `appCatalogProvider` (đã có từ `GET /api/catalog`) → danh sách quà + giá.
2. Chọn quà → `emit('room:gift', { roomId, gift: id })`.
3. Server:
   - kiểm tra thành viên phòng;
   - `chargeRoomGift()` tìm quà trong catalog server, **không tin giá client**;
   - `UPDATE users SET coins = coins - ? WHERE id = ? AND coins >= ?` (atomic, không âm);
   - thất bại → `room:error`; thành công → `user:wallet` cho người gửi + `room:gift` cho phòng.
4. Client cập nhật số dư qua event `user:wallet`, hiện quà trong phòng.

### 10.5. Mic mesh WebRTC

1. Bật mic → `room:rtc:join`; server thêm user vào `rtcRoomPeers`, trả `room:rtc:peers` (danh sách đang mic) và phát `room:rtc:joined`.
2. Người vào sau nhận peers; người đã ở trong phòng tạo offer khi có người mới.
3. Mỗi cặp dùng một `RtcSession` riêng; SDP/ICE đi qua `room:rtc:signal`, server kiểm tra thành viên.
4. Tắt mic/rời phòng → `room:rtc:leave`, đóng peer, phát `room:rtc:left`.
5. Rời trang: hủy subscription → tắt mic/peer → `room:leave` → server cập nhật `roomMembers` và phát presence.

---

## 11. Catalog, ví và VIP

**Client:** `lib/data/repositories/catalog_repository.dart`, `lib/features/profile/wallet_page.dart`, `lib/features/profile/vip_page.dart`, `lib/features/room/room_detail_page.dart`.
**Server:** `server/src/catalog.js`, `server/src/routes.js` (nhóm CATALOG).

### 11.1. Tải catalog

1. `appCatalogProvider` gọi `GET /api/catalog` một lần, cache trong Riverpod.
2. `AppCatalog.fromJson()` parse: profile, rooms.gifts, wallet, vip, matching, call.
3. Các màn hình dùng chung provider: hồ sơ, ví, VIP, quà phòng, thời lượng game/gọi.

### 11.2. Ví và VIP

- `WalletPage` hiển thị số Xu/Kim cương từ `currentUserProvider`; bảng giá từ catalog.
- `VipPage` hiển thị quyền lợi/gói từ catalog.
- **Chưa bật mua:** `wallet.purchasesEnabled = false`, `vip.purchasesEnabled = false`; nút nạp/mua bị khóa. Không có API cộng Xu/cấp VIP tự động.
- Số dư thay đổi thật khi tặng quà phòng; server phát `user:wallet`.

### 11.3. Quy tắc giá quà

`APP_CATALOG.rooms.gifts` là nguồn duy nhất. `chargeRoomGift(database, userId, giftId)`:

1. Tìm quà theo `id`; không có → `invalid_gift`.
2. Trừ Xu bằng câu UPDATE có điều kiện `coins >= cost`; không đủ → `insufficient_coins`.
3. Trả số dư mới + thông tin quà; socket mới phát quà cho phòng.

---

## 12. Mạng, socket và offline

**Client:** `lib/core/network/connectivity_service.dart`, `lib/core/network/outbox.dart`, `lib/data/api/socket_client.dart`, `lib/main.dart`.
**Server:** `server/src/socket.js` (presence).

### 12.1. Kết nối socket

1. `SocketService.connect()` đọc access token từ secure storage.
2. Tạo socket tới `AppConfig.socketUrl` với query `token`, transport WebSocket, bật reconnect.
3. Đăng ký danh sách event server → `_relay()` vào `StreamController.broadcast` theo từng event.
4. Widget dùng `socket.on(event).listen(...)` và hủy subscription khi dispose.
5. Đăng xuất → `disconnect()` đóng socket nhưng giữ stream; app dispose → `dispose()` đóng cả stream.

### 12.2. Presence

- Khi socket connect: server thêm socket vào `presence[userId]`; nếu là socket đầu tiên → phát `presence:changed { online: true }`.
- Khi disconnect: xóa socket; nếu là socket cuối → phát `presence:changed { online: false }`.
- Danh sách chat và hồ sơ cập nhật trạng thái online từ event này.

### 12.3. Offline và outbox

1. Tin nhắn gửi thất bại → `Outbox.enqueue()` lưu `{conversationId, content}` vào `SharedPreferences`.
2. Khi app mở lại → `outbox.init()`.
3. Khi connectivity chuyển offline → online → `outbox.flush()`.
4. `flush()` gửi tuần tự `POST /api/conversations/:id/messages`; thành công thì xóa item; lỗi thì dừng và thử lại lần sau.

### 12.4. Thêm một sự kiện socket mới

Khi bổ sung event realtime, phải làm đủ 3 bước:

1. Server `emit('ten:event', payload)`.
2. Thêm `'ten:event'` vào danh sách `events` trong `SocketService.connect()` — nếu thiếu, `on()` sẽ không nhận dữ liệu.
3. Widget/repository `socket.on('ten:event').listen(...)` và cập nhật state.

---

## 13. Bảng tra nhanh

| Chức năng | Điểm vào UI | Hàm/provider chính | API / event | Bảng DB |
|---|---|---|---|---|
| Đăng ký | `login_page.dart` | `AuthNotifier.register` | `POST /api/auth/register` | `users`, `refresh_tokens` |
| Đăng nhập | `login_page.dart` | `AuthNotifier.login` | `POST /api/auth/login` | `users`, `refresh_tokens` |
| Khôi phục phiên | `main.dart` | `AuthNotifier.restore` | `GET /api/me` | `users` |
| Refresh token | `api_client.dart` | `ApiClient._refreshTokens` | `POST /api/auth/refresh` | `refresh_tokens` |
| Hồ sơ | `profile_setup_page.dart`, `edit_profile_page.dart` | `AuthNotifier.completeProfile` | `PATCH /api/me` | `users` |
| Upload ảnh | `image_tools.dart` | `pickAndUploadImage` | `POST /api/upload` | file trên đĩa |
| Feed | `feed_page.dart` | `FeedNotifier.load/loadMore` | `GET /api/feed` | `posts`, `post_likes`, `comments` |
| Đăng bài | `create_post_page.dart` | `FeedNotifier.addPost` | `POST /api/feed` | `posts` |
| Like | `feed_page.dart` | `FeedNotifier.toggleLike` | `POST /api/feed/:id/like` | `post_likes` |
| Bình luận | `feed_page.dart` | `CommentsNotifier` | `GET/POST/PATCH/DELETE /api/feed/:id/comments` | `comments` |
| Chia sẻ/repost | `feed_page.dart` | `FeedNotifier.sharePost` | `POST /api/feed/:id/share` | `posts` |
| Danh sách chat | `chat_list_page.dart` | `ChatNotifier.load` | `GET /api/conversations` | `conversations`, `messages` |
| Gửi tin | `chat_detail_page.dart` | `MessagesNotifier.send` | `POST /api/conversations/:id/messages` | `messages`, `conversations` |
| Chat realtime | `chat_detail_page.dart` | `applyIncoming` | `chat:message` | — |
| Gọi 1-1 | `call_page.dart` | `_invite`, `_accept`, `RtcSession` | `call:*`, `rtc:signal` | — (bộ nhớ) |
| Soul Game | `soul_game_page.dart` | `_loadOptionsAndQueue`, listener | `soul:*` | `friendships`, `conversations` khi reveal |
| Voice Game | `voice_game_page.dart` | `_startRtc`, listener | `soul:*` | `friendships`, `conversations` khi reveal |
| Phòng | `room_detail_page.dart` | `_loadHistory`, `_send` | `room:*`, REST phòng | `rooms`, `room_messages` |
| Quà phòng | `room_detail_page.dart` | `chargeRoomGift` (server) | `room:gift`, `user:wallet` | `users.coins` |
| Catalog | `catalog_repository.dart` | `appCatalogProvider` | `GET /api/catalog` | — (hằng số server) |

---

## 14. Gỡ lỗi theo triệu chứng

| Triệu chứng | Kiểm tra đầu tiên |
|---|---|
| Đăng nhập xong quay lại login | `AuthNotifier.restore`, token trong secure storage, router redirect |
| API trả 401 liên tục | refresh token còn hạn/không bị revoke; `ApiClient._refreshTokens` |
| Feed không có bài mới | `feedProvider.load`, `feed:new`, socket đã connect chưa |
| Bình luận không hiện | `POST /api/feed/:id/comments`, `commentsProvider(postId)`, filter `postId` trong socket |
| Ô nhập bình luận bị bàn phím che | `MediaQuery.viewInsets.bottom` trong `_CommentsSheet`, `AnimatedPadding` bên trong sheet |
| Tin nhắn không realtime | event `chat:message` có trong danh sách `SocketService` chưa; server có emit cho cả hai user không |
| Gửi tin khi offline mất | `Outbox.enqueue`, `outbox.flush` khi connectivity online |
| Cuộc gọi không có tiếng/hình | quyền mic/camera, SDP/ICE, STUN; mạng NAT đối xứng cần TURN |
| Không nhận được cuộc gọi | socket online, `gInCall`, `call:invite`, `CallPage(incoming)` |
| Gửi quà báo lỗi | quà có trong catalog không, đủ Xu không, user có trong phòng không |
| Mic phòng không hoạt động | `room:rtc:join`, `room:rtc:peers`, `RtcSession`, quyền micro |

---

## 15. Ghi chú khi bảo trì

- **Server là nguồn sự thật:** không tin giá quà, thời lượng phiên, `likedByMe`, số dư do client gửi.
- **Thêm API:** khai báo trong `server/src/routes.js` (hoặc `auth.js`), thêm hàm gọi ở `ApiClient`/repository, xử lý lỗi bằng `ApiException`.
- **Thêm bảng/cột SQLite:** schema hiện dùng `CREATE TABLE IF NOT EXISTS`, không tự migrate database đã tồn tại. Cần viết migration hoặc xóa database local khi phát triển.
- **Thêm event socket:** cập nhật đồng thời server emit, danh sách event trong `SocketService`, và listener ở UI.
- **Ảnh:** luôn upload qua `/api/upload` và dùng URL `/uploads/...`; không nhận URL ngoài cho tin nhắn ảnh.
- **Bảo mật:** không commit `server/config.json`, `server/certs/`, database, upload hoặc APK; xem `.gitignore`.
