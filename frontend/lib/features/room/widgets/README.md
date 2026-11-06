# `frontend/lib/features/room/widgets/` — widget riêng của phòng tiệc

**Vai trò:** các widget chỉ dùng trong phòng tiệc, tách khỏi `room_detail_page.dart` để file chính dễ đọc.
**Ai gọi tới:** `features/room/room_detail_page.dart`.
**Gọi đi:** package `svgaplayer`, file animation trong `frontend/assets/svga/`; dữ liệu quà từ `catalog_repository.dart` (truyền vào qua tham số).

## File trong thư mục

| File | Nội dung |
|---|---|
| `svga_gift_view.dart` | `SvgaGiftView` (StatefulWidget) + `_SvgaGiftViewState`: nạp file `.svga` theo tên quà bằng `SVGAAnimationController`, phát một lần rồi báo `onCompleted` để phòng gỡ overlay; có xử lý lỗi (file thiếu/hỏng) để không treo UI. |

## Luồng hoạt động

```text
backend/src/socket.js: 'room:gift' {gift: 'rose', svga: 'rose.svga', from: {...}}
   └── room_detail_page.dart: nhận event → thêm _GiftAnimationData vào state
         └── SvgaGiftView(asset: 'assets/svga/rose.svga')
               ├── khởi tạo SVGAAnimationController + nạp asset
               ├── controller.play()  → hiệu ứng chạy trên màn hình phòng
               └── onCompleted → phòng xoá overlay, sẵn sàng cho quà tiếp theo
```

## Quy ước

1. Widget trong thư mục này **không** gọi API/socket trực tiếp — nhận dữ liệu qua constructor.
2. Tên asset phải khớp với `svga` trong `backend/src/catalog.js` và file thật trong `frontend/assets/svga/`.
3. Luôn `controller.stop()`/`dispose()` khi widget bị gỡ để giải phóng bộ giải mã.
4. Nếu animation lỗi, hiển thị banner chữ thay thế — không để màn hình trống.
