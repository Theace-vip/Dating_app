# `frontend/assets/svga/` — animation quà tặng

**Vai trò:** hiệu ứng động phát trong phòng tiệc khi có người tặng quà. Định dạng SVGA (vector + timeline, nhẹ hơn video).
**Ai dùng:** `frontend/lib/features/room/widgets/svga_gift_view.dart` (qua package `svgaplayer`), gián tiếp bởi `room_detail_page.dart`.
**Nguồn tên file:** `backend/src/catalog.js` — mỗi quà có trường `svga` trỏ tới file trong thư mục này.

## File trong thư mục

| File | Quà tương ứng (id trong catalog) |
|---|---|
| `rose.svga` | `rose` — Hoa hồng |
| `heartbeat.svga` | `heartbeat` — Nhịp tim |
| `kingset.svga` | `kingset` — Vương miện |
| `angel.svga` | `angel` — Thiên thần |
| `halloween.svga` | `halloween` — Bí ngô Halloween |
| `posche.svga` | `posche` — Xe Porsche |
| `TwitterHeart.svga` | Hiệu ứng tim kiểu Twitter (dùng cho thả tim/khung phòng) |
| `NOTICE.md` | Nguồn và giấy phép của các animation |

## Luồng phát

```text
socket.js: 'room:gift' { gift:'rose', svga:'rose.svga', from:{...} }
   └── room_detail_page.dart: thêm _GiftAnimationData vào state
         └── SvgaGiftView(asset: 'assets/svga/rose.svga')
               ├── SVGAAnimationController + nạp asset
               ├── play()        → hiệu ứng chạy
               └── onCompleted   → phòng gỡ overlay
```

## Thêm quà mới

1. Đặt file `.svga` vào đây, tên không dấu, không khoảng trắng.
2. Thêm mục vào `APP_CATALOG.rooms.gifts` trong `backend/src/catalog.js`: `{ id, name, svga: '<tên file>', cost }`.
3. Không cần sửa client: danh mục quà được tải từ `/api/catalog`.
4. Ghi nguồn/giấy phép vào `NOTICE.md` nếu dùng asset của bên thứ ba.
