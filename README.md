# SoulMate 💜

Ứng dụng hẹn hò đa nền tảng (Flutter + Node.js) theo phong cách Litmatch: chat 1-1, feed cộng đồng, phòng tiệc, ghép đôi ẩn danh và gọi thoại/video WebRTC.

> **Trạng thái:** ứng dụng chạy thật với backend, SQLite và Socket.IO. Các phần cần dịch vụ bên thứ ba (thanh toán, OTP, Google Sign-In, push notification) chưa được bật.

## 1. Tính năng

### Đã hoạt động

| Nhóm | Chi tiết |
|---|---|
| **Tài khoản** | Đăng ký/đăng nhập email + mật khẩu qua REST API; access JWT 15 phút, refresh token xoay 30 ngày; khôi phục phiên, đăng xuất, đổi mật khẩu |
| **Hồ sơ** | Avatar emoji hoặc ảnh upload thật, tên, tuổi, giới tính, bio, sở thích, tối đa 9 ảnh; hồ sơ công khai và trạng thái online |
| **Chat 1-1** | Tin nhắn realtime, gửi ảnh, typing indicator, sửa/xóa tin, phân trang lịch sử, đánh dấu đã đọc, outbox tự gửi lại khi có mạng |
| **Gọi thoại/video** | WebRTC 1-1 từ chat hoặc hồ sơ công khai; màn hình gọi đến, mic/loa/camera, timeout chuông 45 giây |
| **Soul Game** | Ghép đôi ẩn danh theo hàng đợi server, chat realtime, mở nút tim sau 5 tin hoặc 10 giây, hiện danh tính và kết bạn |
| **Voice Game** | Hàng đợi riêng cho voice, thoại WebRTC trong phiên 90 giây |
| **Phòng tiệc** | Tạo phòng, chat nhóm realtime, thả tim, tặng quà trừ Xu thật, mic mesh WebRTC, danh sách thành viên online |
| **Feed** | Đăng bài kèm ảnh, like/unlike, bình luận (thêm/sửa/xóa), chia sẻ qua hệ điều hành, repost kèm bài gốc, phân trang |
| **Catalog** | Avatar, sở thích, quà phòng, gói Xu, VIP và thời lượng được định nghĩa một lần ở server và tải qua API |
| **Kết bạn** | Danh sách bạn bè, tìm kiếm theo tên/email, mở hội thoại và xem hồ sơ |
| **Mạng** | connectivity_plus hiển thị loại mạng, kiểm tra trước thao tác, socket tự kết nối lại, banner trạng thái |
| **Bảo vệ dữ liệu** | SQLite, backup VACUUM INTO, rate limit, khóa tài khoản sau 5 lần sai, HTTPS + certificate pinning |

### Chưa triển khai

- **Nạp Xu / mua VIP:** catalog và bảng giá đã có nhưng `purchasesEnabled: false`; chưa có cổng thanh toán và xác minh giao dịch phía server.
- **Đăng nhập SĐT/OTP và Google:** nút trên UI đang báo “sắp ra mắt”; cần Twilio/Firebase.
- **Push notification, TURN server, deploy chính thức:** dự án đang chạy local/tunnel.
- **Trang web/deep link công khai cho bài viết:** link share hiện chỉ định danh bài trong app.

## 2. Kiến trúc

```text
┌─────────────────────────────┐        HTTPS + JWT        ┌──────────────────────────────┐
│  Flutter app (Android/iOS)  │ ────────────────────────► │  Node.js + Express           │
│  Riverpod · Dio · GoRouter  │                           │  REST API /api/*             │
│                             │ ◄──────────────────────── │  SQLite (node:sqlite)        │
│  Socket.IO client           │   Socket.IO (realtime)    │  Socket.IO server            │
│  WebRTC (flutter_webrtc)    │ ◄──── SDP/ICE signaling ──│  WebRTC signaling            │
└──────────────┬──────────────┘                           └──────────────┬───────────────┘
               │                                                         │
               └──────────────── audio/video P2P ────────────────────────┘
```

- REST dùng cho dữ liệu bền vững (tài khoản, hồ sơ, feed, lịch sử chat).
- Socket.IO dùng cho sự kiện tức thời (presence, tin nhắn, ghép đôi, phòng, tín hiệu cuộc gọi).
- WebRTC truyền âm thanh/video trực tiếp giữa hai thiết bị; server chỉ chuyển tiếp offer/answer/ICE.
- Server là nguồn quyết định thời lượng phiên, giá quà, quyền tham gia phòng và trạng thái cuộc gọi.

## 3. Công nghệ

| Thành phần | Công nghệ |
|---|---|
| Client | Flutter 3.x, Dart 3.13+, Riverpod, GoRouter, Dio, Socket.IO client, flutter_webrtc |
| Backend | Node.js ≥ 22.5, Express 4, Socket.IO 4, `node:sqlite` |
| Lưu trữ | SQLite (WAL), file upload trên đĩa |
| Bảo mật | scrypt, JWT, refresh token rotation, helmet, rate limit, cert pinning SHA-256 |
| Kiểm thử | Flutter test/analyze, smoke test REST + Socket.IO bằng Node |

## 4. Cấu trúc thư mục

```text
dating_app/
├── lib/                         # Flutter client
│   ├── main.dart                # Khởi động, socket toàn app, cuộc gọi đến, outbox
│   ├── app/router.dart          # Điều hướng và guard đăng nhập
│   ├── core/                    # Cấu hình, theme, mạng, pinning
│   ├── data/
│   │   ├── api/                 # ApiClient (Dio + refresh token), SocketService
│   │   ├── models/              # Model JSON
│   │   └── repositories/        # Riverpod state + gọi API/realtime
│   ├── features/                # auth, chat, feed, room, matching, call, profile
│   └── shared/                  # Widget và tiện ích dùng chung
├── server/
│   ├── src/
│   │   ├── index.js             # HTTPS, middleware, mount router/socket
│   │   ├── auth.js              # register/login/refresh/logout
│   │   ├── routes.js            # REST API nghiệp vụ
│   │   ├── socket.js            # Presence, Soul Game, phòng, call signaling
│   │   ├── catalog.js           # Catalog + quy tắc trừ Xu
│   │   ├── db.js                # Schema SQLite, seed, helper
│   │   ├── security.js          # scrypt, JWT, token hash
│   │   └── config.js            # Cấu hình và secret cục bộ
│   ├── scripts/                 # gen-cert, backup_db, e2e/socket tests
│   ├── certs/                   # Chứng chỉ HTTPS (không commit)
│   ├── data/                    # soulmate.db + WAL (không commit)
│   └── uploads/                 # Ảnh người dùng (không commit)
├── test/                        # Unit test Flutter
├── integration_test/            # Kiểm thử tích hợp
├── docs/PROJECT_GUIDE_VI.md     # Hướng dẫn luồng code chi tiết
├── cai_dat.bat                  # Cài đặt một lần trên Windows
├── ket_noi_internet.bat         # Server + Cloudflare tunnel
├── sao_luu.bat                  # Sao lưu database
└── pubspec.yaml
```

## 5. Bắt đầu nhanh

### Yêu cầu

- Flutter SDK 3.47+ và Dart 3.13+
- Node.js ≥ 22.5 (dùng `node:sqlite`)
- Android SDK nếu build APK; thiết bị Android hoặc máy ảo

### 5.1. Chạy backend

```bash
cd server
npm install
npm run gen-cert     # chỉ lần đầu, tạo cert HTTPS + in SHA-256 pin
npm start            # https://localhost:3000
```

Lần chạy đầu, server tự tạo `server/data/soulmate.db`, seed tài khoản mẫu và sinh `server/config.json` nếu chưa có.

Kiểm tra nhanh:

```bash
curl -k https://localhost:3000/health
```

### 5.2. Chạy Flutter

```bash
flutter pub get
flutter run
```

Nếu chạy trên điện thoại thật qua cáp USB:

```bash
adb reverse tcp:3000 tcp:3000
```

App mặc định gọi `https://localhost:3000`. Có thể đổi máy chủ trong app tại **Cá nhân → thẻ Mạng → Máy chủ** (hỗ trợ IP LAN, `10.0.2.2` cho emulator, hoặc URL tunnel).

### 5.3. Tài khoản mẫu

```text
demo1@soulmate.app / Demo@1234
demo2@soulmate.app / Demo@1234
```

Chỉ được seed khi database trống. Nếu đã có dữ liệu, dùng chức năng đăng ký hoặc xóa database local để seed lại (**chỉ khi chấp nhận mất dữ liệu**).

## 6. Cấu hình và bí mật

- `server/config.json` chứa `jwtSecret`, thời hạn token và cổng; **không commit** (đã nằm trong `.gitignore`).
- Nếu file không tồn tại, server sinh secret ngẫu nhiên và ghi lại. Đổi/xóa file sẽ làm mọi phiên đăng nhập cũ mất hiệu lực.
- `server/certs/` chứa private key HTTPS; **không commit**.
- `server/data/`, `server/uploads/`, `server/backups/`, `dist/` và APK cũng bị loại khỏi Git.
- Mẫu cấu hình tham khảo: [`server/config.example.json`](server/config.example.json). Sao chép thành `server/config.json` nếu muốn tự đặt cổng/thời hạn token; không cần điền `jwtSecret`, server sẽ tự sinh và ghi lại.

## 7. API

Base URL: `https://<host>:3000/api`. Mọi endpoint (trừ `/api/auth/*`) yêu cầu header:

```http
Authorization: Bearer <accessToken>
```

### 7.1. Xác thực

| Method | Endpoint | Mô tả |
|---|---|---|
| POST | `/auth/register` | Đăng ký email/mật khẩu, trả user + token |
| POST | `/auth/login` | Đăng nhập, trả user + token |
| POST | `/auth/refresh` | Xoay refresh token; dùng lại token cũ → thu hồi cả family |
| POST | `/auth/logout` | Thu hồi refresh token hiện tại |

### 7.2. Hồ sơ, catalog, bạn bè

| Method | Endpoint | Mô tả |
|---|---|---|
| GET | `/catalog` | Toàn bộ catalog (hồ sơ, quà, ví, VIP, matching, call) |
| GET | `/rooms/catalog` | Danh mục quà phòng |
| GET | `/wallet/catalog` | Gói Xu và trạng thái mua |
| GET | `/vip/catalog` | Gói VIP và quyền lợi |
| GET | `/profile/options` | Avatar/sở thích hợp lệ |
| POST | `/upload` | Upload ảnh data URL (jpeg/png/webp ≤ 5 MB) |
| GET | `/me` | Hồ sơ hiện tại |
| PATCH | `/me` | Cập nhật hồ sơ; validate avatar/tuổi/giới tính/tags/photos |
| POST | `/me/password` | Đổi mật khẩu, thu hồi phiên cũ, trả token mới |
| GET | `/users?q=` | Tìm người dùng theo tên/email |
| GET | `/users/:id` | Hồ sơ công khai + `isOnline` + `isFriend` |
| GET | `/friends` | Danh sách bạn bè + `conversationId` |

### 7.3. Hội thoại và tin nhắn

| Method | Endpoint | Mô tả |
|---|---|---|
| GET | `/conversations` | Danh sách hội thoại, tin cuối, số chưa đọc |
| POST | `/conversations/ensure` | Tạo hoặc lấy hội thoại 1-1 |
| GET | `/conversations/:id/messages` | Lịch sử (cursor `before`, `limit`), đánh dấu đã đọc |
| POST | `/conversations/:id/messages` | Gửi tin (text/ảnh) + phát `chat:message` |
| PATCH | `/conversations/:id/messages/:mid` | Sửa tin của mình |
| DELETE | `/conversations/:id/messages/:mid` | Xóa tin của mình |

### 7.4. Feed, bình luận, phòng

| Method | Endpoint | Mô tả |
|---|---|---|
| GET | `/feed?limit=&before=` | Feed phân trang, kèm like/comment/share |
| POST | `/feed` | Đăng bài (nội dung và/hoặc media) |
| PATCH | `/feed/:id` | Sửa bài của mình |
| DELETE | `/feed/:id` | Xóa bài của mình |
| POST | `/feed/:id/like` | Toggle like |
| POST | `/feed/:id/share` | Ghi nhận share đã xác nhận hoặc tạo repost |
| GET | `/feed/:id/comments` | Danh sách bình luận |
| POST | `/feed/:id/comments` | Thêm bình luận + phát realtime |
| PATCH | `/feed/:id/comments/:cid` | Sửa bình luận của mình |
| DELETE | `/feed/:id/comments/:cid` | Xóa bình luận của mình (hoặc chủ bài) |
| GET | `/rooms` | Danh sách phòng + thành viên online |
| POST | `/rooms` | Tạo phòng |
| GET | `/rooms/:id/messages` | 100 tin gần nhất |
| POST | `/rooms/:id/messages` | Gửi tin phòng qua REST (dự phòng) |

Ngoài `/api`, server có `GET /health` công khai và `/uploads/<file>` phục vụ ảnh tĩnh.

## 8. Sự kiện Socket.IO

Kết nối cần access token:

```dart
io('https://host:3000', auth: {'token': accessToken});
```

### Client → server

| Nhóm | Sự kiện |
|---|---|
| Soul Game | `soul:queue`, `soul:message`, `soul:heart:unlock`, `soul:like`, `soul:reveal`, `soul:finish`, `soul:continue`, `soul:leave`, `soul:rtc:signal` |
| Gọi 1-1 | `call:invite`, `call:accept`, `call:reject`, `call:hangup`, `rtc:signal` |
| Phòng | `room:join`, `room:leave`, `room:message`, `room:heart`, `room:gift`, `room:rtc:join`, `room:rtc:leave`, `room:rtc:signal` |
| Chat | `chat:typing` |

### Server → client

| Nhóm | Sự kiện |
|---|---|
| Presence | `presence:changed` |
| Soul Game | `soul:queued`, `soul:matched`, `soul:message`, `soul:heart-available`, `soul:like:received`, `soul:like:sent`, `soul:mutual-like`, `soul:revealed`, `soul:time-ended`, `soul:continued`, `soul:partner-left`, `soul:queue:error`, `soul:like:error`, `soul:continue:error` |
| Gọi 1-1 | `call:invite`, `call:accepted`, `call:rejected`, `call:ended`, `call:error`, `rtc:signal` |
| Phòng | `room:presence`, `room:message`, `room:heart`, `room:gift`, `room:error`, `room:rtc:peers`, `room:rtc:joined`, `room:rtc:left`, `room:rtc:signal` |
| Chat | `chat:message`, `chat:message-edited`, `chat:message-deleted`, `chat:typing` |
| Feed | `feed:new`, `feed:updated`, `feed:deleted`, `feed:stats`, `feed:comment:new`, `feed:comment:updated`, `feed:comment:deleted` |
| Ví | `user:wallet` |

## 9. Dữ liệu và sao lưu

- Database: `server/data/soulmate.db` (SQLite, WAL). Các file `soulmate.db-wal` và `soulmate.db-shm` đi kèm khi server chạy.
- Ảnh upload: `server/uploads/`.
- Sao lưu: chạy `sao_luu.bat` (hoặc `node server/scripts/backup_db.js`), dùng `VACUUM INTO` để snapshot nhất quán, giữ 14 bản gần nhất trong `server/backups/`.
- Khi cần copy database thủ công: dừng server hoặc dùng script backup; không copy mỗi file `.db` khi WAL còn ghi.

## 10. Kiểm thử

```bash
# Flutter
flutter analyze
flutter test

# Backend: kiểm tra cú pháp
node --check server/src/index.js
node --check server/src/routes.js
node --check server/src/socket.js

# Smoke test cần server đang chạy tại https://localhost:3000
cd server
node scripts/e2e_test.js       # 31 check gần nhất
node scripts/e2e_test2.js      # 36 check gần nhất
node scripts/socket_test.js    # 50 check gần nhất
```

`e2e_test.js` kiểm tra auth/profile/feed/chat/phòng; `e2e_test2.js` kiểm tra upload, phân trang, sửa/xóa và realtime cơ bản; `socket_test.js` kiểm tra catalog, giao dịch quà, Soul Game, phòng và WebRTC signaling.

Các script dùng chứng chỉ self-signed local (`NODE_TLS_REJECT_UNAUTHORIZED=0`) và cần hai tài khoản demo còn trong database. Chúng không thay thế kiểm thử thủ công trên hai thiết bị thật.

## 11. Build APK

```bash
flutter build apk --release
```

Kết quả: `build/app/outputs/flutter-apk/app-release.apk`.

> Cấu hình hiện tại ký release bằng **debug keystore** để cài thử nhanh. Trước khi phát hành Play Store, tạo release keystore riêng, cấu hình `signingConfigs` và bảo vệ `key.properties`.

APK local có thể đặt trong `dist/` (đã bị `.gitignore` loại trừ, không đẩy lên Git).

## 12. Bảo mật

| Hạng mục | Cách làm |
|---|---|
| Mật khẩu | scrypt (N=16384, salt 16 byte), so sánh timing-safe |
| Access token | JWT 15 phút, ký bằng secret trong `server/config.json` |
| Refresh token | 30 ngày, xoay mỗi lần refresh; phát hiện dùng lại và thu hồi cả family |
| Đăng nhập | Rate limit 15 lần/15 phút theo IP + email; sai 5 lần khóa 15 phút |
| Truyền dữ liệu | HTTPS self-signed + certificate pinning SHA-256 ở app |
| Lưu token | FlutterSecureStorage (Android Keystore/iOS Keychain) |
| API | Helmet, CORS, giới hạn JSON 10 MB, rate limit toàn cục, SQL tham số hóa |
| Upload | Chỉ jpeg/png/webp, tối đa 5 MB, đổi tên ngẫu nhiên |
| Quyền | Kiểm tra thành viên hội thoại/phòng và chủ sở hữu bài/tin trước khi sửa/xóa |
| Release APK | R8/ProGuard bật (xem `android/app/proguard-rules.pro`) |

**Không commit** `server/config.json`, `server/certs/`, database, ảnh upload hoặc APK. Nếu secret bị lộ, đổi `jwtSecret` và thu hồi toàn bộ refresh token.

## 13. Giới hạn hiện tại

- Chưa có thanh toán thật; không cộng Xu/cấp VIP tự động.
- Chưa có OTP SĐT/Google Sign-In/push notification.
- WebRTC dùng STUN công cộng; mạng NAT đối xứng có thể cần TURN.
- Server chạy local hoặc qua Cloudflare tunnel; chưa có deploy VPS/domain chính thức.
- Chưa có trang web công khai cho bài viết được chia sẻ.
- SQLite phù hợp cho demo/một server; khi mở rộng cần cân nhắc PostgreSQL và hàng đợi.

## 14. Xử lý sự cố

| Hiện tượng | Cách xử lý |
|---|---|
| App báo không kết nối được | Kiểm tra server đang chạy, `adb reverse tcp:3000 tcp:3000`, hoặc nhập lại IP/tunnel trong **Cá nhân → Mạng → Máy chủ** |
| Sai certificate pin | Chạy lại `npm run gen-cert`, cập nhật `AppConfig.certPinningSha256` rồi build lại app |
| Tunnel đổi URL | Mỗi lần chạy `ket_noi_internet.bat`, nhập URL mới vào app |
| Điện thoại cùng WiFi không vào được | Chạy `mo_ket_noi_mang.bat` một lần để mở firewall cổng 3000 |
| Lỗi `PUB_CACHE` trên Windows | Đặt `PUB_CACHE` cùng ổ với project, ví dụ `D:\flutter_pub_cache` |
| Quên mật khẩu demo | Xóa `server/data/soulmate.db` khi server dừng để seed lại (mất dữ liệu) |

## 15. Tài liệu

- [`docs/CODE_FLOWS_VI.md`](docs/CODE_FLOWS_VI.md) — **luồng chạy code chi tiết của từng chức năng** (auth, hồ sơ, feed, chat, gọi, Soul Game, phòng, ví).
- [`docs/FILE_GUIDE_VI.md`](docs/FILE_GUIDE_VI.md) — **danh mục từng thư mục/từng file** và nên sửa ở đâu.
- [`docs/PROJECT_GUIDE_VI.md`](docs/PROJECT_GUIDE_VI.md) — cấu trúc thư mục, WebRTC, feed/bình luận và các file nên đọc.
- [`README.md`](README.md) — tài liệu tổng quan này.

---

Dự án phục vụ học tập/demo. Khi triển khai thật, cần bổ sung thanh toán, TURN, push notification, backup định kỳ và giám sát server.
