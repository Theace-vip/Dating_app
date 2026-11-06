# `frontend/lib/app/` — điều hướng

**Vai trò:** quyết định người dùng đang ở màn hình nào dựa trên trạng thái đăng nhập.
**Ai gọi tới:** `main.dart` (`ref.watch(routerProvider)` để dựng `MaterialApp.router`); `main.dart` cũng dùng `rootNavigatorKey` để mở màn hình cuộc gọi đến.
**Gọi đi:** `data/repositories/auth_repository.dart` (`authProvider`) và 4 màn hình trong `features/auth`, `features/home`.

## File trong thư mục

| File | Nội dung |
|---|---|
| `router.dart` | `rootNavigatorKey` — key của navigator gốc, cho phép push màn hình từ ngoài router (cuộc gọi đến, luôn nằm trên cùng). `routerProvider` — tạo `GoRouter` với `redirect` và 4 route: `/splash`, `/login`, `/profile-setup`, `/`. |

## Luật redirect (đọc từ trên xuống, dừng ở điều kiện đầu tiên đúng)

| Điều kiện | Chuyển tới |
|---|---|
| `auth.isRestoring == true` | `/splash` (đang đọc token + gọi `/api/me`) |
| Đang ở `/splash` và đã khôi phục xong | `/` |
| Chưa đăng nhập và không ở `/login` | `/login` |
| Đã đăng nhập nhưng `profileCompleted == false` | `/profile-setup` |
| Đã đăng nhập, đủ hồ sơ mà còn ở `/login` hoặc `/profile-setup` | `/` |
| Còn lại | Đứng yên |

## Luồng hoạt động

```text
main.dart
  └── ref.watch(routerProvider)                     ← tạo GoRouter mỗi khi auth đổi
        └── redirect() đọc authProvider
              ├── /splash            features/auth/splash_page.dart  (watchdog 8 giây)
              ├── /login             features/auth/login_page.dart   → AuthNotifier.login()
              ├── /profile-setup     features/auth/profile_setup_page.dart → PATCH /api/me
              └── /                 features/home/home_page.dart    (5 tab)
```

- Đăng nhập thành công: `AuthNotifier` đổi state → `routerProvider` tạo lại → `redirect` trả `/` hoặc `/profile-setup`.
- Đăng xuất: state về `unauthenticated` → `redirect` đưa về `/login`; `main.dart` đồng thời ngắt socket và `ref.invalidate` các provider chat/feed/rooms/friends.
- Các màn hình phụ (chat chi tiết, phòng, gọi điện, hồ sơ người khác) **không** khai báo ở đây mà mở bằng `Navigator.push` từ màn hình gọi tới, vì chúng cần tham số và không ảnh hưởng redirect.

## Khi thêm route

1. Thêm `GoRoute` vào `routes` trong `router.dart` nếu màn hình cần deep link hoặc cần chặn theo trạng thái đăng nhập.
2. Nếu màn hình chỉ mở từ một nút bấm, dùng `Navigator.push` như hiện tại — không cần route.
3. Cập nhật bảng redirect nếu màn hình mới phải chặn người chưa đăng nhập.
