# `frontend/assets/images/` — ảnh tĩnh

**Vai trò:** chỗ đặt ảnh tĩnh đóng gói cùng app (nền, banner, minh hoạ).
**Hiện trạng:** **trống** (chỉ có `.gitkeep`). Mọi ảnh người dùng (avatar, ảnh bài viết, ảnh chat) đều nằm ở server `backend/uploads/` và được tải qua `/uploads/...`, không đóng gói vào app.

## Khi nào dùng thư mục này

| Dùng | Không dùng |
|---|---|
| Logo, ảnh nền cố định, minh hoạ màn hình giới thiệu | Ảnh người dùng upload (→ `backend/uploads/`) |
| Hình cho trạng thái rỗng nếu muốn thay emoji | Ảnh bài viết (→ `/api/upload` rồi lưu URL trong DB) |

## Cách dùng

1. Đặt file vào đây (tên không dấu, không khoảng trắng, ví dụ `onboarding_bg.png`).
2. Thư mục đã khai báo trong `pubspec.yaml` (`assets/images/`) nên không cần sửa gì thêm.
3. Trong code: `Image.asset('assets/images/onboarding_bg.png')`.

## Quy ước

- Ưu tiên định dạng nén (`.webp`, `.png` đã tối ưu); mỗi ảnh < 200KB.
- Không đặt ảnh có dữ liệu cá nhân hoặc bản quyền không rõ nguồn.
- Ảnh động dùng `assets/lottie/` hoặc `assets/svga/`, không dùng GIF trong thư mục này.
