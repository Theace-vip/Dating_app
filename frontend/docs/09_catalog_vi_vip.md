# 09 — Catalog, ví Xu & VIP

## Mục đích
Mọi danh mục và bảng giá (avatar, sở thích, quà phòng, gói Xu, VIP, thời lượng
phiên ghép đôi) được định nghĩa **một lần ở backend** và tải qua API. App không
hard-code nghiệp vụ.

## File chính
| File | Vai trò |
|---|---|
| `data/repositories/catalog_repository.dart` | `catalogRepositoryProvider`, model `RoomGiftOption`… |
| `features/profile/wallet_page.dart` | số dư Xu / Kim cương, danh sách gói |
| `features/profile/vip_page.dart` | quyền lợi VIP |
| `data/models/models.dart` | `UserModel.coins`, `diamonds`, `isVip` |

## Endpoint
| API | Nội dung |
|---|---|
| `GET /api/catalog` | toàn bộ catalog |
| `GET /api/profile/options` | avatar + sở thích hợp lệ |
| `GET /api/rooms/catalog` | 7 quà phòng (id, tên, file SVGA, giá) |
| `GET /api/wallet/catalog` | gói Xu, bảng giá |
| `GET /api/vip/catalog` | gói VIP + quyền lợi |

Catalog trả `Cache-Control: public, max-age=300` vì là dữ liệu công khai.

## Ví realtime
Server là nguồn số dư duy nhất. Sau khi tặng quà, server phát
`user:wallet {coins, diamonds}` → `main.dart` → `AuthNotifier.applyWallet()` →
mọi màn hình hiển thị số dư mới ngay (trang cá nhân, ví, khung chọn quà).

## Trạng thái hiện tại
- **Nạp Xu / mua VIP** chưa bật: catalog có bảng giá nhưng
  `coinPurchasesEnabled = false`; nút mua hiển thị "sắp ra mắt". Cần cổng thanh
  toán + xác minh giao dịch phía server trước khi bật.
- Xu chỉ bị trừ ở server (transaction SQLite); client không bao giờ gửi giá.

## Ghi chú
- Sửa giá/quà: chỉ cần sửa `backend/src/catalog.js`, app tự cập nhật.
- File SVGA đặt trong `frontend/assets/svga/`, khai báo trong `pubspec.yaml`.
