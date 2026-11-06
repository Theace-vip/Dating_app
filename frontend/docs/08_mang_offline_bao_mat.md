# 08 — Mạng, offline & bảo mật kết nối

## Mục đích
Theo dõi trạng thái mạng, chặn thao tác khi offline, gửi bù tin nhắn, đổi địa chỉ
máy chủ và chống nghe lén (certificate pinning).

## File chính
| File | Vai trò |
|---|---|
| `core/network/connectivity_service.dart` | `connectivityProvider`, `isOnlineProvider`, `ensureOnline()`, nhãn loại mạng |
| `core/network/outbox.dart` | hàng đợi tin nhắn, lưu bằng Hive, `flush()` |
| `core/network/pinning.dart` | gắn kiểm tra SHA-256 certificate |
| `shared/server_host.dart` | lưu/đổi địa chỉ máy chủ |
| `features/profile/network_demo_page.dart` | UI chẩn đoán + đổi máy chủ |
| `core/constants/app_config.dart` | `apiBaseUrl`, `socketUrl`, pin, ICE servers |

## Trạng thái mạng
- `connectivity_plus` phát thay đổi → `HomePage` hiện nhãn ("WiFi", "4G"…).
- `ensureOnline(context, ref)` dùng trước mọi thao tác ghi; offline thì hiện
  Snackbar và **không** gửi request.
- Khi mạng trở lại: `main.dart` gọi `socket.connect()` + `outbox.flush()`.

## Outbox
1. Tin nhắn gửi lúc offline được lưu (clientMessageId + nội dung + hội thoại).
2. Khi có mạng, `flush()` gửi lại tuần tự; server dedup theo `clientMessageId`.
3. Gửi xong mới xoá khỏi hàng đợi; lỗi mạng thì giữ lại cho lần sau.

## Đổi máy chủ
`AppConfig.applyServerHost(raw)` nhận `192.168.1.5`, `192.168.1.5:3000` hoặc
`https://host`. IP trần được thêm cổng 3000; domain (tunnel) giữ cổng 443.
Địa chỉ lưu vào `SharedPreferences`, áp dụng lại khi mở app.

## Certificate pinning
`installCertificatePinning()` chấp nhận certificate khớp SHA-256 trong
`AppConfig.certPinningSha256`; mọi certificate khác bị từ chối (chống MitM).
Khi dùng tunnel Cloudflare (`*.trycloudflare.com`), chứng chỉ do Cloudflare cấp
nên chế độ pin được nới theo `isTunnelHost`.

## Ghi chú
- Đổi máy chủ xong phải kết nối lại socket (app tự làm khi mạng đổi).
- Nếu đổi/regenerate certificate server: chạy `node backend/scripts/gen-cert.js`
  rồi cập nhật `certPinningSha256`.
