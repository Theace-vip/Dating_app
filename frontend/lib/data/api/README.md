# `frontend/lib/data/api/` — vận chuyển (HTTP + WebSocket)

**Vai trò:** hai client duy nhất nói chuyện với backend. Không chứa nghiệp vụ, không giữ danh sách hiển thị.
**Ai gọi tới:** các file trong `data/repositories/` và `core/network/outbox.dart`; `main.dart` chỉ dùng `socketProvider` để connect/disconnect.
**Gọi đi:** `https://<server>/api/*` (Dio) và `https://<server>` qua Socket.IO.

## File trong thư mục

| File | Nội dung chính |
|---|---|
| `api_client.dart` | `ApiException` (message + status để UI hiện lỗi thân thiện). `apiClientProvider`. `ApiClient`: `loadTokens()`, `_saveTokens()`, `clearSession()` (secure storage); `register()`, `login()`, `getMe()`, `updateMe()`, `changePassword()`, `logoutOnServer()`, `uploadImage(bytes)`; `get/post/patch/delete` trả phần `data` của JSON; interceptor gắn `Authorization: Bearer`, gặp 401 thì `_refreshTokens()` **một lần** (single-flight) rồi gửi lại request gốc; refresh thất bại → `onSessionExpired`. |
| `socket_client.dart` | `socketProvider`. `SocketService`: `connect()` đọc token từ secure storage, mở socket với `transports: websocket`, `enableReconnection()`; danh sách `events` đăng ký sẵn; `on(event)` trả `Stream` broadcast (nhiều widget cùng nghe); `emit()`; `disconnect()`/`dispose()`; các event vòng đời `connect`, `connect_error` được chuẩn hoá thành stream `bool`. |

## Luồng một lời gọi REST

```text
repositories/*.dart
   └── apiClient.get('/api/conversations')
         └── api_client.dart: _get()
               ├── onRequest: gắn Bearer access token
               ├── Dio → https://<host>/api/conversations   (cert pin ở core/network/pinning.dart)
               ├── 401 → _refreshTokens() → POST /api/auth/refresh → lưu token mới → gửi lại 1 lần
               └── 2xx → trả res.data['data'] hoặc body
```

## Luồng một sự kiện realtime

```text
backend/src/socket.js: emitToUser()/io.to(...).emit()
   └── socket_client.dart: _socket.on(event) → _relay(event, data)
         └── StreamController.broadcast()  →  Stream cho event
               └── chat_detail_page.dart / feedRealtimeProvider / room_detail_page.dart ...
```

## Thêm event realtime mới

1. Server phát event (`backend/src/socket.js` hoặc `routes.js`).
2. Thêm tên event vào danh sách `events` trong `socket_client.dart: connect()` — **thiếu bước này client không nhận được**.
3. Lắng nghe ở notifier hoặc màn hình, nhớ `cancel()` khi dispose.

## Ghi chú

- `ApiClient` là provider thường (không autoDispose) để giữ token/refresh đang xử lý; `SocketService` cũng là singleton toàn app.
- Không đặt URL ở đây: địa chỉ lấy từ `AppConfig` (`core/constants/app_config.dart`).
- Upload ảnh đi qua `POST /api/upload` dạng data URL base64; server trả `/uploads/<tên>`, UI dùng `AppConfig.absoluteUrl()`.
