# `frontend/lib/features/room/` — phòng tiệc

**Vai trò:** tab "Phòng trò chuyện": danh sách phòng đang mở, tạo phòng, và phòng tiệc nhiều người (chat, thả tim, tặng quà, mic WebRTC).
**Ai gọi tới:** `features/home/home_page.dart` (tab 3); `room_list_page.dart` mở `RoomDetailPage`.
**Gọi đi:** `data/repositories/chat_repository.dart` (`roomsProvider`), `data/repositories/catalog_repository.dart` (danh mục quà + giá), `data/repositories/auth_repository.dart` (số dư), `data/api/socket_client.dart` (`room:*`), `features/call/rtc_session.dart` (mic), `features/room/widgets/svga_gift_view.dart`.

## File trong thư mục

| File | Nội dung chính |
|---|---|
| `room_list_page.dart` | `RoomListPage`: `roomsProvider.load()` → `GET /api/rooms`; `_showCreateRoom()` mở dialog nhập tên/chủ đề/emoji → `POST /api/rooms` → thêm phòng lên đầu; nghe `rooms:changed` để cập nhật số người; `_RoomCard` hiển thị phòng + avatar thành viên. |
| `room_detail_page.dart` | `RoomDetailPage`: tải lịch sử `GET /api/rooms/:id/messages` rồi `room:join`; gửi tin qua REST; nhận `room:message`, `room:presence`, `room:heart`, `room:gift`, `room:error`; thả tim (`_TikTokHeartWidget`), tặng quà (SVGA), bật/tắt mic mesh (`room:rtc:*`); rời trang → `room:leave` + dispose peer. |
| `widgets/svga_gift_view.dart` | `SvgaGiftView` — phát animation SVGA của quà trong phòng (đọc file `.svga` theo tên trong catalog). |

## Luồng vào phòng

```text
RoomListPage → chọn phòng → RoomDetailPage
   ├── _loadHistory()  → GET /api/rooms/:id/messages         backend/src/routes.js:720
   ├── socket.emit('room:join', {roomId})
   │     └── socket.js: join room 'room:<id>', roomMembers.add(userId)
   │           ├── 'room:presence' cho cả phòng
   │           └── io.emit('rooms:changed')  → danh sách phòng cập nhật số người
   └── đăng ký: room:message / room:presence / room:heart / room:gift / room:error / room:rtc:*
```

## Gửi tin, thả tim, tặng quà

| Thao tác | Client | Server |
|---|---|---|
| Gửi tin | `_send()` → `POST /api/rooms/:id/messages` | `routes.js:738` `INSERT room_messages` → phát `room:message` (giữ lịch sử cho người vào sau) |
| Thả tim | `socket.emit('room:heart')` | `socket.js` relay cho người khác (không lưu DB) |
| Tặng quà | `socket.emit('room:gift', {roomId, gift})` | `socket.js` → `catalog.js: chargeRoomGift()` (tra giá server, trừ Xu atomic) → `user:wallet` cho người gửi + `room:gift` cho phòng |

```text
room_detail_page.dart: chọn quà → emit('room:gift')
   └── backend/src/socket.js → backend/src/catalog.js: chargeRoomGift(db, userId, giftId)
         ├── không đủ Xu / quà sai → 'room:error'  → SnackBar
         └── thành công → 'user:wallet' → main.dart → AuthNotifier.applyWallet()
                        → 'room:gift'   → SvgaGiftView phát animation
```

## Mic trong phòng (mesh WebRTC)

```text
bật mic → emit('room:rtc:join', {roomId})
   └── socket.js: 'room:rtc:peers' (danh sách đang bật mic) + 'room:rtc:joined' cho người cũ
         ├── người vào sau nhận peers → tạo RtcSession cho từng peer
         ├── người đã ở trong phòng tạo offer khi có peer mới
         └── SDP/ICE qua 'room:rtc:signal' (server kiểm tra thành viên + đang bật mic)
tắt mic / rời phòng → 'room:rtc:leave' → 'room:rtc:left'
```

## Ghi chú

- Vào phòng phải tải lịch sử **trước** khi `room:join` để không lỡ tin đến giữa hai bước.
- Tin nhắn phòng lưu DB; tim và quà chỉ là sự kiện tức thời (quà có trừ Xu nên server ghi nhận giao dịch).
- Giá quà luôn lấy từ `/api/catalog`; client chỉ gửi `id`, server tự tra giá.
- Tài liệu chức năng: [`frontend/docs/05_phong_tiec_qua_tang.md`](../../../docs/05_phong_tiec_qua_tang.md).
