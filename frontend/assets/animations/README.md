# `frontend/assets/animations/` — animation thô

**Vai trò:** chỗ dành cho file animation chưa thuộc định dạng Lottie/SVGA (ví dụ JSON tự viết, sprite sheet, Rive).
**Hiện trạng:** **trống** (chỉ có `.gitkeep`). Thực tế dự án dùng `assets/lottie/` cho hiệu ứng JSON và `assets/svga/` cho quà trong phòng.

## Quy ước đặt animation

| Định dạng | Thư mục đúng |
|---|---|
| Lottie (`.json` Bodymovin) | `assets/lottie/` |
| SVGA (`.svga`) | `assets/svga/` |
| Ảnh động sprite/GIF | `assets/animations/` (thư mục này) |
| Video | Không đóng gói; phát từ URL |

## Nếu thêm file vào đây

1. Đặt file, tên không dấu (`confetti.json`, `heart_sprite.png`).
2. Thư mục đã khai báo trong `pubspec.yaml`, không cần sửa.
3. Dùng: `Image.asset()` cho sprite, hoặc đọc bytes nếu tự parse.
4. Ghi rõ file dùng ở màn hình nào vào bảng dưới đây.

| File | Dùng ở đâu |
|---|---|
| _(chưa có)_ | — |
