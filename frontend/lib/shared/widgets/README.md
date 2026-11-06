# `frontend/lib/shared/widgets/` — bộ widget giao diện dùng chung

**Vai trò:** các widget nhỏ, lặp lại ở nhiều màn hình, được chuẩn hoá một lần để giao diện đồng nhất.
**Ai gọi tới:** `features/*` (chat, feed, profile, room, auth…).
**Gọi đi:** `core/theme/app_theme.dart` (`AppColors`, `AppTheme`), `core/constants/app_style.dart`, `shared/image_tools.dart` (`isNetworkAvatar`), `cached_network_image`.

## File trong thư mục

| File | Nội dung |
|---|---|
| `app_widgets.dart` | `AppAvatar` — avatar tròn, tự nhận emoji hoặc URL ảnh (`isNetworkAvatar`), có chấm online và viền gradient. `AppButton` — nút chính/phụ, trạng thái loading và disabled. `AppTextField` — ô nhập có label, icon, ẩn/hiện mật khẩu. `AppChip` — chip chọn sở thích. `LoadingWidget` — spinner căn giữa. `EmptyState` — trạng thái rỗng (emoji + thông điệp), dùng khi chưa có dữ liệu thật. |

## Ai dùng widget nào

| Widget | Dùng ở |
|---|---|
| `AppAvatar` | `chat_list_page`, `chat_detail_page`, `feed_page`, `room_detail_page`, `profile_page`, `friends_page`, `soul_game_page` |
| `AppButton` | `login_page`, `profile_setup_page`, `edit_profile_page`, `wallet_page`, `vip_page` |
| `AppTextField` | các form đăng nhập/hồ sơ/tìm kiếm |
| `AppChip` | `profile_setup_page`, `edit_profile_page` (chọn sở thích) |
| `EmptyState` | mọi danh sách khi chưa có dữ liệu (chat, feed, phòng, bạn bè, bài của tôi) |
| `LoadingWidget` | màn hình chờ tải lần đầu |

## Quy ước

1. Widget ở đây **không** gọi API/socket và không giữ state nghiệp vụ.
2. Màu lấy từ `AppColors`, khoảng cách từ `AppSpacing`; không hard-code.
3. Tham số có tên rõ nghĩa, mặc định hợp lý (ví dụ `AppAvatar(size: 48)`).
4. Thêm widget mới chỉ khi đã dùng ở **từ hai màn hình trở lên**; widget riêng của một màn hình để trong `features/<nghiệp vụ>/`.
