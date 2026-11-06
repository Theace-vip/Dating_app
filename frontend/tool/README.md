# `frontend/tool/` — script kiểm tra phía client

**Vai trò:** công cụ chạy bằng Dart thuần (không mở app, không cần điện thoại) để kiểm tra nhanh kết nối và bảo mật giữa client và backend.
**Chạy:** `cd frontend && dart run tool/client_smoke.dart` (backend phải đang chạy).

## File trong thư mục

| File | Nội dung |
|---|---|
| `client_smoke.dart` | Smoke test client: (1) **certificate pinning** — chặn certificate sai, chấp nhận đúng pin; (2) **REST** — đăng nhập qua HTTPS, gọi `/api/me`; (3) **Socket.IO** — mở socket có token và chờ kết nối. In `✓`/`✗` cho từng mục và đếm `passed`/`failed`. |

## Cách hoạt động

```text
dart run tool/client_smoke.dart
   ├── HttpOverrides tạm thời: pin sai  → phải bị từ chối (kỳ vọng lỗi)
   ├── pin đúng (AppConfig.certPinningSha256) → gọi được
   ├── Dio POST /api/auth/login (demo1@soulmate.app) → nhận access token
   ├── Dio GET /api/me với Bearer      → xác nhận token dùng được
   └── socket_io_client connect tới AppConfig.socketUrl kèm token
```

## Khi nào dùng

- Sau khi chạy lại `backend/scripts/gen-cert.js` (đổi cert → kiểm tra pin còn đúng không).
- Sau khi đổi địa chỉ server/tunnel.
- Trước khi build APK để chắc backend trả lời được.

## Ghi chú

- Script dùng chung `AppConfig` và `pinning.dart` với app, nên kiểm tra đúng logic thật của app.
- Không phải test tự động trong CI: cần backend đang chạy và database có tài khoản demo.
- Muốn thêm kiểm tra (ví dụ `/api/feed`), thêm bước vào `main()` và in kết quả qua `ok(cond, tên)`.
