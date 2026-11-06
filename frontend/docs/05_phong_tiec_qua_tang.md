# 05 — Phòng tiệc & quà tặng

## Mục đích
Phòng chat nhóm nhiều người: vào/ra phòng, chat realtime, thả tim, tặng quà
(trừ Xu thật), bật mic (WebRTC mesh).

## File chính
| File | Vai trò |
|---|---|
| `features/room/room_list_page.dart` | danh sách phòng + realtime `rooms:changed` |
| `features/room/room_detail_page.dart` | UI phòng: chat, tim, quà, mic, thành viên |
| `features/room/widgets/svga_gift_view.dart` | phát animation SVGA (fallback Lottie) |
| `data/repositories/chat_repository.dart` | `RoomsNotifier`, `applyPresence` |
| `assets/svga/*.svga` | 7 animation quà (xem `assets/svga/NOTICE.md`) |

## Luồng vào phòng
```text
mở RoomDetailPage → socket.emit('room:join', {roomId})
   ├─ server join + phát room:presence (danh sách thành viên) và rooms:changed
   ├─ socket room:message → tin nhắn nhóm
   └─ rời màn hình → room:leave
```

`RoomsNotifier.applyPresence` cập nhật số người + avatar trong danh sách phòng;
`rooms:changed` giữ danh sách phòng (số thành viên, phòng mới) đồng bộ.

## Tặng quà
```text
chọn quà → socket.emit('room:gift', {roomId, gift})
   ├─ server đối chiếu ID + giá trong catalog (không tin giá client)
   ├─ trừ Xu trong transaction SQLite → fail: room:error
   └─ emit room:gift {gift, giftName, svga, cost, from}
        ├─ user:wallet → cập nhật số dư
        └─ mọi người thấy hiệu ứng toàn màn hình
```

### Hiệu ứng quà
- Overlay được vẽ **ngoài `Scaffold`** (Stack cấp route) nên phủ cả AppBar và
  thanh nhập tin; `FittedBox(scaleDown)` bảo đảm không bao giờ tràn khung.
- Tốc độ phát `0.7` (chậm hơn 30%). Quà **trên 100 Xu** phát 3 vòng; còn lại 1.
- Banner thông tin (người tặng + tên quà) tự tan sau khi animation chạy xong; có
  hẹn giờ dự phòng để không kẹt banner.
- File SVGA lỗi → hiển thị Lottie thay thế (`assets/lottie/gift_sparkle.json`).

## Realtime trong phòng
| Sự kiện | Ý nghĩa |
|---|---|
| `room:presence` | danh sách thành viên online |
| `room:message` | tin nhắn nhóm (lưu DB) |
| `room:gift` | quà + số dư mới |
| `room:heart` | tim bay |
| `room:rtc:*` | signaling mic mesh |
| `rooms:changed` | danh sách phòng thay đổi |

## Ghi chú
- Danh sách quà do server cung cấp (`/api/rooms/catalog`), app chỉ hiển thị.
- "Tên lửa" (`Rocket.svga`) không dùng được: file là SVGA 1.0 trong khi
  `svgaplayer` chỉ đọc 2.0.
- Tối đa 3 banner cùng lúc để nhiều người tặng liên tiếp không rối màn hình.
