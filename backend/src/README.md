# `backend/src/` — mã nguồn server

**Vai trò:** 8 file chứa toàn bộ xử lý phía server. Thứ tự nạp: `index.js` → `config.js` → `db.js` → `auth.js` → `routes.js` → `socket.js` → `catalog.js` / `security.js`.
**Ai gọi tới:** app Flutter qua HTTPS (`/api/*`) và WebSocket; các file trong `scripts/` khi chạy kiểm thử.

## File trong thư mục

| File | Vai trò | Hàm/đoạn chính |
|---|---|---|
| `index.js` | Điểm khởi động: dựng HTTPS (cert tự ký), gắn helmet/CORS/JSON limit/rate limit, phục vụ `/uploads`, mount `/api/auth` và `/api` sau middleware, gắn Socket.IO, in IP LAN + cert pin. | `ensureCert()`, `app.use('/api', authMiddleware, apiRouter)`, `initSocket(server)` |
| `config.js` | Xác định `serverRoot`, đọc/ghi `config.json`, giá trị mặc định cổng 3000, JWT secret, thời hạn access/refresh token. | `config`, `serverRoot` |
| `db.js` | Mở SQLite (`data/soulmate.db`), bật WAL + foreign keys, tạo schema (users, refresh_tokens, friendships, conversations, messages, posts, post_likes, comments, rooms, room_messages), seed 2 tài khoản demo, helper dùng chung. | `publicUser()`, `getUser()`, `getUserByEmail()`, `ensureConversation()`, `addFriendship()`, `db.prepare()` |
| `auth.js` | Router `/api/auth`: đăng ký, đăng nhập (khóa sau 5 lần sai), refresh (xoay token, phát hiện dùng lại), logout; middleware Bearer; rate limit. | `authMiddleware()`, `issueTokenPair()`, `validPassword()` |
| `security.js` | Mật mã: hash mật khẩu scrypt + salt, so sánh timing-safe, ký/verify JWT, sinh refresh token ngẫu nhiên, hash token, sinh ID. | `hashPassword()`, `verifyPassword()`, `signAccessToken()`, `verifyAccessToken()`, `hashToken()`, `randomId()` |
| `routes.js` | Toàn bộ REST nghiệp vụ dưới `/api`: catalog, upload, hồ sơ/bạn bè, hội thoại/tin nhắn, feed/bình luận, phòng. Mỗi route ghi xong phát sự kiện realtime. | `router.get('/conversations/:id/messages')`, `router.post('/conversations/:id/messages')`, `emitToUserSafe()`, `emitFeedSafe()` |
| `socket.js` | Kênh realtime: xác thực handshake, presence, Soul Game (queue/session/timer/heart/reveal), gọi 1-1 (WebRTC signaling), phòng (chat/heart/gift/mic mesh), dọn dẹp khi ngắt. | `initSocket()`, `emitToUser()`, `isOnline()`, `roomPresenceList()` |
| `catalog.js` | Nguồn sự thật cho dữ liệu nghiệp vụ tĩnh: avatar, sở thích, quà + giá, gói Xu, VIP, thời lượng Soul Game, thời gian đổ chuông; trừ Xu khi tặng quà. | `APP_CATALOG`, `chargeRoomGift()` |

## Đường đi của một request

```text
frontend/lib/data/api/api_client.dart
   │ HTTPS (cert pin)
   ▼
index.js  app.use('/api', authMiddleware, apiRouter)
   │ authMiddleware (auth.js) → verifyAccessToken (security.js) → req.userId
   ▼
routes.js  <route tương ứng>
   ├── db.js  db.prepare(...).get/run/all        ← SQLite
   ├── catalog.js  (giá quà, gói Xu, thời lượng)
   └── emitToUserSafe / emitFeedSafe  → socket.js: emitToUser()
                                             │ io.to('user:<id>').emit(...)
                                             ▼
                                    frontend/lib/data/api/socket_client.dart
```

## Chat 1-1 — phía server (đối chiếu với `frontend/lib/features/chat/`)

| Bước | Code | Việc xảy ra |
|---|---|---|
| 1 | `routes.js: router.get('/conversations')` | Danh sách hội thoại + tin cuối + số chưa đọc + `isOnline()` |
| 2 | `routes.js: router.post('/conversations/ensure')` | `ensureConversation()` (`db.js`) — sắp xếp cặp `user_a < user_b` để không tạo trùng; phát `conversations:changed` cho đối phương |
| 3 | `routes.js: findConversationFor()` | Chỉ thành viên mới đọc/ghi; người ngoài nhận 404 (không lộ sự tồn tại) |
| 4 | `routes.js: router.get('/conversations/:id/messages')` | `UPDATE messages SET is_read = 1` cho tin của đối phương, trả tối đa 100 tin + `hasMore` (phân trang `before`) |
| 5 | `routes.js: router.post('/conversations/:id/messages')` | Validate nội dung ≤ 2000; ảnh chỉ nhận URL `/uploads/...`; `INSERT messages` + `UPDATE conversations.last_message`; phát `chat:message` cho **cả hai** bên kèm `clientMessageId` |
| 6 | `routes.js: PATCH/DELETE .../:mid` | Chỉ người gửi được sửa/xoá → phát `chat:message-edited` / `chat:message-deleted` |
| 7 | `socket.js` handler `chat:typing` | Kiểm tra thành viên hội thoại trong DB rồi `emitToUser(partner, 'chat:typing')` |

## Sự kiện realtime do thư mục này phát ra

| Nhóm | Sự kiện | Phát từ |
|---|---|---|
| Chat | `chat:message`, `chat:message-edited`, `chat:message-deleted`, `chat:typing` | `routes.js`, `socket.js` |
| Presence | `presence:changed` | `socket.js` (first/last socket) |
| Hội thoại / bạn bè | `conversations:changed`, `friends:changed` | `routes.js`, `socket.js` |
| Hồ sơ / ví | `user:updated`, `user:wallet` | `routes.js`, `socket.js` |
| Feed | `feed:new`, `feed:updated`, `feed:deleted`, `feed:stats`, `feed:comment:new/updated/deleted` | `routes.js` (`emitFeedSafe`) |
| Phòng | `room:presence`, `room:message`, `room:heart`, `room:gift`, `room:error`, `rooms:changed`, `room:rtc:*` | `socket.js` |
| Soul Game | `soul:queued`, `soul:matched`, `soul:message`, `soul:heart-available`, `soul:like:*`, `soul:mutual-like`, `soul:revealed`, `soul:continued`, `soul:time-ended`, `soul:partner-left`, `soul:rtc:signal` | `socket.js` |
| Gọi điện | `call:invite`, `call:accepted`, `call:rejected`, `call:ended`, `call:error`, `rtc:signal` | `socket.js` |

> Thêm event mới phải khai báo tên ở `frontend/lib/data/api/socket_client.dart` (danh sách `events`) thì client mới nhận được.

## Quy ước khi sửa

1. **Không tin dữ liệu client gửi**: giá quà, thời lượng phiên, quyền vào phòng, quyền sửa tin đều kiểm tra lại ở server.
2. Route mới: đặt trong đúng nhóm comment `// ===== ... =====` của `routes.js`, validate input trước khi ghi DB.
3. Sau khi ghi DB phải phát sự kiện để các client khác đồng bộ (dùng `emitToUserSafe` / `emitFeedSafe`).
4. Truy vấn SQL luôn dùng tham số (`?` / `@name`), không nối chuỗi.
5. Thay đổi schema: sửa `db.js`; DB cũ chưa có migration nên phải xoá `data/soulmate.db` hoặc tự viết `ALTER TABLE`.
