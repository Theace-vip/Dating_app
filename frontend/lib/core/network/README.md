# `frontend/lib/core/network/` — mạng, offline và bảo mật kết nối

**Vai trò:** phát hiện mất mạng, chặn thao tác khi offline, giữ tin nhắn để gửi bù, và ghim chứng chỉ TLS của backend.
**Ai gọi tới:** `main.dart` (init outbox, listener connectivity), mọi màn hình có thao tác ghi (`ensureOnline`), `data/api/api_client.dart` + `socket_client.dart` (được pinning bảo vệ).
**Gọi đi:** `data/api/api_client.dart` (outbox gửi lại tin), `core/constants/app_config.dart` (pin, host).

## File trong thư mục

| File | Nội dung chính |
|---|---|
| `connectivity_service.dart` | `connectivityProvider` (StreamProvider từ `connectivity_plus`), `isOnlineProvider` (bool), `connectionTypeLabelProvider` (nhãn WiFi/4G), `ensureOnline(context, ref)` — kiểm tra mạng thật từ OS, offline thì hiện SnackBar và trả `false`, `NetworkBanner` — dải cảnh báo mất mạng đặt trên cùng app. |
| `outbox.dart` | `outboxProvider` + `Outbox`: `init()` đọc hàng đợi từ `SharedPreferences`, `enqueue(conversationId, content)` lưu tin chưa gửi, `flush()` gửi lần lượt qua `POST /api/conversations/:id/messages` rồi xoá khỏi hàng đợi. Chỉ áp dụng cho chat 1-1. |
| `pinning.dart` | `PinningHttpOverrides` — `badCertificateCallback` so SHA-256 của cert với `AppConfig.certPinningSha256`; chỉ bỏ qua khi host đúng là tunnel người dùng đã nhập. `installCertificatePinning()` gán `HttpOverrides.global` (áp dụng cho cả Dio và WebSocket). `fingerprintOfPem()` tính pin khi đổi cert. |

## Luồng: gửi tin khi mất mạng

```text
features/chat/chat_detail_page.dart: _send()
   ├── ensureOnline()  → offline: báo + dừng
   ├── chat_repository.dart: MessagesNotifier.send()   → thất bại, trả false
   └── outboxProvider.enqueue(conversationId, text)     → SharedPreferences

mạng trở lại
   └── main.dart: ref.listen(connectivityProvider)
         ├── socketProvider.connect()
         └── outboxProvider.flush()
               └── api.post('/api/conversations/:id/messages', clientMessageId: 'outbox_...')
                     └── backend/src/routes.js → INSERT messages → chat:message
```

## Luồng: bảo vệ kết nối

```text
main.dart: main()
   └── installCertificatePinning()
         └── HttpOverrides.global = PinningHttpOverrides()

Dio/Socket mở TLS tới backend (cert tự ký)
   └── badCertificateCallback: sha256(cert) == AppConfig.certPinningSha256 ?
         ├── đúng      → cho phép
         ├── host tunnel → cho phép (cert của Cloudflare/ngrok)
         └── khác      → từ chối (chống nghe lén trong WiFi công cộng)
```

## Ghi chú

- `ensureOnline()` kiểm tra trực tiếp hệ điều hành, không chỉ đọc state provider — tránh trường hợp UI tưởng còn mạng.
- Outbox chỉ giữ nội dung text; tin ảnh gửi lỗi thì báo ngay, không xếp hàng.
- Đổi cert backend phải cập nhật `AppConfig.certPinningSha256`.
