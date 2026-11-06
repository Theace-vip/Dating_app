# 01 — Xác thực, phiên đăng nhập & đăng xuất

## Mục đích
Đăng ký, đăng nhập, khôi phục phiên khi mở app, đổi mật khẩu và đăng xuất an toàn.

## File chính
| File | Vai trò |
|---|---|
| `features/auth/splash_page.dart` | màn chờ trong lúc khôi phục phiên |
| `features/auth/login_page.dart` | đăng nhập / đăng ký email + mật khẩu |
| `features/auth/profile_setup_page.dart` | thiết lập hồ sơ lần đầu (tên, tuổi, giới tính, avatar, sở thích) |
| `data/repositories/auth_repository.dart` | `AuthNotifier` + `AuthState`, `currentUserProvider` |
| `data/api/api_client.dart` | lưu token, refresh 401, `logoutOnServer()` |
| `app/router.dart` | redirect theo trạng thái đăng nhập |

## Luồng
```text
mở app
  └─ AuthNotifier() → restore()
        ├─ loadTokens() (secure storage)
        ├─ không có token → unauthenticated → /login
        └─ có token → GET /api/me
              ├─ 200 → authenticated (+ profileCompleted?)
              └─ lỗi → clearSession() → /login
```

### Đăng nhập / đăng ký
`POST /api/auth/login` (hoặc `/register`) trả `accessToken`, `refreshToken`,
`user`. Token lưu bằng `flutter_secure_storage`; access token 15 phút, refresh
token 30 ngày và **xoay vòng** mỗi lần refresh.

### Tự refresh
`ApiClient` chặn lỗi 401: gọi `POST /api/auth/refresh` **một lần duy nhất**
(single-flight) rồi gửi lại request gốc. Refresh thất bại → xoá token →
`authProvider.sessionExpired()` → router đưa về `/login`.

### Đổi mật khẩu
`POST /api/me/password`: server kiểm tra mật khẩu cũ, thu hồi **mọi** refresh
token cũ và trả cặp token mới (app lưu ngay) — các thiết bị khác bị đăng xuất.

### Đăng xuất
Có hai chỗ vào (menu ⋯ và nút cuối trang cá nhân) → hộp thoại xác nhận →
`authProvider.logout()`:

1. `POST /api/auth/logout` để server thu hồi refresh token (lỗi mạng vẫn bỏ qua).
2. `clearSession()` xoá token khỏi bộ nhớ + secure storage.
3. `state = unauthenticated`.
4. Router redirect về `/login`; `main.dart` ngắt socket và invalidate các
   provider dữ liệu (`chat`, `feed`, `rooms`, `friends`).

## Realtime liên quan
| Sự kiện | Xử lý |
|---|---|
| `user:updated` | `main.dart` → `AuthNotifier.applyUser()` (sửa hồ sơ ở máy khác) |
| `user:wallet` | `AuthNotifier.applyWallet()` cập nhật Xu/Kim cương |

## Ghi chú
- Token **không** lưu trong SharedPreferences hay bộ nhớ thường.
- `AuthState.copyWith` không cho phép xoá `user` về `null` — khi đăng xuất dùng
  state mới thay vì `copyWith`.
- Sai mật khẩu 5 lần → server khoá tạm (`423`), app hiện thông báo tương ứng.
