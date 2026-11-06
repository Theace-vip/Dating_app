# `frontend/lib/features/matching/` — Soul Game & Voice Game

**Vai trò:** ghép đôi ẩn danh với người lạ. Bản text (Soul Game) và bản thoại (Voice Game). Không lộ tên/avatar cho tới khi hai bên đồng ý.
**Ai gọi tới:** `features/home/home_page.dart: ExplorePage` (hai thẻ game).
**Gọi đi:** `data/api/socket_client.dart` (`soul:*`), `data/repositories/catalog_repository.dart` (thời lượng, thời điểm mở nút tim), `features/call/rtc_session.dart` (Voice Game), `features/chat/chat_detail_page.dart` (sau khi reveal).

## File trong thư mục

| File | Nội dung chính |
|---|---|
| `soul_game_page.dart` | `SoulGamePage` + `_SoulStatus { searching, matched, ended }`: vào hàng đợi `soul:queue`, nhận `soul:matched`, chat ẩn danh (`soul:message`), đếm giờ theo `endsAt` do server cấp, nút tim mở khi `soul:heart-available`, thả tim (`soul:like`), hiện danh tính (`soul:reveal`), gia hạn (`soul:continue`), rời (`soul:leave`); `_ChatBubble` hiển thị tin. |
| `voice_game_page.dart` | `VoiceGamePage` + `_VoiceStatus`: cùng giao thức nhưng `mode: 'voice'`; khi `soul:matched` tạo `RtcSession` (bên `initiator` gửi offer), SDP/ICE qua `soul:rtc:signal`; nút tắt/bật mic, loa; `_CircleButton` cho các nút tròn. |

## Luồng hoạt động

```text
ExplorePage → SoulGamePage
   └── initState: đọc catalog (textSeconds, heartUnlockAfterSeconds), kiểm tra socket
         └── socket.emit('soul:queue', {mode:'text'})
               ▼
        backend/src/socket.js: handler 'soul:queue'
           ├── chưa có ai → queue.push(...) → 'soul:queued'      (UI: đang tìm)
           └── có người  → tạo sessionId + room 'soul:<id>'
                 ├── catalog.js: matching.textSeconds  → hẹn giờ hết phiên
                 ├── catalog.js: heartUnlockAfterSeconds → hẹn mở nút tim
                 └── 'soul:matched' cho cả hai (một bên initiator: true)
                       ▼
        soul_game_page.dart: _SoulStatus.matched
           ├── gửi: socket.emit('soul:message')  → server relay cho đối phương
           ├── nhận: socket.on('soul:message')   → thêm bong bóng
           ├── server đếm tin: đủ 5 tin → 'soul:heart-available'
           └── hết giờ (server): 'soul:time-ended' → sheet gia hạn / tìm người mới
```

### Thả tim và reveal

```text
bấm tim → socket.emit('soul:like')
   └── socket.js: kiểm tra heartAvailable + thành viên → session.likes.add(userId)
         ├── 'soul:like:sent' (mình) / 'soul:like:received' (đối phương)
         └── đủ 2 lượt → ensureConversation() + addFriendship() (backend/src/db.js)
               ├── emitToUser('friends:changed') cho cả hai
               └── 'soul:mutual-like' {conversationId, user thật}
                     └── soul_game_page.dart → mở ChatDetailPage

bấm "Hiện danh tính" → socket.emit('soul:reveal')
   └── socket.js: tạo hội thoại + bạn bè → 'soul:revealed' {conversationId, user}
```

## Voice Game (WebRTC)

```text
voice_game_page.dart → soul:queue {mode:'voice'}
   └── soul:matched {initiator}
         ├── initiator: RtcSession.createOffer()  → soul:rtc:signal
         └── bên kia:  RtcSession.acceptOffer()   → soul:rtc:signal
               └── socket.js chỉ relay giữa đúng 2 socket của phiên
                     └── RtcSession.onRemoteStream → phát audio
```

## Ghi chú

- Server giữ đồng hồ (`endsAt`) và quyền mở nút tim; client chỉ hiển thị — không thể tự rút ngắn/gia hạn.
- `soul:continue` chỉ hợp lệ sau khi phiên hết giờ thật; `soul:finish` gửi sớm bị bỏ qua.
- Rời trang phải `emit('soul:leave')` và dispose `RtcSession` để đối phương không chờ vô hạn.
- Tài liệu chức năng: [`frontend/docs/04_soul_game.md`](../../../docs/04_soul_game.md).
