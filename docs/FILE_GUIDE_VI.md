# Danh mục thư mục và file — SoulMate

Tài liệu này giải thích **từng thư mục, từng file code dùng để làm gì** và khi cần sửa chức năng thì nên vào đâu.

Đọc kèm:

- [`README.md`](../README.md) — tổng quan, cài đặt, API.
- [`docs/CODE_FLOWS_VI.md`](CODE_FLOWS_VI.md) — luồng chạy chi tiết theo chức năng.
- [`docs/PROJECT_GUIDE_VI.md`](PROJECT_GUIDE_VI.md) — kiến trúc và các luồng lớn.

---

## 1. Cây thư mục tổng quan

```text
dating_app/
├── lib/                    # Toàn bộ app Flutter
│   ├── main.dart
│   ├── app/                # Điều hướng
│   ├── core/               # Cấu hình, theme, mạng, bảo mật
│   ├── data/               # API, model, repository (state)
│   ├── features/           # Màn hình theo nghiệp vụ
│   └── shared/             # Widget/tiện ích dùng chung
├── server/                 # Backend Node.js
│   ├── src/                # Mã nguồn server
│   ├── scripts/            # Sinh cert, backup, smoke test
│   ├── certs/              # Cert HTTPS (không commit)
│   ├── data/               # SQLite (không commit)
│   ├── uploads/            # Ảnh người dùng (không commit)
│   └── backups/            # Bản sao lưu DB (không commit)
├── test/                   # Unit test Flutter
├── integration_test/       # Kiểm thử tích hợp trên thiết bị
├── tool/                   # Script kiểm tra client thuần Dart
├── assets/                 # Ảnh/icon/animations
├── docs/                   # Tài liệu dự án
├── android/ ios/ web/      # Project shell từng nền tảng
│   windows/ linux/ macos/
├── cai_dat.bat             # Cài đặt một lần trên Windows
├── ket_noi_internet.bat    # Server + Cloudflare tunnel
├── mo_ket_noi_mang.bat     # Mở firewall cổng 3000
├── sao_luu.bat             # Sao lưu database
├── pubspec.yaml            # Khai báo package/asset Flutter
└── analysis_options.yaml   # Quy tắc lint Dart
```

---

## 2. File ở thư mục gốc

| File | Dùng để làm gì |
|---|---|
| `README.md` | Tổng quan dự án, tính năng, kiến trúc, API, cài đặt, kiểm thử, bảo mật. |
| `pubspec.yaml` | Khai báo tên app, phiên bản, dependency Flutter và thư mục `assets/`. |
| `pubspec.lock` | Khóa phiên bản package thực tế; commit để mọi máy build giống nhau. |
| `analysis_options.yaml` | Bật/tắt quy tắc lint của Dart/Flutter. |
| `.gitignore` | Loại trừ secret, database, ảnh upload, build, APK, log khỏi Git. |
| `cai_dat.bat` | Cài đặt một lần trên Windows: `pub get`, `npm install`, tạo cert, build APK, cài máy, `adb reverse`, chạy server. |
| `ket_noi_internet.bat` | Chạy server + Cloudflare tunnel để điện thoại truy cập từ internet. |
| `mo_ket_noi_mang.bat` | Mở firewall Windows cổng 3000 cho điện thoại cùng WiFi. |
| `sao_luu.bat` | Gọi script sao lưu SQLite, giữ 14 bản gần nhất. |
| `PC` | File rỗng còn sót lại, không ảnh hưởng; đã bị `.gitignore` bỏ qua. |
| `build_full.log`, `run_log*.txt`, `tunnel.log`, ... | Log tạo trong quá trình phát triển; không commit. |

---

## 3. `lib/` — ứng dụng Flutter

### 3.1. Điểm vào và điều hướng

| File | Chức năng |
|---|---|
| `lib/main.dart` | Khởi động app: cài certificate pinning, khôi phục địa chỉ server, tạo `ProviderScope`. `_MyAppState` giữ socket toàn app, nghe `user:wallet`, mở `CallPage` khi có `call:invite`, kết nối lại khi mạng trở lại, flush outbox. |
| `lib/app/router.dart` | Khai báo `GoRouter`, `rootNavigatorKey` và logic redirect: splash khi đang khôi phục phiên, login khi chưa đăng nhập, profile-setup khi thiếu hồ sơ, home khi đã đủ. |

### 3.2. `lib/core/` — nền tảng dùng chung

| File | Chức năng |
|---|---|
| `core/constants/app_config.dart` | Địa chỉ server (`serverHost`, `apiBaseUrl`, `socketUrl`), chuẩn hóa IP/domain, nhận diện host tunnel, cấu hình cert pin và ICE servers. |
| `core/constants/app_style.dart` | Hằng số khoảng cách (`AppSpacing`) và text style (`AppTextStyle`, `AppColorsText`) dùng chung. |
| `core/theme/app_theme.dart` | Bảng màu `AppColors`, gradient, theme sáng cho Material. |
| `core/network/connectivity_service.dart` | Bọc `connectivity_plus`: stream loại mạng, `isOnlineProvider`, nhãn WiFi/4G, hàm `ensureOnline()` chặn thao tác khi offline. |
| `core/network/outbox.dart` | Hàng đợi tin nhắn offline: lưu vào `SharedPreferences`, `enqueue()`, `flush()` gửi lại khi có mạng. |
| `core/network/pinning.dart` | `HttpOverrides` kiểm tra SHA-256 certificate; chỉ bỏ pin đúng host tunnel; helper tính fingerprint. |

### 3.3. `lib/data/` — API, model, state

| File | Chức năng |
|---|---|
| `data/api/api_client.dart` | `ApiClient` dùng Dio: gắn Bearer token, tự refresh khi 401 (single-flight), lưu token trong secure storage, `get/post/patch/delete`, upload ảnh, báo `onSessionExpired`. |
| `data/api/socket_client.dart` | `SocketService`: một socket có xác thực cho toàn app, chuyển mỗi event thành broadcast stream, danh sách event cần đăng ký, connect/disconnect/dispose. |
| `data/models/models.dart` | Toàn bộ model JSON: `Gender`, `MessageType`, `UserModel`, `MessageModel`, `ConversationModel`, `OriginalPostModel`, `PostModel`, `RoomModel`, `CommentModel`, `RoomMessageModel`. |
| `data/repositories/auth_repository.dart` | `AuthNotifier`/`AuthState`: đăng nhập, đăng ký, khôi phục phiên, đăng xuất, đổi mật khẩu, cập nhật hồ sơ, cập nhật ví; `currentUserProvider`. |
| `data/repositories/catalog_repository.dart` | Model catalog (`AppCatalog`, quà, gói Xu, VIP) và `appCatalogProvider` tải `GET /api/catalog`. |
| `data/repositories/chat_repository.dart` | State nghiệp vụ chính: `ChatNotifier`, `MessagesNotifier`, `FeedNotifier`, `CommentsNotifier`, `RoomsNotifier`, `feedRealtimeProvider`; xử lý optimistic, phân trang, realtime, outbox. |

### 3.4. `lib/features/` — màn hình theo nghiệp vụ

#### Auth

| File | Chức năng |
|---|---|
| `features/auth/login_page.dart` | Form đăng nhập/đăng ký email + mật khẩu; validate; gọi `AuthNotifier`; mở dialog đổi server khi lỗi kết nối; nút OTP/Google đang “sắp ra mắt”. |
| `features/auth/profile_setup_page.dart` | Thiết lập hồ sơ lần đầu: chọn avatar/sở thích từ catalog, nhập tên/tuổi/giới tính/bio, upload ảnh; lưu qua `PATCH /api/me`. |
| `features/auth/splash_page.dart` | Màn chờ khôi phục phiên; watchdog 8 giây đưa về đăng nhập nếu restore treo. |

#### Home

| File | Chức năng |
|---|---|
| `features/home/home_page.dart` | Khung 5 tab: chat, khám phá, feed, phòng, cá nhân. Tải dữ liệu nền, kích hoạt realtime feed, chứa `ExplorePage` với nút vào Soul Game/Voice Game. |

#### Chat

| File | Chức năng |
|---|---|
| `features/chat/chat_list_page.dart` | Danh sách hội thoại, tìm người dùng, mở bạn bè; nghe `chat:message` và `presence:changed` để cập nhật tin cuối/unread/online. |
| `features/chat/chat_detail_page.dart` | Chat 1-1: tải lịch sử, đánh dấu đã đọc, gửi text/ảnh optimistic, outbox khi lỗi, typing, sửa/xóa, phân trang, cuộn giữ vị trí. |
| `features/chat/friends_page.dart` | Tải `GET /api/friends`, hiển thị bạn bè + trạng thái online, mở chat hoặc hồ sơ. |
| `features/chat/search_users_page.dart` | Tìm kiếm người dùng theo tên/email với debounce, mở hồ sơ công khai. |

#### Feed

| File | Chức năng |
|---|---|
| `features/feed/feed_page.dart` | Feed: danh sách bài, like, chia sẻ/repost, sửa/xóa bài, bottom sheet bình luận (thêm/sửa/xóa, realtime, né bàn phím), phân trang. |
| `features/feed/create_post_page.dart` | Soạn bài mới: nội dung + tối đa 3 ảnh (upload thật), gọi `FeedNotifier.addPost`. |

#### Phòng tiệc

| File | Chức năng |
|---|---|
| `features/room/room_list_page.dart` | Danh sách phòng, tạo phòng mới (tên/chủ đề/emoji), mở chi tiết phòng. |
| `features/room/room_detail_page.dart` | Trong phòng: lịch sử chat, gửi tin, thả tim, gửi quà trừ Xu, danh sách thành viên, mic mesh WebRTC, dọn dẹp khi rời. |

#### Ghép đôi

| File | Chức năng |
|---|---|
| `features/matching/soul_game_page.dart` | Soul Game text: vào hàng đợi, chat ẩn danh, đếm giờ server, mở nút tim sau 5 tin/10 giây, thả tim, reveal, gia hạn, tìm người mới. |
| `features/matching/voice_game_page.dart` | Voice Game: queue riêng mode `voice`, thoại WebRTC 90 giây, đếm giờ, gia hạn, reveal, chuyển sang chat. |

#### Gọi thoại/video

| File | Chức năng |
|---|---|
| `features/call/call_page.dart` | UI/state cuộc gọi: gọi đi, nhận cuộc gọi, accept/reject, timer chuông, chuyển phase ringing → connecting → connected → ended, bật/tắt mic/camera/loa. |
| `features/call/rtc_session.dart` | Bọc `flutter_webrtc`: xin media, tạo peer connection, offer/answer/ICE, xử lý signaling tuần tự, phát state và remote stream. |

#### Cá nhân

| File | Chức năng |
|---|---|
| `features/profile/profile_page.dart` | Trang cá nhân: thông tin, số Xu/Kim cương, thẻ trạng thái mạng + ping, đổi mật khẩu, mở chỉnh sửa/ví/VIP/demo mạng. |
| `features/profile/edit_profile_page.dart` | Chỉnh sửa hồ sơ: avatar, tên, tuổi, giới tính, bio, sở thích, upload ảnh; lưu `PATCH /api/me`. |
| `features/profile/public_profile_page.dart` | Hồ sơ người khác: tải user + `isFriend`/`isOnline`, nhắn tin, gọi thoại/video. |
| `features/profile/wallet_page.dart` | Ví Xu/Kim cương và bảng giá gói Xu; nút nạp bị khóa khi `purchasesEnabled = false`. |
| `features/profile/vip_page.dart` | Quyền lợi/gói VIP lấy từ catalog; chưa bật mua. |
| `features/profile/network_demo_page.dart` | Màn demo connectivity_plus: log đổi mạng, kiểm tra trực tiếp, ping `/health`, đổi địa chỉ server. |

### 3.5. `lib/shared/` — dùng chung

| File | Chức năng |
|---|---|
| `shared/image_tools.dart` | `pickAndUploadImage()`: chọn ảnh, nén theo `maxWidth/quality`, upload qua `ApiClient`, trả URL `/uploads/...`. |
| `shared/server_host.dart` | `saveServerHost()` lưu địa chỉ server vào `SharedPreferences`, áp dụng cho Dio/socket; `showServerHostDialog()` dialog đổi server kèm kiểm tra `/health`. |
| `shared/widgets/app_widgets.dart` | Widget dùng chung: `AppAvatar`, `AppButton`, `AppTextField`, `AppChip`, `LoadingWidget`, `EmptyState`. |

---

## 4. `server/` — backend Node.js

### 4.1. `server/src/` — mã nguồn

| File | Chức năng |
|---|---|
| `src/index.js` | Điểm vào server: tạo HTTPS (self-signed), helmet/CORS/JSON limit/rate limit, mount `/api/auth`, `/api` sau auth middleware, `/uploads` tĩnh, `/health`, error handler; dùng chung HTTP server cho Socket.IO; in IP LAN và cert pin khi khởi động. |
| `src/config.js` | Xác định `serverRoot`, đọc/ghi `config.json`, defaults cổng 3000, JWT secret ngẫu nhiên, thời hạn access/refresh token. |
| `src/auth.js` | Router auth: register/login/refresh/logout, middleware Bearer, rate limit, khóa sau 5 lần sai, xoay refresh token và phát hiện dùng lại. |
| `src/security.js` | Hash mật khẩu bằng scrypt + salt, verify timing-safe, ký/verify JWT, sinh refresh token, hash token, sinh ID ngẫu nhiên. |
| `src/db.js` | Mở SQLite (`data/soulmate.db`), bật WAL/foreign keys, tạo schema (users, refresh_tokens, friendships, conversations, messages, posts, likes, comments, rooms, room_messages), seed dữ liệu mẫu, helper `publicUser/getUser/getUserByEmail/ensureConversation/addFriendship`. |
| `src/routes.js` | Toàn bộ REST nghiệp vụ: catalog, upload, hồ sơ/bạn bè, hội thoại/tin nhắn, feed/bình luận, phòng; validate quyền sở hữu, phân trang, phát socket event. |
| `src/socket.js` | Realtime: xác thực socket, presence, Soul Game (queue, session, timer, heart, like, reveal), call signaling (invite/accept/reject/hangup), room chat/heart/gift, room mic mesh, cleanup disconnect. |
| `src/catalog.js` | Nguồn sự thật cho catalog: avatar/sở thích, quà phòng + giá, gói Xu, VIP, thời lượng game/call; `chargeRoomGift()` trừ Xu atomic. |

### 4.2. `server/scripts/` — công cụ và kiểm thử

| File | Chức năng |
|---|---|
| `scripts/gen-cert.js` | Tạo certificate HTTPS self-signed (hoặc dùng lại), in SHA-256 pin để cập nhật `AppConfig.certPinningSha256`; export `ensureCert()` cho server. |
| `scripts/backup_db.js` | Snapshot SQLite bằng `VACUUM INTO` vào `backups/`, giữ 14 bản gần nhất. |
| `scripts/e2e_test.js` | Smoke test REST: health, register/login/refresh, profile, feed, comment, share, conversation, room, bảo mật cơ bản. |
| `scripts/e2e_test2.js` | Smoke test mở rộng: upload ảnh, tìm kiếm, đổi mật khẩu, tạo phòng, sửa/xóa bài & bình luận, phân trang tin nhắn, ảnh chat, Soul Game/typing. |
| `scripts/socket_test.js` | Test catalog/quà, socket auth, Soul Game, timer, reveal, room presence/chat/gift, call signaling, heart, room RTC. |
| `scripts/realtime_feed_test.js` | Test riêng các event feed realtime (`feed:new/updated/deleted/stats`, comment). |

### 4.3. File cấu hình và thư mục runtime

| Đường dẫn | Dùng để làm gì |
|---|---|
| `server/package.json` | Khai báo dependency Express, Socket.IO, JWT, helmet... và script `start`, `gen-cert`. |
| `server/package-lock.json` | Khóa phiên bản dependency Node. |
| `server/config.example.json` | Mẫu cấu hình không chứa secret; copy thành `config.json` nếu muốn đổi cổng/thời hạn. |
| `server/config.json` | Cấu hình thật + `jwtSecret`; **không commit**, server tự sinh nếu thiếu. |
| `server/tunnel.bat` | Chạy Cloudflare tunnel trỏ tới server local (dùng khi cần URL công khai). |
| `server/cloudflared.exe` | Binary Cloudflare Tunnel; **không commit** do dung lượng lớn. |
| `server/certs/` | `server.key` + `server.crt` cho HTTPS; **không commit**. |
| `server/data/` | `soulmate.db` + WAL/SHM; **không commit**. |
| `server/uploads/` | Ảnh người dùng upload; **không commit**. |
| `server/backups/` | Các bản sao lưu database; **không commit**. |
| `server/node_modules/` | Dependency cài bằng `npm install`; **không commit**. |

---

## 5. Kiểm thử và công cụ

| File | Chức năng |
|---|---|
| `test/widget_test.dart` | Unit test model và auth state: parse `UserModel`, `PostModel` repost, `ConversationModel`, `MessageModel`, trạng thái đăng nhập. |
| `integration_test/app_test.dart` | Kịch bản integration trên thiết bị thật: đăng nhập, đi qua các màn hình, chụp ảnh. **Lưu ý:** file đang hard-code đường dẫn máy và device ID (`adb`, `_outDir`), cần sửa trước khi chạy trên máy khác. |
| `tool/client_smoke.dart` | Smoke test phía client thuần Dart: kiểm tra cert pinning, login REST, kết nối Socket.IO mà không cần mở app. |

---

## 6. `assets/` và `docs/`

| Đường dẫn | Chức năng |
|---|---|
| `assets/images/` | Ảnh tĩnh dùng trong app (hiện có `.gitkeep`). |
| `assets/icons/` | Icon tùy chỉnh (hiện có `.gitkeep`). |
| `assets/animations/` | File animation (Lottie...) (hiện có `.gitkeep`). |
| `docs/CODE_FLOWS_VI.md` | Luồng chạy code chi tiết từng chức năng. |
| `docs/PROJECT_GUIDE_VI.md` | Hướng dẫn cấu trúc, luồng lớn, WebRTC, feed/bình luận. |
| `docs/FILE_GUIDE_VI.md` | Tài liệu này — danh mục thư mục/file. |

---

## 7. Thư mục nền tảng

Các thư mục này là **project shell** do Flutter tạo; chỉ sửa khi cần cấu hình quyền, icon, tên app hoặc build.

### Android — `android/`

| File/thư mục | Chức năng |
|---|---|
| `android/app/src/main/AndroidManifest.xml` | Khai báo quyền INTERNET, CAMERA, RECORD_AUDIO, activity chính, label `SoulMate`, `windowSoftInputMode=adjustResize`. |
| `android/app/build.gradle.kts` | `applicationId`, min/target SDK, Java 17, bật R8/ProGuard cho release, ký bằng debug key (cần đổi trước khi lên store). |
| `android/app/proguard-rules.pro` | Quy tắc giữ class cho thư viện khi minify. |
| `android/app/src/main/kotlin/.../MainActivity.kt` | `FlutterActivity` mặc định, điểm vào Android. |
| `android/app/src/main/res/` | Icon app, launch background, theme sáng/tối. |
| `android/build.gradle.kts`, `settings.gradle.kts`, `gradle.properties` | Cấu hình Gradle toàn project Android. |

### iOS — `ios/`

| File | Chức năng |
|---|---|
| `ios/Runner/Info.plist` | Tên hiển thị (hiện là `Dating App`), quyền micro/camera (`NSMicrophoneUsageDescription`, `NSCameraUsageDescription`). |
| `ios/Runner/AppDelegate.swift`, `SceneDelegate.swift` | Điểm vào ứng dụng iOS. |
| `ios/Runner/Assets.xcassets/` | Icon và launch image. |
| `ios/Runner.xcodeproj/`, `Runner.xcworkspace/` | Project Xcode; mở bằng Xcode khi build iOS. |

### Các nền tảng khác

| Thư mục | Chức năng |
|---|---|
| `web/` | Shell web (`index.html`, manifest, icon). App chính là mobile; web chỉ để chạy thử. |
| `windows/`, `linux/`, `macos/` | Shell desktop do Flutter tạo; không phải nền tảng chính của dự án. |

---

## 8. Thư mục sinh tự động / không commit

| Đường dẫn | Vì sao không commit |
|---|---|
| `build/`, `.dart_tool/` | Output build và cache Dart/Flutter, rất lớn và tái tạo được. |
| `.flutter-plugins-dependencies` | File sinh theo máy. |
| `dist/`, `*.apk`, `*.aab` | APK/AAB build ra, dung lượng lớn. |
| `server/node_modules/` | Cài lại bằng `npm install`. |
| `server/data/`, `*.db`, WAL/SHM | Dữ liệu thật, có thể chứa thông tin người dùng. |
| `server/uploads/` | Ảnh người dùng. |
| `server/backups/` | Bản sao lưu dữ liệu. |
| `server/certs/`, `*.key`, `*.pem` | Private key HTTPS. |
| `server/config.json`, `.env*` | Chứa secret/JWT. |
| `qa-artifacts/`, log, `*.pid` | File tạm trong quá trình chạy/test. |
| `.idea/`, `.freebuff/`, `*.iml` | Cấu hình IDE/công cụ cá nhân. |

---

## 9. Muốn sửa chức năng thì vào đâu?

| Việc cần làm | File nên xem |
|---|---|
| Đổi địa chỉ server mặc định | `lib/core/constants/app_config.dart` |
| Đổi logic đăng nhập/token | `lib/data/repositories/auth_repository.dart`, `lib/data/api/api_client.dart`, `server/src/auth.js` |
| Thêm API mới | `server/src/routes.js` → `lib/data/api/api_client.dart` → repository tương ứng |
| Sửa feed/bài viết | `lib/features/feed/feed_page.dart`, `lib/data/repositories/chat_repository.dart` (`FeedNotifier`), `server/src/routes.js` |
| Sửa bình luận | `lib/features/feed/feed_page.dart` (`_CommentsSheet`), `CommentsNotifier`, `server/src/routes.js` nhóm BÌNH LUẬN |
| Sửa chat 1-1 | `lib/features/chat/chat_detail_page.dart`, `MessagesNotifier`, `server/src/routes.js` nhóm hội thoại, `server/src/socket.js` |
| Sửa gọi thoại/video | `lib/features/call/call_page.dart`, `lib/features/call/rtc_session.dart`, `server/src/socket.js` nhóm call |
| Sửa Soul Game/Voice Game | `lib/features/matching/*`, `server/src/socket.js` nhóm Soul Game, `server/src/catalog.js` (`matching`) |
| Sửa phòng tiệc/quà | `lib/features/room/*`, `server/src/socket.js` nhóm room, `server/src/catalog.js` (`rooms.gifts`, `chargeRoomGift`) |
| Sửa catalog/ví/VIP | `lib/data/repositories/catalog_repository.dart`, `lib/features/profile/wallet_page.dart`, `vip_page.dart`, `server/src/catalog.js` |
| Đổi giao diện/màu | `lib/core/theme/app_theme.dart`, `lib/core/constants/app_style.dart`, `lib/shared/widgets/app_widgets.dart` |
| Đổi database/schema | `server/src/db.js` (lưu ý chưa có migration cho DB cũ) |
| Thêm event realtime | `server/src/socket.js` (emit) + `lib/data/api/socket_client.dart` (danh sách event) + listener UI |
| Đổi cấu hình HTTPS/pin | `server/scripts/gen-cert.js`, `lib/core/constants/app_config.dart`, `lib/core/network/pinning.dart` |
| Sửa script cài đặt/tunnel | `cai_dat.bat`, `ket_noi_internet.bat`, `mo_ket_noi_mang.bat`, `sao_luu.bat` |

---

## 10. Quy ước khi thêm file mới

1. **Màn hình mới:** đặt trong `lib/features/<nghiệp vụ>/`, dùng `ConsumerWidget`/`ConsumerStatefulWidget` nếu cần Riverpod.
2. **Gọi API mới:** thêm hàm vào `ApiClient` hoặc repository; không gọi Dio trực tiếp rải rác trong widget.
3. **State mới:** thêm `StateNotifier`/`Provider` vào `lib/data/repositories/`, không giữ state nghiệp vụ trong widget nếu nhiều màn hình dùng chung.
4. **Socket event mới:** emit ở server, thêm tên event vào `SocketService.connect()`, listen ở UI/repository và hủy subscription khi dispose.
5. **Model mới:** đặt trong `lib/data/models/models.dart` (hoặc tách file nếu lớn), parse null-safe, có `fromJson`.
6. **Tài liệu:** cập nhật `README.md` và tài liệu liên quan nếu thay đổi API, cấu hình hoặc luồng chính.
