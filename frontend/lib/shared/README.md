# `frontend/lib/shared/` — tiện ích và widget dùng chung

**Vai trò:** những thành phần được nhiều màn hình dùng lại nhưng không thuộc một nghiệp vụ cụ thể: upload ảnh, đổi địa chỉ server, bộ widget giao diện cơ bản.
**Ai gọi tới:** `features/*` (chat, feed, room, profile, auth), `main.dart` (gián tiếp qua dialog đổi server).
**Gọi đi:** `data/api/api_client.dart` (upload, kiểm tra `/health`), `core/constants/app_config.dart`, `core/theme/app_theme.dart`, `data/repositories/auth_repository.dart` (làm mới sau khi đổi server).

## File / thư mục

| Đường dẫn | Nội dung |
|---|---|
| `image_tools.dart` | `pickAndUploadImage(ref, {maxWidth, quality})`: mở thư viện ảnh (`image_picker`), nén theo kích thước/chất lượng, đọc bytes → `ApiClient.uploadImage()` → `POST /api/upload`, trả URL `/uploads/...` (hoặc `null` nếu người dùng huỷ). `isNetworkAvatar()` phân biệt URL ảnh với emoji. |
| `server_host.dart` | `saveServerHost(ref, raw)`: `AppConfig.applyServerHost()` + lưu `SharedPreferences('server_host')` + kiểm tra `/health`. `showServerHostDialog()`: dialog nhập IP/URL máy chủ, dùng khi app không kết nối được. |
| `widgets/` | Bộ widget nền dùng chung — xem [`widgets/README.md`](widgets/README.md). |

## Luồng upload ảnh (dùng ở chat, feed, hồ sơ)

```text
features/... gọi pickAndUploadImage()
   ├── ImagePicker.pickImage(...)                  → bytes
   ├── nén (maxWidth/quality)
   └── ApiClient.uploadImage(bytes)                 data/api/api_client.dart
         └── POST /api/upload {dataUrl: 'data:image/jpeg;base64,...'}
               └── backend/src/routes.js: /upload  → ghi backend/uploads/<id>.jpg
                     └── {url: '/uploads/img_xxx.jpg'}
   └── UI dùng AppConfig.absoluteUrl(url) để hiển thị
```

## Luồng đổi máy chủ

```text
profile_page.dart (menu ⋯) hoặc login_page.dart (khi lỗi kết nối)
   └── showServerHostDialog(context, ref)
         └── saveServerHost(ref, '192.168.1.5')      shared/server_host.dart
               ├── AppConfig.applyServerHost(...)    (apiBaseUrl + socketUrl đổi ngay)
               ├── SharedPreferences.setString('server_host', ...)
               └── kiểm tra GET /health → thông báo kết quả
```

## Quy ước

1. Hàm ở đây phải **không phụ thuộc nghiệp vụ** — nếu cần biết "bài viết" hay "hội thoại" thì để ở repository.
2. Widget dùng chung không tự gọi API; nhận dữ liệu qua tham số.
3. Mọi tiện ích có `BuildContext` phải kiểm tra `context.mounted` sau `await`.
4. Không đặt hằng số cấu hình ở đây — dùng `core/constants/app_config.dart`.
