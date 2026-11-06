# 10 — Bảng sự kiện Socket.IO

Mọi sự kiện đi qua **một** kết nối duy nhất (`SocketService`), xác thực bằng
access token trong query. Danh sách dưới đây là toàn bộ sự kiện app đăng ký
(`data/api/socket_client.dart`).

## Kết nối
| Sự kiện | Chiều | Ghi chú |
|---|---|---|
| `connect` / `disconnect` / `connect_error` | client | chuẩn hoá thành stream để UI hiện trạng thái |

## Tin nhắn & hiện diện
| Sự kiện | Chiều | Nội dung |
|---|---|---|
| `chat:message` | server → client | `{conversationId, message, clientMessageId}` |
| `chat:message-edited` | server → client | tin sau khi sửa |
| `chat:message-deleted` | server → client | `{conversationId, messageId}` |
| `chat:typing` | hai chiều | `{conversationId}` / `{conversationId, from}` |
| `presence:changed` | server → client | `{userId, online}` |
| `conversations:changed` | server → client | có hội thoại mới với mình |

## Soul Game / Voice Game
`soul:queued`, `soul:matched`, `soul:message`, `soul:heart-available`,
`soul:like:sent`, `soul:like:received`, `soul:like:error`, `soul:mutual-like`,
`soul:revealed`, `soul:continued`, `soul:time-ended`, `soul:continue:error`,
`soul:partner-left`, `soul:rtc:signal`.

## Gọi điện
`call:invite`, `call:accepted`, `call:rejected`, `call:ended`, `call:error`,
`rtc:signal` (SDP/ICE cho cuộc gọi 1-1).

## Phòng tiệc
| Sự kiện | Chiều | Nội dung |
|---|---|---|
| `room:join` / `room:leave` | client → server | `{roomId}` |
| `room:presence` | server → client | danh sách thành viên |
| `room:message` | hai chiều | tin nhắn nhóm |
| `room:heart` | hai chiều | tim bay |
| `room:gift` | hai chiều | `{gift, giftName, svga, cost, from}` |
| `room:error` | server → client | ví dụ "Không đủ Xu" |
| `room:rtc:*` | hai chiều | `peers`, `joined`, `left`, `signal` (mic mesh) |
| `rooms:changed` | server → client | phòng mới / số người thay đổi |

## Feed
`feed:new`, `feed:updated`, `feed:deleted`, `feed:stats`,
`feed:comment:new`, `feed:comment:updated`, `feed:comment:deleted`.

## Tài khoản
| Sự kiện | Chiều | Nội dung |
|---|---|---|
| `user:wallet` | server → client | `{coins, diamonds}` |
| `user:updated` | server → client | hồ sơ sau khi sửa (mọi phiên của tài khoản) |
| `friends:changed` | server → client | hai bên vừa kết bạn |

## Cách dùng trong code
```dart
final sub = ref.read(socketProvider).on('friends:changed').listen((_) {
  ref.read(friendsProvider.notifier).load();
});
// ... trong dispose:
sub.cancel();
```
- Luôn `cancel()` trong `dispose` để không rò rỉ stream.
- Sự kiện không có trong danh sách đăng ký sẽ **không** được chuyển vào stream —
  thêm sự kiện mới thì phải thêm vào `events` trong `socket_client.dart`.
- Server kiểm tra quyền trước khi phát; client coi mọi payload là dữ liệu, không
  phải mệnh lệnh.
