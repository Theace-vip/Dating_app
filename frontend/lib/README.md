# `frontend/lib/` — mã nguồn ứng dụng Flutter

**Vai trò:** toàn bộ UI, state và lớp gọi API/socket của app SoulMate. Không có dữ liệu mẫu: mọi thứ hiển thị đều đến từ backend.
**Ai gọi tới:** `main()` trong `main.dart` (điểm vào), các file trong `test/`, `tool/`, `integration_test/`.
**Gọi đi:** REST + Socket.IO tới `backend/`; `SharedPreferences`/secure storage cho cấu hình và token.

## Cấu trúc

```text
lib/
├── main.dart          Điểm vào: pinning, khôi phục host, ProviderScope, listener toàn app
├── app/               router.dart — điều hướng + redirect theo trạng thái đăng nhập
├── core/              nền tảng: hằng số, theme, mạng/offline/pinning
├── data/              api (Dio, Socket.IO), models (JSON), repositories (state)
├── features/          màn hình theo nghiệp vụ: auth, chat, feed, home, matching, room, call, profile
└── shared/            widget + tiện ích dùng chung (avatar, nút, upload ảnh, đổi server)
```

Chi tiết từng thư mục con có `README.md` riêng — xem mục lục ở [`docs/README.md`](../../docs/README.md).

## Thứ tự chạy khi mở app

```text
main.dart: main()
  ├── installCertificatePinning()          core/network/pinning.dart
  ├── AppConfig.applyServerHost(savedHost) core/constants/app_config.dart
  └── runApp(ProviderScope(child: MyApp()))
        │
        ├── router.dart: routerProvider  → đọc authProvider → chọn màn hình
        ├── auth_repository.dart: restore() → GET /api/me (nếu có token)
        ├── main.dart: listener user:wallet / user:updated / call:invite
        └── main.dart: authProvider đổi → socket.connect() / disconnect()
```

## Ba lớp, không được trộn

| Lớp | Ở đâu | Quy ước |
|---|---|---|
| Giao diện | `features/`, `shared/widgets/` | Chỉ đọc state qua `ref.watch`, gọi hành động qua `ref.read(...notifier)`. Không gọi `Dio` trực tiếp. |
| Trạng thái | `data/repositories/` | `StateNotifier` giữ danh sách, optimistic update, nghe socket, gọi `ApiClient`. |
| Vận chuyển | `data/api/` | `ApiClient` (REST + token + refresh), `SocketService` (một socket, mỗi event một `Stream`). |

`data/models/models.dart` là hợp đồng dữ liệu dùng chung cho cả ba lớp.

## Điểm vào của từng chức năng

| Chức năng | Màn hình | State | API chính |
|---|---|---|---|
| Đăng nhập | `features/auth/login_page.dart` | `authProvider` | `/api/auth/*`, `/api/me` |
| Chat | `features/chat/chat_list_page.dart` → `chat_detail_page.dart` | `chatProvider`, `messagesProvider` | `/api/conversations*` + socket `chat:*` |
| Feed | `features/feed/feed_page.dart` | `feedProvider`, `commentsProvider` | `/api/feed*` |
| Phòng | `features/room/room_list_page.dart` → `room_detail_page.dart` | `roomsProvider` + socket | `/api/rooms*` + socket `room:*` |
| Soul/Voice Game | `features/matching/*` | state cục bộ + socket | socket `soul:*` |
| Gọi điện | `features/call/call_page.dart` | state cục bộ + `RtcSession` | socket `call:*`, `rtc:signal` |
| Cá nhân | `features/profile/profile_page.dart` | `authProvider`, `myPostsProvider`, `friendsProvider` | `/api/me`, `/api/feed?userId=`, `/api/friends` |

## Cần sửa gì thì vào đâu

| Việc | File |
|---|---|
| Đổi địa chỉ server mặc định | `core/constants/app_config.dart` |
| Đổi màu, font, khoảng cách | `core/theme/app_theme.dart`, `core/constants/app_style.dart` |
| Đổi luồng điều hướng | `app/router.dart` |
| Thêm API mới | `data/api/api_client.dart` → `data/repositories/*` → UI |
| Thêm sự kiện realtime | `data/api/socket_client.dart` (khai báo tên) → notifier xử lý |
| Thêm model | `data/models/models.dart` |
| Xử lý mất mạng | `core/network/connectivity_service.dart`, `core/network/outbox.dart` |

## Quy ước khi thêm file

1. Màn hình mới → `features/<nghiệp vụ>/`, dùng `ConsumerWidget`/`ConsumerStatefulWidget`.
2. State dùng chung nhiều màn hình → `data/repositories/`, không giữ trong `State` của widget.
3. Mọi thao tác ghi dữ liệu đi qua repository → `ApiClient`; UI không tự gọi HTTP.
4. Hủy `StreamSubscription` và `Timer` trong `dispose()`.
5. Đầu mỗi file giữ comment mô tả mục đích + vai trò (đã áp dụng cho toàn bộ 41 file `.dart`).
