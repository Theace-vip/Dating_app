# 07 — Gọi thoại / video (WebRTC)

## Mục đích
Gọi 1-1 từ màn chat hoặc hồ sơ công khai; có màn hình cuộc gọi đến, bật/tắt mic,
loa, camera, timeout chuông 45 giây.

## File chính
| File | Vai trò |
|---|---|
| `features/call/call_page.dart` | UI cuộc gọi (incoming/outgoing, timer, điều khiển) |
| `features/call/rtc_session.dart` | bọc `RTCPeerConnection`, luồng audio/video |
| `main.dart` | lắng nghe `call:invite` để mở màn hình nhận cuộc gọi |
| `core/constants/app_config.dart` | danh sách ICE servers (STUN) |

## Luồng
```text
A: call:invite {to, callId, isVideo}
   ├─ B nhận call:invite → CallPage(incoming: true)
   ├─ B: call:accept → A nhận call:accepted → hai bên trao đổi rtc:signal (SDP/ICE)
   ├─ B: call:reject → A nhận call:rejected (kết thúc)
   └─ một bên: call:hangup → cả hai nhận call:ended, đóng peer
```

- `callId` do bên gọi sinh; server chỉ chuyển tiếp cho đúng người nhận.
- Nếu đang có cuộc gọi khác (`gInCall`), `main.dart` tự `call:reject` — tránh
  hai phiên media cùng lúc.
- Server tự hết hạn chuông sau 45 giây và phát `call:ended`.

## Âm thanh
- Mic mặc định bật sau khi kết nối; loa ngoài (`setSpeaker`) áp dụng cho mọi
  peer đang mở trong phòng.
- Voice Game dùng chung `RtcSession` qua `soul:rtc:signal`.

## Ghi chú
- Chưa có TURN server: hai máy sau NAT đối xứng có thể không kết nối được (đã ghi
  trong README gốc). Thêm coturn và bổ sung `iceServers` là đủ.
- WebRTC chạy trên thiết bị; server không thấy nội dung cuộc gọi.
