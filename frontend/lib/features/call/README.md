# `frontend/lib/features/call/` — gọi thoại / video

**Vai trò:** giao diện và phiên WebRTC cho cuộc gọi 1-1 (gọi đi và nhận), dùng chung cho bạn bè lẫn người lạ.
**Ai gọi tới:** `main.dart` (khi có `call:invite`), `features/chat/chat_detail_page.dart` (nút gọi), `features/profile/public_profile_page.dart`.
**Gọi đi:** `data/api/socket_client.dart` (`call:*`, `rtc:signal`), `data/repositories/catalog_repository.dart` (thời gian đổ chuông), `core/network/connectivity_service.dart`, package `flutter_webrtc` (qua `rtc_session.dart`).

## File trong thư mục

| File | Nội dung chính |
|---|---|
| `call_page.dart` | `CallPage` + `_CallPhase { outgoing, incoming, connecting, connected, ended }`: `_invite()` chờ socket kết nối rồi `emit('call:invite')`; nhận `call:accepted/rejected/ended/error`; tạo `RtcSession` sau khi kết nối; timer chuông dự phòng; nút tắt/bật mic, camera, loa; `gInCall` (biến toàn cục) chặn hai cuộc gọi cùng lúc. |
| `rtc_session.dart` | `RtcSession` + `RtcState { connecting, connected, failed, closed }`: xin quyền media, tạo `RTCPeerConnection` với ICE servers (`AppConfig.iceServers`), tạo/nhận offer-answer, xử lý ICE theo thứ tự (ICE đến sớm được xếp hàng), phát `onState`/`onRemoteStream`, `close()` dọn tài nguyên. |

## Luồng gọi đi

```text
chat_detail_page.dart / public_profile_page.dart → CallPage(peerId, callId, isVideo)
   └── call_page.dart: _invite()
         ├── ensureOnline() + chờ socket connected (tối đa 8 giây)
         └── socket.emit('call:invite', {to, callId, isVideo})
               ▼
        backend/src/socket.js: handler 'call:invite'
           ├── kiểm tra: user tồn tại, không tự gọi mình, không bận, đối phương online
           ├── activeCalls.set(callId, {status:'ringing', timeout: ...})
           │     └── hết catalog.call.ringingTimeoutSeconds → 'call:ended' reason timeout
           └── 'call:invite' tới mọi socket của người nhận
```

## Luồng nhận cuộc gọi

```text
backend/src/socket.js: 'call:invite'
   └── main.dart: listener call:invite
         ├── đang gInCall → emit('call:reject') ngay
         └── push CallPage(incoming: true) lên rootNavigatorKey
               ├── bấm nghe   → emit('call:accept', {to, callId})
               │     └── socket.js: status 'accepted', huỷ timer → 'call:accepted' cho caller
               └── bấm từ chối → emit('call:reject') → 'call:rejected' cho caller
```

## Trao đổi media

```text
sau accept → hai bên tạo RtcSession
   ├── caller (initiator): createOffer()  → emit('rtc:signal', {to, callId, data})
   └── callee:             setRemoteDescription → createAnswer → emit('rtc:signal')
         └── socket.js: chỉ relay khi call.status === 'accepted' và đúng cặp caller/callee
               └── RtcSession: thêm ICE, khi connected → _CallPhase.connected
```

Kết thúc: `call:hangup` (bấm đỏ) hoặc socket `disconnecting` → server xoá `activeCalls` → `call:ended` cho đầu kia.

## Ghi chú

- Media (âm thanh/hình) đi **trực tiếp** giữa hai thiết bị; server chỉ chuyển tiếp SDP/ICE.
- STUN công khai đủ cho demo cùng mạng; muốn gọi qua NAT chặt cần thêm TURN (cấu hình ở `core/constants/app_config.dart: iceServers`).
- Server giữ trạng thái cuộc gọi để chặn gọi chồng, gọi người offline và giả mạo `callId`.
- Tài liệu chức năng: [`frontend/docs/07_goi_dien.md`](../../../docs/07_goi_dien.md).
