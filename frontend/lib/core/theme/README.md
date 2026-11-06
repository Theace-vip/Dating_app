# `frontend/lib/core/theme/` — giao diện (màu, typography)

**Vai trò:** định nghĩa bảng màu và theme Material duy nhất cho toàn app, để mọi màn hình dùng cùng một ngôn ngữ thị giác.
**Ai gọi tới:** `main.dart` (`theme: AppTheme.light`) và hầu hết widget trong `features/`, `shared/widgets/` khi cần `AppColors.primary`, `AppColors.surface`…

## File trong thư mục

| File | Nội dung |
|---|---|
| `app_theme.dart` | `AppColors` — hằng số màu: `primary`, `primaryGradient`, `accent`, `background`, `surface`, `bubbleMine`, `bubbleOther`, `textPrimary`, `textSecondary`, `divider`, `success`, `warning`, `error`… `AppTheme.light` — `ThemeData` cho Material 3: màu chủ đạo, `AppBarTheme`, `InputDecorationTheme`, `ElevatedButtonTheme`, `CardTheme`… |

## Ai dùng cái gì

| Thành phần | Dùng ở đâu |
|---|---|
| `AppColors.primary` / `primaryGradient` | nút gửi, icon hành động, avatar ring, nút nạp Xu |
| `AppColors.surface` / `background` | nền `Scaffold`, `AppBar`, bottom sheet |
| `AppColors.bubbleMine` / `bubbleOther` | bong bóng chat (`chat_detail_page.dart: _buildBubble`) |
| `AppColors.error` / `warning` / `success` | SnackBar, trạng thái mất mạng, thông báo lỗi |

Khoảng cách và style chữ chi tiết nằm ở `core/constants/app_style.dart` (`AppSpacing`, `AppTextStyle`), không khai báo lại trong màn hình.

## Quy ước

1. Không viết mã màu `Color(0xFF...)` rải rác trong màn hình — thêm vào `AppColors` rồi dùng lại.
2. Muốn đổi nhận diện thương hiệu: sửa `AppColors` + `AppTheme.light`, không sửa từng trang.
3. Màu mang nghĩa nghiệp vụ (lỗi, cảnh báo, thành công) dùng đúng hằng số ngữ nghĩa để đổi theme sau này dễ.
