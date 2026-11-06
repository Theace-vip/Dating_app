# `frontend/lib/data/` — lớp dữ liệu

**Vai trò:** cầu nối duy nhất giữa app và backend. Gồm 3 tầng: `api/` (vận chuyển), `models/` (hình dạng dữ liệu), `repositories/` (state + nghiệp vụ phía client).
**Ai gọi tới:** toàn bộ `features/` (qua `ref.watch`/`ref.read`), `main.dart`, `core/network/outbox.dart`.
**Gọi đi:** `backend/` qua HTTPS (Dio) và Socket.IO.

## Thư mục con

| Thư mục | Nội dung | README |
|---|---|---|
| `api/` | `ApiClient` (REST, token, refresh), `SocketService` (một socket, mỗi event một `Stream`) | [`api/README.md`](api/README.md) |
| `models/` | `models.dart` — toàn bộ model JSON dùng chung | [`models/README.md`](models/README.md) |
| `repositories/` | State toàn app: auth, chat/feed/rooms, bạn bè, catalog | [`repositories/README.md`](repositories/README.md) |

## Luồng dữ liệu một chiều

```text
UI (features/)
  │ ref.watch(provider)            ← đọc state
  │ ref.read(provider.notifier)    ← gọi hành động
  ▼
repositories/  (StateNotifier)
  │ ApiClient.get/post/...        ← REST cho dữ liệu bền vững
  │ socket.on('...')              ← realtime cho dữ liệu thay đổi liên tục
  ▼
api/api_client.dart  |  api/socket_client.dart
  │ JSON → models.dart            ← parse
  ▼
state mới → UI rebuild
```

## Quy ước

1. **Không gọi `Dio`/`Socket` trong widget.** Mọi thứ đi qua repository.
2. **Server là nguồn sự thật.** Optimistic update chỉ để UI mượt; phản hồi server/socket luôn thắng.
3. **Khử trùng theo `id`** khi cùng một bản ghi có thể đến từ cả REST và socket (tin nhắn, bình luận, bài viết).
4. **Model null-safe:** mọi `fromJson` chịu được thiếu trường; dữ liệu lạ bị bỏ qua thay vì crash.
5. **Provider đặt tên hậu tố `Provider`**, notifier là `StateNotifier` cùng file với provider.
