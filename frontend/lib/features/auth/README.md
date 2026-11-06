# `frontend/lib/features/auth/` — đăng nhập và thiết lập hồ sơ

**Vai trò:** 3 màn hình đầu tiên của app: chờ khôi phục phiên, đăng nhập/đăng ký, thiết lập hồ sơ lần đầu.
**Ai gọi tới:** `app/router.dart` (route `/splash`, `/login`, `/profile-setup`).
**Gọi đi:** `data/repositories/auth_repository.dart` (`authProvider`), `data/api/api_client.dart` (gián tiếp), `data/repositories/catalog_repository.dart` (avatar/sở thích), `shared/image_tools.dart` (upload ảnh), `shared/server_host.dart` (đổi server).

## File trong thư mục

| File | Nội dung |
|---|---|
| `splash_page.dart` | Màn chờ khi `AuthNotifier.restore()` đang chạy; watchdog 8 giây đưa về `/login` nếu treo; hiển thị logo + loading. |
| `login_page.dart` | Form đăng nhập/đăng ký (cùng một trang, chuyển chế độ): validate email, mật khẩu ≥ 8 ký tự, tên 2–30; gọi `AuthNotifier.login()` / `register()`; hiện lỗi từ `ApiException`; dialog đổi địa chỉ server khi không kết nối được; nút OTP/Google ở trạng thái "sắp ra mắt". |
| `profile_setup_page.dart` | Thiết lập hồ sơ lần đầu: chọn avatar emoji hoặc upload ảnh, nhập tên/tuổi/giới tính/bio, chọn sở thích từ catalog; lưu bằng `AuthNotifier.completeProfile()` → `PATCH /api/me` với `profileCompleted = true`. |

## Luồng hoạt động

```text
main.dart: authProvider khởi tạo
   └── AuthNotifier.restore()                     data/repositories/auth_repository.dart
         ├── ApiClient.loadTokens()               (flutter_secure_storage)
         ├── không có token → AuthStatus.unauthenticated
         └── có token → GET /api/me
               ├── 200 → authenticated + UserModel
               └── lỗi → clearSession() → unauthenticated
                     └── app/router.dart: redirect → /splash hoặc /login

login_page.dart: _submit()
   └── AuthNotifier.login(email, password)
         └── ApiClient.login()  →  POST /api/auth/login
               ├── backend/src/auth.js: verifyPassword() + issueTokenPair()
               ├── ApiClient._saveTokens()
               └── AuthState(authenticated, user)
                     └── router: profileCompleted ? '/' : '/profile-setup'

profile_setup_page.dart: _save()
   └── AuthNotifier.completeProfile(...)
         └── ApiClient.updateMe()  →  PATCH /api/me
               └── backend/src/routes.js: validateProfileOptions() + UPDATE users
                     └── emitToUserSafe('user:updated')
                           └── AuthState.user  → router vào '/'
```

## Ghi chú

- Đăng nhập sai 5 lần: server khoá tài khoản 15 phút, trả `423` — UI hiện đúng thông báo từ `ApiException.message`.
- Đổi server: `shared/server_host.dart: showServerHostDialog()` lưu vào `SharedPreferences` và áp dụng ngay, không cần khởi động lại app.
- Trang này không tự lưu token — tất cả nằm trong `ApiClient` (secure storage).
