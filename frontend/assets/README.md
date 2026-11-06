# `frontend/assets/` — tài nguyên tĩnh của app

**Vai trò:** ảnh, icon, animation đóng gói vào APK/exe. Khai báo trong `pubspec.yaml` (`flutter: assets:`) để Flutter nạp được.
**Ai dùng:** `features/room/widgets/svga_gift_view.dart` (SVGA), `features/room/room_detail_page.dart` (Lottie/SVGA), các màn hình dùng ảnh/icon.

## Thư mục con

| Thư mục | Nội dung | Trạng thái |
|---|---|---|
| `images/` | Ảnh tĩnh (nền, banner) | Chỉ có `.gitkeep` — chưa dùng |
| `icons/` | Icon tuỳ chỉnh ngoài bộ Material | Chỉ có `.gitkeep` — chưa dùng |
| `animations/` | Animation dạng file thô | Chỉ có `.gitkeep` — chưa dùng |
| `lottie/` | Animation Lottie (`.json`) | `gift_sparkle.json` — hiệu ứng lấp lánh khi tặng quà |
| `svga/` | Animation SVGA (`.svga`) cho quà trong phòng | 7 file, khớp tên quà trong `backend/src/catalog.js` |

Mỗi thư mục con có `README.md` ghi rõ file nào dùng ở đâu.

## Luồng: quà trong phòng

```text
backend/src/catalog.js: APP_CATALOG.rooms.gifts
   { id:'rose', name:'Hoa hồng', svga:'rose.svga', cost:50 }      ← giá do server quyết định
        │  GET /api/catalog → catalog_repository.dart: AppCatalog.roomGifts
        ▼
room_detail_page.dart: chọn quà → emit('room:gift', {gift:'rose'})
        │
        ▼
socket.js: 'room:gift' {gift:'rose', svga:'rose.svga'}  (sau khi trừ Xu)
        ▼
SvgaGiftView(asset: 'assets/svga/rose.svga') → svgaplayer phát animation
```

## Quy ước

1. **Tên file phải khớp `svga` trong catalog** — server gửi tên, client ghép `assets/svga/<tên>`.
2. Thêm asset mới: đặt file vào đúng thư mục; nếu là thư mục mới thì khai báo thêm trong `pubspec.yaml`.
3. Giữ file nhẹ (SVGA nên < 500KB) vì toàn bộ asset nằm trong APK.
4. `NOTICE.md` trong `assets/svga/` ghi nguồn/giấy phép của các animation — giữ lại khi thay file.
