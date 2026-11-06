# 02 — Trang cá nhân, chỉnh sửa hồ sơ & bạn bè

## Mục đích
Trang "Cá nhân" là nơi người dùng thấy **toàn bộ dữ liệu thật của chính mình**:
hồ sơ, thống kê, bạn bè, bài viết, ví và các lối tắt (chỉnh sửa, VIP, mạng,
đăng xuất). Không có số liệu hay danh sách mẫu.

## File chính
| File | Vai trò |
|---|---|
| `features/profile/profile_page.dart` | trang cá nhân (cover, avatar, thống kê, chi tiết, bạn bè, bài viết, đăng xuất) |
| `features/profile/edit_profile_page.dart` | sửa tên, tuổi, giới tính, bio, sở thích, ảnh, avatar |
| `features/profile/public_profile_page.dart` | hồ sơ người khác + nút nhắn tin/gọi |
| `features/chat/friends_page.dart` | danh sách bạn bè (realtime) |
| `features/chat/search_users_page.dart` | tìm người theo tên/email |
| `data/repositories/social_repository.dart` | `friendsProvider`, `FriendEntry`, realtime |
| `features/profile/wallet_page.dart`, `vip_page.dart` | ví Xu, gói VIP |
| `features/profile/network_demo_page.dart` | chẩn đoán mạng, đổi máy chủ |

## Thành phần trang cá nhân
| Khối | Dữ liệu | Nguồn |
|---|---|---|
| Cover + avatar | gradient + `user.avatar` | `authProvider` |
| Tên, tích xanh VIP, bio | `UserModel` | `/api/me` |
| Thống kê: Bài viết / Bạn bè / Xu / Kim cương | đếm thật | `feedProvider`, `friendsProvider`, `user` |
| Chi tiết | email, SĐT, tuổi, giới tính, trạng thái hồ sơ, **ngày tham gia** | `user.createdAt` (server) |
| Sở thích | `user.tags` | `/api/me` |
| Bạn bè (tối đa 6) | `friendsProvider` — bấm để mở chat | `/api/friends` |
| Bài viết của bạn | `myPostsProvider` (tải riêng theo tác giả) | `/api/feed?userId=<mình>` |
| Nút Thích / Bình luận / Chia sẻ | hoạt động thật | `feedProvider.toggleLike`, `CommentsSheet`, `share_plus` |
| Đăng xuất | hộp thoại xác nhận | `authProvider.logout()` |

## Bạn bè realtime
`socialRealtimeProvider` (watch một lần ở `HomePage`):

```dart
friends.load();                                  // nạp lần đầu từ DB
socket.on('friends:changed').listen(...)         // hai bên vừa kết bạn
socket.on('conversations:changed').listen(...)   // có hội thoại mới
```

`GET /api/friends` trả mỗi bạn kèm `isOnline`, `friendsSince` và
`conversationId` (server tạo nếu chưa có), nhờ vậy bấm vào bạn là mở chat ngay.

## Chỉnh sửa hồ sơ
`PATCH /api/me` → server validate (tên 2–30 ký tự, tuổi 16–80, tối đa 20 sở
thích, 9 ảnh, avatar phải là `/uploads/...` hoặc emoji ngắn) → trả `user` mới.
Server cũng phát `user:updated` cho chính tài khoản đó để các phiên khác đồng bộ.

## Ghi chú
- Ảnh đại diện/diện mạo: emoji hoặc URL do `/api/upload` trả về.
- Ngày tham gia lấy từ `users.created_at` trong database, không phải chuỗi cứng.
- Trang cá nhân **không** hiển thị người lạ: chỉ bạn bè thật trong bảng
  `friendships`.
