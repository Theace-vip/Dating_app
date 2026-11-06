# 04 — Soul Game & Voice Game (ghép đôi ẩn danh)

## Mục đích
Ghép hai người lạ vào một phiên trò chuyện **ẩn danh**; sau khi đủ điều kiện mới
mở nút tim, hai bên cùng thích thì lộ danh tính, kết bạn và mở chat 1-1.

## File chính
| File | Vai trò |
|---|---|
| `features/matching/soul_game_page.dart` | hàng đợi text, chat ẩn danh, nút tim, gia hạn |
| `features/matching/voice_game_page.dart` | hàng đợi voice + gọi thoại trong phiên |
| `data/api/socket_client.dart` | các sự kiện `soul:*`, `rtc:signal` |
| `features/call/rtc_session.dart` | dựng `RTCPeerConnection` dùng chung |

## Luồng text
```text
soul:queue {mode:'text'}  → ghép cặp → soul:matched {sessionId, endsAt, partner}
   ├─ chat ẩn danh: soul:message (server chuyển tiếp, không lưu DB)
   ├─ sau 5 tin HOẶC 10 giây → soul:heart-available (hiện nút tim)
   ├─ soul:like  → đủ 2 lượt → soul:mutual-like {conversationId, user}
   ├─ hết giờ    → soul:time-ended → có thể soul:continue (gia hạn)
   └─ rời phòng  → soul:partner-left
```

## Luồng voice
`mode: 'voice'` → phiên 90 giây (server quyết định), hai bên dùng WebRTC qua
`soul:rtc:signal`. Không lưu nội dung.

## Quy tắc do server quyết định
- Thời lượng phiên, mốc mở nút tim, số tin tối thiểu: `catalog.matching`.
- Danh tính bị ẩn (`profileForStranger`: chỉ avatar/tuổi/giới tính) cho tới khi
  `soul:revealed` / `soul:mutual-like`.
- Không ai có thể tự đổi trạng thái phiên từ client; mọi `soul:*` đều kiểm tra
  socket có thuộc phiên (`session.a.socketId` / `session.b.socketId`).

## Kết quả
Hai bên thích nhau (hoặc nhấn "Tiếp tục" khi hết giờ):
1. Server `ensureConversation(a, b)`.
2. Server `addFriendship(a, b)` và phát `friends:changed` cho cả hai.
3. App nhận `soul:mutual-like`/`soul:revealed` → mở `ChatDetailPage` với
   `conversationId` vừa tạo.

Nhờ `friends:changed`, trang cá nhân và trang Bạn bè cập nhật ngay, không cần
tải lại tay.

## Ghi chú
- Nút tim chỉ hiện khi `heartAvailable = true`; bấm sớm → `soul:like:error`.
- Rời app giữa phiên → `disconnect` dọn hàng đợi và phát `soul:partner-left`.
- Voice Game cần micro (`flutter_webrtc`); nếu thiếu quyền, app báo lỗi thay vì
  treo.
