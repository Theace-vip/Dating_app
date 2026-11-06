# `frontend/lib/core/constants/` — hằng số và cấu hình

**Vai trò:** nơi duy nhất giữ địa chỉ server, URL API/socket, danh sách STUN và các hằng số trình bày.
**Ai gọi tới:** `main.dart`, `data/api/api_client.dart`, `data/api/socket_client.dart`, `core/network/pinning.dart`, mọi màn hình cần `absoluteUrl()` hoặc màu/khoảng cách.

## File trong thư mục

| File | Nội dung chính |
|---|---|
| `app_config.dart` | `AppConfig.serverHost` / `apiBaseUrl` / `socketUrl` (mặc định `https://localhost:3000`); `applyServerHost(raw)` chuẩn hoá chuỗi người dùng nhập (tự thêm `:3000` cho IP/localhost, giữ nguyên domain tunnel); `isTunnelHost` nhận diện `trycloudflare.com`/`ngrok`; `certPinningSha256` — fingerprint chứng chỉ backend; `iceServers` — STUN cho WebRTC; `absoluteUrl(url)` đổi `/uploads/x.jpg` thành URL đầy đủ; `appName`, `appVersion`. `AppConstants` để trống, chờ hằng số thuần giao diện. |
| `app_style.dart` | `AppSpacing` (khoảng cách chuẩn), `AppTextStyle` (style chữ), `AppColorsText` (màu chữ ngữ nghĩa). |

## Luồng đổi máy chủ

```text
features/profile/network_demo_page.dart  (hoặc dialog trong shared/server_host.dart)
   └── shared/server_host.dart: saveServerHost()
         ├── AppConfig.applyServerHost(raw)        ← cập nhật apiBaseUrl + socketUrl
         ├── SharedPreferences.setString('server_host', host)   ← nhớ cho lần mở sau
         └── apiClient / socket nối lại theo URL mới

main.dart: main()
   └── đọc 'server_host' từ SharedPreferences → AppConfig.applyServerHost()
```

## Lưu ý quan trọng

- **Đổi chứng chỉ HTTPS** (chạy lại `backend/scripts/gen-cert.js`) thì phải cập nhật `certPinningSha256`, nếu không app sẽ từ chối kết nối (đúng thiết kế chống MitM).
- Host tunnel dùng chứng chỉ của Cloudflare/ngrok nên không pin được; `pinning.dart` chỉ bỏ qua pin cho đúng host tunnel người dùng đã nhập.
- Không đặt giá quà/gói Xu/danh mục avatar ở đây — chúng đến từ `/api/catalog`.
