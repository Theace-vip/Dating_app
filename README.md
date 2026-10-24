# SoulMate — Ứng dụng hẹn hò (Flutter + Node.js backend)

Ứng dụng hẹn hò đa nền tảng (iOS + Android) tương tự Litmatch.
**App THẬT: backend + database + realtime + gọi thoại WebRTC.**

## Chức năng

### Hoạt động thật (đã tích hợp backend)

| Nhóm | Chi tiết |
|---|---|
| **Tài khoản** | Đăng ký/đăng nhập email + mật khẩu qua REST API backend (scrypt hash, access/refresh JWT xoay), khôi phục phiên, đăng xuất, **đổi mật khẩu** |
| **Catalog & nghiệp vụ** | `GET /api/catalog` cung cấp catalog hồ sơ/avatar/sở thích, quà phòng, gói Xu, VIP và thời lượng; backend xác thực hồ sơ và tự định giá/trừ Xu khi tặng quà |
| **Chat 1-1** | Tin nhắn realtime (Socket.io), gửi **ảnh thật**, **typing indicator**, **sửa/xóa tin**, phân trang lịch sử, tin nhắn gửi khi offline **tự gửi lại khi có mạng** |
| **Gọi thoại/video** | **WebRTC thật** (1-1) từ màn chat — có màn gọi đến, mic/loa/camera hoạt động |
| **Trò chơi tâm giao** | Ghép 2 người ẩn danh thật qua hàng đợi server, chat realtime, hiện danh tính + kết bạn |
| **Trò chơi giọng nói** | Ghép queue voice riêng + **thoại WebRTC thật** 90 giây |
| **Phòng tiệc** | Tạo phòng mới, chat nhóm realtime, thả tim, gửi quà (trừ Xu thật), **mic thật (mesh WebRTC)**, thành viên online realtime |
| **Feed** | Đăng bài kèm **ảnh thật**, like/share, **bình luận** (sửa/xóa), **sửa/xóa bài**, phân trang vô tận, bấm vào tác giả → xem hồ sơ — **bài mới/like/bình luận hiển thị realtime trên mọi thiết bị đang mở app** |
| **Kết bạn** | Danh sách bạn bè, **tìm kiếm người dùng** theo tên/email, hồ sơ công khai + nhắn tin |
| **Hồ sơ** | Avatar/upload ảnh thật, ví Xu/Kim cương (số dư thật), thẻ trạng thái **mạng + ping máy chủ** |
| **connectivity_plus** | Hiện **loại mạng** (WiFi/4G/Ethernet/VPN) trên appbar + banner, **kiểm tra mạng trực tiếp** trước mỗi thao tác, hàng đợi outbox tự gửi lại, socket tự kết nối lại khi có mạng |

### Chưa làm (cần yếu tố bên ngoài)

- **Nạp Xu / đăng ký VIP chưa hoạt động**: app chỉ tải và hiển thị catalog/bảng giá; backend đang đặt `purchasesEnabled: false`, không tự cộng Xu hoặc cấp VIP. Cần tích hợp cổng thanh toán và xác minh giao dịch phía server trước khi bật (MoMo/VNPay/IAP).
- Đăng nhập SĐT OTP (cần Twilio/Firebase), Google Sign-In (cần Firebase)
- Push notification, deploy server chính thức (VPS + domain — tạm thời dùng tunnel)

## Cấu trúc

```
dating_app/
├── cai_dat.bat            # CÀI ĐẶT MỘT LẦN (build APK + cài + chạy server + adb reverse)
├── ket_noi_internet.bat   # MỞ INTERNET: server + tunnel Cloudflare -> vào từ bất kỳ đâu
├── mo_ket_noi_mang.bat    # Mở firewall Windows cổng 3000 (chạy 1 lần, quyền Admin)
├── sao_luu.bat            # Sao lưu database (giữ 14 bản gần nhất)
├── server/                # Backend Node.js (HTTPS + Socket.io + SQLite)
│   ├── src/
│   │   ├── index.js       # HTTPS, helmet, rate limit, /uploads tĩnh
│   │   ├── auth.js        # register/login/refresh/logout (scrypt, JWT xoay, lockout)
│   │   ├── routes.js      # auth, catalog, profile, chat, feed, phòng, upload, tìm kiếm, bạn bè
│   │   ├── catalog.js     # catalog server-side + quy tắc trừ Xu khi tặng quà
│   │   ├── socket.js      # realtime + WebRTC signaling (call, voice, mic phòng)
│   │   ├── db.js          # SQLite (node:sqlite) + seed
│   │   └── security.js    # scrypt, JWT, refresh token
│   ├── certs/server.crt   # certificate HTTPS (app pin SHA-256)
│   ├── data/soulmate.db   # database (tự tạo khi chạy lần đầu)
│   ├── backups/           # bản sao lưu (sao_luu.bat)
│   └── scripts/
│       ├── gen-cert.js    # tạo certificate + in cert pin
│       ├── backup_db.js   # sao lưu DB
│       ├── e2e_test.js    # smoke test REST/auth/feed/chat/phòng (31 check gần nhất)
│       ├── e2e_test2.js   # smoke test REST mở rộng + realtime (36 check gần nhất)
│       └── socket_test.js # smoke test catalog/quà + Socket/WebRTC (50 check gần nhất)
├── lib/
│   ├── main.dart          # cert pinning, socket lifecycle, gọi đến, outbox
│   ├── core/network/      # pinning, connectivity_plus, outbox
│   ├── data/api/          # Dio (auto refresh), SocketService
│   ├── data/repositories/ # auth, chat/feed/room (gọi API)
│   ├── features/
│   │   ├── call/          # rtc_session.dart (WebRTC tái sử dụng), call_page
│   │   ├── matching/      # Soul Game text + Voice Game (WebRTC)
│   │   ├── chat/          # chat, tìm kiếm, bạn bè
│   │   ├── feed/          # feed + bình luận
│   │   ├── room/          # phòng tiệc (mic mesh)
│   │   └── profile/       # cá nhân, chỉnh sửa, ví, VIP, hồ sơ công khai
│   └── shared/            # AppAvatar, AppButton, image_tools...
├── tool/client_smoke.dart # test client thuần Dart (pinning + REST + socket)
└── test/widget_test.dart
```

## Cài đặt (Windows, điện thoại Android cắm cáp USB)

1. Cài **Flutter SDK** + **Node.js** (>= 22.5) nếu chưa có.
2. Bật **Developer Options** + **USB Debugging**, cắm cáp USB.
3. Chạy **`cai_dat.bat`** (click đúp) — tự động: `pub get` + `npm install` →
   tạo certificate → build APK → cài vào điện thoại → `adb reverse tcp:3000` →
   khởi động server → mở app.
4. Đăng ký bằng email trong app, hoặc dùng tài khoản mẫu:

```
demo1@soulmate.app / Demo@1234
demo2@soulmate.app / Demo@1234
```

> **Test gọi thoại / Voice Game / Soul Game**: cần **2 điện thoại** (2 tài khoản).

### Lệnh hữu ích

```bash
flutter run                 # dev hot reload (server phải đang chạy)
flutter build apk --debug   # build APK cài tay
flutter build apk --release # bản release (R8/ProGuard bật sẵn)
sao_luu.bat                 # sao lưu database

cd server
node scripts/e2e_test.js      # smoke test REST/auth/feed/chat/phòng (31 check gần nhất)
node scripts/e2e_test2.js     # smoke test REST mở rộng + realtime (36 check gần nhất)
node scripts/socket_test.js   # catalog/quà + Socket/WebRTC (50 check gần nhất)

flutter test                # unit test app
flutter analyze             # static analysis
dart run tool/client_smoke.dart  # test pinning + REST + socket từ Dart
```

## Bảo mật

| Hạng mục | Cách làm |
|---|---|
| Mật khẩu | **scrypt** (N=16384, salt 16 byte, timing-safe) — không lưu plain text |
| Đăng nhập | Rate limit 15/15 phút theo **IP + email**; sai 5 lần → khóa 15 phút |
| Token | Access JWT **15 phút** + refresh **xoay rotation**; dùng lại → thu hồi cả gia đình |
| Truyền dữ liệu | **HTTPS + cert pinning SHA-256** ở app (chống MitM, đã có test chứng minh) |
| Lưu token | FlutterSecureStorage (Android Keystore) |
| API | Helmet, validate input, SQL parameterized, payload limit 10MB; các API nghiệp vụ và catalog cần Bearer token |
| Ảnh upload | Chỉ nhận jpeg/png/webp ≤ 5MB, đổi tên ngẫu nhiên khi lưu |
| Release APK | **R8/ProGuard** bật: thu nhỏ + mã hoá tên lớp (proguard-rules.pro) |
| Mạng | connectivity_plus: banner theo loại mạng, kiểm tra trực tiếp trước thao tác, outbox gửi lại |
| DB | `sao_luu.bat` — snapshot VACUUM INTO, giữ 14 bản gần nhất |

### Cert pinning

App chỉ chấp nhận cert có SHA-256 khớp `AppConfig.certPinningSha256`.
Nếu regenerate cert (`node server/scripts/gen-cert.js --force`), script in pin mới —
cập nhật vào `lib/core/constants/app_config.dart` rồi build lại app.

## Kịch bản kết nối (đổi ngay trong app, không cần build lại)

Địa chỉ máy chủ đổi tại **Cá nhân → thẻ Mạng → Demo connectivity_plus → “Máy chủ”**
(lưu vào SharedPreferences, áp dụng lại khi mở app):

| Kịch bản | Nhập vào ô “Máy chủ” | Điều kiện |
|---|---|---|
| Cáp USB | `localhost` (mặc định) | `cai_dat.bat` đã `adb reverse` |
| Cùng WiFi | `192.168.1.91` (IP in lúc server khởi động) | chạy `mo_ket_noi_mang.bat` 1 lần mở firewall |
| **Từ bất kỳ đâu (internet)** | `https://xxx.trycloudflare.com` | chạy **`ket_noi_internet.bat`** — tự copy URL vào clipboard |
| Emulator | `10.0.2.2` | — |

- **Tunnel** (`ket_noi_internet.bat`): server + cloudflared cùng 1 script, không cần cài đặt router/VPS.
  URL thay mỗi lần mở lại → nhập lại khi app báo mất kết nối.
  Khi ở chế độ tunnel, app **chỉ bỏ pinning đúng host tunnel đó** (cert do Cloudflare cấp,
  không pin được theo cert SoulMate); mọi host khác vẫn bắt buộc đúng pin.
- WebRTC chạy xuyên LAN/internet nhờ STUN public (test: WebSocket 101 + /health 200 qua tunnel).

## Lỗi đã biết trên Windows

- `PUB_CACHE` phải cùng ổ với project (dùng `D:\flutter_pub_cache`).
- Package name `com.datingapp.dating_app` — đừng đổi.

## Giai đoạn sau

- Thanh toán nạp Xu/VIP (MoMo/VNPay/IAP — cần tài khoản doanh nghiệp)
- OTP SĐT + Google Sign-In (cần Firebase/Twilio)
- Push notification
- Deploy server thật (Let's Encrypt, PostgreSQL, monitoring)
