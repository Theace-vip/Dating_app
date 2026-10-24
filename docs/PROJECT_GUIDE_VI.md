# Hướng dẫn cấu trúc và luồng code SoulMate

Tài liệu dành cho người mới đọc source. Ứng dụng gồm Flutter (giao diện iOS/Android) và backend Node.js + Express + Socket.IO + SQLite.

> Muốn xem luồng chạy chi tiết theo từng chức năng (đăng nhập, feed, chat, gọi, Soul Game, phòng), đọc [`CODE_FLOWS_VI.md`](CODE_FLOWS_VI.md).
> Muốn tra nhanh một thư mục/file dùng để làm gì, đọc [`FILE_GUIDE_VI.md`](FILE_GUIDE_VI.md). Flutter gọi API HTTPS để đọc/ghi dữ liệu; Socket.IO dùng cho sự kiện tức thời; WebRTC truyền âm thanh/video trực tiếp giữa hai thiết bị.

## 1. Thư mục chính

```text
.
├── lib/                         # Ứng dụng Flutter
│   ├── main.dart                # Khởi chạy, pinning, socket toàn app và cuộc gọi đến
│   ├── app/router.dart          # Điều hướng GoRouter và điều kiện đăng nhập
│   ├── core/                    # Cấu hình, theme, mạng, outbox, certificate pinning
│   ├── data/
│   │   ├── api/                 # ApiClient HTTPS/token và SocketService (Dart streams)
│   │   ├── models/              # Model JSON dùng chung cho UI và repository
│   │   └── repositories/        # StateNotifier/Provider, REST và đồng bộ realtime
│   ├── features/                # Các màn hình theo nghiệp vụ
│   │   ├── auth/                # Đăng nhập, tạo hồ sơ, splash
│   │   ├── call/                # CallPage (UI/state) và RtcSession (WebRTC/media)
│   │   ├── chat/                # Danh sách, bạn bè, tìm kiếm và chat 1-1
│   │   ├── feed/                # Feed, bình luận, share sheet, repost và đăng bài
│   │   ├── matching/            # Soul Game và Voice Game
│   │   ├── profile/             # Hồ sơ công khai, ví, kết nối máy chủ
│   │   └── room/                # Phòng nhóm, tin nhắn và mic mesh
│   └── shared/                  # Widget và công cụ UI dùng chung
├── server/
│   ├── src/index.js             # Khởi động HTTPS, middleware và gắn Socket.IO
│   ├── src/auth.js              # Xác thực, access/refresh token
│   ├── src/routes.js            # REST API, kiểm tra quyền và thao tác nghiệp vụ
│   ├── src/socket.js            # Presence, realtime feed/chat và call signaling
│   ├── src/db.js                # Schema SQLite, seed và helper DB
│   ├── src/security.js          # Hash mật khẩu, JWT và mã định danh
│   └── scripts/                 # Sinh chứng chỉ và smoke/integration tests
├── test/                        # Unit/widget tests của Flutter
├── integration_test/            # Kiểm thử tích hợp Flutter
├── tool/                        # Script kiểm tra app/client
└── docs/PROJECT_GUIDE_VI.md     # Hướng dẫn cấu trúc và luồng chính
```

## 2. Một request dữ liệu đi qua đâu?

1. Widget trong `lib/features/` đọc state bằng Riverpod Provider.
2. `lib/data/repositories/` chuyển thao tác thành lệnh qua `ApiClient` hoặc `SocketService`.
3. `ApiClient` thêm Bearer token, gửi HTTPS tới `/api/...`; server kiểm tra token rồi `routes.js` validate input và thao tác SQLite qua helper trong `db.js`.
4. Khi thay đổi cần đồng bộ ngay, server phát sự kiện Socket.IO. `SocketService` phân phối event thành Dart stream; repository cập nhật state để widget render lại.
5. WebRTC chỉ gửi offer/answer/ICE qua Socket.IO để trao đổi thông tin kết nối. Âm thanh/video thực tế truyền peer-to-peer, không đi qua REST.

## 3. Gọi thoại/video 1-1 (bạn bè hoặc người lạ)

- Từ chat, `ChatDetailPage` mở `CallPage`; từ hồ sơ công khai cũng có thể gọi thoại/video nếu người đó online. `peerId`/`callId` định tuyến phiên, không bắt buộc hai bên là bạn bè; server từ chối nếu offline/đang bận.
- `main.dart` nghe `call:invite`, đẩy giao diện nhận cuộc gọi lên root navigator; nếu app đang có phiên khác thì tự từ chối. Màn nhận tự timeout sau 45 giây để không giữ cuộc gọi ringing mãi.
- Người nhận bấm nghe máy: client gửi `call:accept`; server xác nhận đúng cặp user/callId rồi thông báo người gọi. Người gọi tạo offer; người nhận tạo answer.
- `RtcSession` xin media (micro/camera), tạo `RTCPeerConnection`, gửi SDP/ICE qua socket và phát state/remote stream cho giao diện. ICE đến trước khi phiên sẵn sàng được xếp hàng, SDP/ICE xử lý tuần tự để tránh tranh chấp.
- Từ chối, cúp máy, timeout 45 giây, lỗi WebRTC hoặc mất kết nối đều đóng giao diện/phiên và báo cho đầu bên kia. Nút mic/camera/loa điều khiển track hoặc audio route.
- iOS cần các mô tả quyền `NSMicrophoneUsageDescription` và `NSCameraUsageDescription`; Android khai báo quyền trong `android/app/src/main/AndroidManifest.xml`.
- `AppConfig.iceServers` hiện có public STUN cho phát triển. Kết nối giữa một số mạng NAT/firewall cần TURN; nếu vẫn không nghe/nhìn thấy nhau khi signaling thành công thì cần cấu hình TURN server có credentials.

## 4. Feed, bình luận và chia sẻ

### Feed

- `FeedPage` vẽ danh sách `PostModel`; `FeedNotifier` tải trang đầu, phân trang và áp dụng like/stats/realtime.
- Bài đăng lưu trong bảng `posts`; số like và bình luận được tính từ bảng quan hệ, số share lưu ở `posts.shares_count`.
- `feed:stats` chỉ cập nhật các bộ đếm; `feed:new/updated/deleted` đồng bộ nội dung bài.

### Bình luận

- Sheet bình luận nạp dữ liệu từ `GET /api/feed/:id/comments`, gửi nội dung bằng `POST`, sửa/xóa bằng `PATCH/DELETE`.
- Server phát nguyên comment kèm tên/avatar cho mọi client qua `feed:comment:new`; sửa/xóa phát event riêng. Sheet chỉ áp dụng event của bài đang mở, loại trùng theo comment ID và cuộn tới bình luận mới.
- Server là nguồn chính xác của số đếm. Thao tác local/realtime cập nhật danh sách và tổng số dựa trên ID, không tăng/decrease mù khiến số bị sai.

### Chia sẻ

- Chạm share mở hai lựa chọn: share text/link qua share sheet của hệ điều hành hoặc tạo một bài repost mới trên feed (có caption tùy chọn và thẻ trích dẫn bài gốc).
- Chỉ kết quả SharePlus `success` mới gửi xác nhận tăng counter; đóng/hủy share sheet không ghi nhận. Repost được ghi nhận khi server đã tạo bài mới.
- Repost tạo bài feed mới của người đăng lại, lưu caption và snapshot tối thiểu của bài gốc; UI render bài gốc bên trong thẻ trích dẫn. Server phát `feed:new` và tăng counter bài gốc.
- Link ngoài hiện chỉ là URL định danh bài theo API host, chưa phải trang web/deep link công khai; người nhận có thể cần cài app/đăng nhập để mở nội dung.

## 5. Những file đáng đọc theo tác vụ

| Muốn tìm hiểu | Bắt đầu từ |
|---|---|
| Khởi động/đăng nhập/socket | `lib/main.dart`, `lib/app/router.dart`, `lib/data/repositories/auth_repository.dart` |
| Chat thường | `lib/features/chat/chat_detail_page.dart`, `lib/data/repositories/chat_repository.dart`, `server/src/routes.js` |
| Cuộc gọi | `lib/features/call/call_page.dart`, `lib/features/call/rtc_session.dart`, `lib/main.dart`, `server/src/socket.js` |
| Gọi người lạ từ hồ sơ | `lib/features/profile/public_profile_page.dart`, `server/src/routes.js` (trả trạng thái online) |
| Feed/bình luận/share | `lib/features/feed/feed_page.dart`, `lib/data/models/models.dart`, `lib/data/repositories/chat_repository.dart`, `server/src/routes.js` |
| Realtime | `lib/data/api/socket_client.dart`, `lib/data/repositories/chat_repository.dart`, `server/src/socket.js` |
| Schema và dữ liệu | `server/src/db.js` |

## 6. Lệnh kiểm tra

```bash
flutter test
flutter analyze
node --check server/src/socket.js
node --check server/src/routes.js
cd server && node scripts/socket_test.js
cd server && node scripts/realtime_feed_test.js
```

Các script Socket cần backend đang chạy trên `https://localhost:3000`, hai tài khoản seed còn tồn tại và chứng chỉ local đã có. Chúng xác minh API/signaling/realtime; không thay thế thử gọi thật trên hai thiết bị. Kiểm thử thiết bị thật cần hai tài khoản, quyền mic/camera được cấp và mạng có thể kết nối ICE/STUN (hoặc TURN).
