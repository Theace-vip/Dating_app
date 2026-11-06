# `frontend/lib/features/profile/` — trang cá nhân và các trang con

**Vai trò:** tab "Trang cá nhân" cùng các màn hình phụ: chỉnh sửa hồ sơ, hồ sơ người khác, ví Xu, VIP, chẩn đoán mạng.
**Ai gọi tới:** `features/home/home_page.dart` (tab 5); các trang trong thư mục mở lẫn nhau; `features/chat/friends_page.dart` và `search_users_page.dart` mở `PublicProfilePage`.
**Gọi đi:** `data/repositories/auth_repository.dart` (`authProvider`, `currentUserProvider`), `chat_repository.dart` (`myPostsProvider`, `feedProvider`), `social_repository.dart` (`friendsProvider`), `catalog_repository.dart` (gói Xu, VIP, avatar), `shared/image_tools.dart`, `shared/server_host.dart`, `data/api/socket_client.dart`.

## File trong thư mục

| File | Nội dung chính |
|---|---|
| `profile_page.dart` | Trang cá nhân kiểu Facebook: ảnh bìa + avatar, thống kê **thật** (số bài từ `myPostsProvider`, số bạn từ `friendsProvider`, Xu/Kim cương từ `authProvider`), ngày tham gia thật (`createdAt`), lưới bạn bè thật, nhật ký bài viết của mình (like/comment/share thật), menu ⋯ (VIP, Ví & Xu, Đổi mật khẩu, Trạng thái mạng) và nút **Đăng xuất**. |
| `edit_profile_page.dart` | Sửa hồ sơ: avatar (emoji hoặc upload), tên, tuổi, giới tính, bio, sở thích từ catalog, ảnh; lưu qua `AuthNotifier.completeProfile()` → `PATCH /api/me`. |
| `public_profile_page.dart` | Hồ sơ người khác: `GET /api/users/:id` (kèm `isFriend`, `isOnline`), nút nhắn tin (`POST /api/conversations/ensure` → `ChatDetailPage`) và gọi thoại/video (`CallPage`). |
| `wallet_page.dart` | Ví Xu/Kim cương: số dư thật, danh sách gói Xu từ catalog; nút nạp bị khoá khi `purchasesEnabled == false`. |
| `vip_page.dart` | Quyền lợi và gói VIP lấy từ catalog; chưa bật mua. |
| `network_demo_page.dart` | Chẩn đoán mạng: log đổi kết nối, kiểm tra `/health`, đổi địa chỉ server (dialog `showServerHostDialog`). |

## Luồng hoạt động

### Mở trang cá nhân

```text
profile_page.dart: initState()
   ├── myPostsProvider.notifier.load(me.id)   → GET /api/feed?userId=<id>   (chat_repository.dart)
   └── friendsProvider.notifier.load()        → GET /api/friends            (social_repository.dart)
build()
   ├── ref.watch(currentUserProvider)         → tên, avatar, bio, Xu, createdAt
   ├── ref.watch(myPostsProvider)             → thống kê "Bài viết" + danh sách bài
   └── ref.watch(friendsProvider)             → thống kê "Bạn bè" + lưới avatar
```

### Đăng xuất

```text
profile_page.dart → AuthNotifier.logout()          data/repositories/auth_repository.dart
   ├── ApiClient.logoutOnServer()                  → POST /api/auth/logout (revoke refresh token)
   ├── ApiClient.clearSession()                    → xoá token trong secure storage
   └── AuthStatus.unauthenticated
         ├── app/router.dart: redirect → /login
         └── main.dart: socket.disconnect() + invalidate(chat/feed/rooms/friends)
```

### Đổi mật khẩu

`profile_page.dart` dialog → `AuthNotifier.changePassword(current, new)` → `POST /api/me/password`
→ server revoke toàn bộ refresh token cũ, trả cặp token mới → client lưu lại; thiết bị khác phải đăng nhập lại.

### Ví và quà

Số dư hiển thị từ `currentUserProvider`; mỗi lần tặng quà server phát `user:wallet`
→ `main.dart` → `AuthNotifier.applyWallet(coins, diamonds)` → trang Ví tự cập nhật (không cần mở lại).

## Ghi chú

- Không có số liệu giả: chưa có bài/bạn thì hiện `EmptyState`, không hiện số mẫu.
- Bài của mình tải riêng theo `userId` để không phụ thuộc phần đã cuộn trong bảng tin chung.
- Tài liệu chức năng: [`frontend/docs/02_ho_so_ca_nhan.md`](../../../docs/02_ho_so_ca_nhan.md), [`09_catalog_vi_vip.md`](../../../docs/09_catalog_vi_vip.md).
