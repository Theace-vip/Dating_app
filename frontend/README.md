# SoulMate — Frontend (Flutter)

Ứng dụng hẹn hò đa nền tảng, giao tiếp với backend Node.js qua **REST API** và
**Socket.IO**. Tài liệu này giải thích mã nguồn và từng chức năng; mỗi chức năng
có một tài liệu riêng trong [`docs/`](docs/).

## Chạy nhanh

```bash
cd frontend
flutter pub get
flutter run -d windows      # hoặc -d <thiết bị Android>
```

Backend phải chạy trước (`cd ../backend && npm start`, mặc định
`https://localhost:3000`). Đổi máy chủ trong app: **Cá nhân → ⋯ → Kiểm tra máy
chủ & Mạng → Máy chủ**.

Tài khoản thử: `demo1@soulmate.app` / `demo2@soulmate.app`, mật khẩu `Demo@1234`.

## Công nghệ

| Thành phần | Thư viện |
|---|---|
| Quản lý trạng thái | `flutter_riverpod` (StateNotifier + Provider) |
| Điều hướng | `go_router` (redirect theo trạng thái đăng nhập) |
| HTTP | `dio` + interceptor tự refresh token |
| Realtime | `socket_io_client` |
| Gọi thoại/video | `flutter_webrtc` |
| Lưu token | `flutter_secure_storage` |
| Lưu cấu hình | `shared_preferences` |
| Hoạt ảnh | `lottie`, `svgaplayer` (quà trong phòng) |
| Khác | `image_picker`, `file_picker`, `share_plus`, `connectivity_plus`, `cached_network_image` |

## Bản đồ mã nguồn

```text
lib/
├── main.dart                 Điểm vào: pinning, đổi server, socket, ví realtime, cuộc gọi đến
├── app/router.dart           go_router + redirect theo AuthState
├── core/
│   ├── constants/app_config.dart   URL API/socket, ICE servers, cert pin
│   ├── network/              connectivity, outbox (gửi lại khi offline), pinning
│   └── theme/app_theme.dart  màu, typography
├── data/
│   ├── api/                  api_client.dart (dio), socket_client.dart (Socket.IO)
│   ├── models/models.dart    UserModel, PostModel, MessageModel, RoomModel…
│   └── repositories/         auth, chat (+feed/rooms), catalog, social (bạn bè)
├── features/
│   ├── auth/                 splash, đăng nhập, thiết lập hồ sơ
│   ├── home/                 khung 5 tab + banner mạng
│   ├── chat/                 danh sách chat, chat 1-1, bạn bè, tìm người
│   ├── feed/                 bảng tin, đăng bài, bình luận
│   ├── matching/             Soul Game (ẩn danh) và Voice Game
│   ├── room/                 phòng tiệc, quà SVGA
│   ├── call/                 gọi thoại/video WebRTC
│   └── profile/              trang cá nhân, chỉnh sửa, ví, VIP, chẩn đoán mạng
└── shared/                   widget dùng chung (AppAvatar, EmptyState…), tiện ích ảnh
```

## Nguyên tắc chung

1. **Server là nguồn sự thật.** Giá quà, thời lượng phiên, số Xu, danh mục avatar
   … đều tải từ backend; app không hard-code nghiệp vụ.
2. **Không có dữ liệu mẫu.** Bài viết, bình luận, phòng, bạn bè chỉ hiển thị khi
   có bản ghi thật trong database. Chưa có thì hiển thị trạng thái rỗng.
3. **Realtime mặc định.** Mọi dữ liệu thay đổi được server phát qua Socket.IO và
   provider tương ứng tự cập nhật; nút "làm mới" chỉ là phương án dự phòng.
4. **Optimistic + đối chiếu.** Thao tác like/gửi tin cập nhật ngay trên UI, sau đó
   đối chiếu với phản hồi server; lỗi thì hoàn tác.

## Danh sách tài liệu chức năng

| # | Chức năng | Tài liệu |
|---|---|---|
| 0 | Kiến trúc & luồng dữ liệu | [docs/00_kien_truc.md](docs/00_kien_truc.md) |
| 1 | Xác thực, phiên, đăng xuất | [docs/01_xac_thuc.md](docs/01_xac_thuc.md) |
| 2 | Trang cá nhân & bạn bè | [docs/02_ho_so_ca_nhan.md](docs/02_ho_so_ca_nhan.md) |
| 3 | Chat 1-1 | [docs/03_chat_1_1.md](docs/03_chat_1_1.md) |
| 4 | Soul Game & Voice Game | [docs/04_soul_game.md](docs/04_soul_game.md) |
| 5 | Phòng tiệc & quà tặng | [docs/05_phong_tiec_qua_tang.md](docs/05_phong_tiec_qua_tang.md) |
| 6 | Feed: bài viết, like, bình luận | [docs/06_feed.md](docs/06_feed.md) |
| 7 | Gọi thoại/video WebRTC | [docs/07_goi_dien.md](docs/07_goi_dien.md) |
| 8 | Mạng, offline, bảo mật kết nối | [docs/08_mang_offline_bao_mat.md](docs/08_mang_offline_bao_mat.md) |
| 9 | Catalog, ví Xu, VIP | [docs/09_catalog_vi_vip.md](docs/09_catalog_vi_vip.md) |
| 10 | Bảng sự kiện Socket.IO | [docs/10_su_kien_realtime.md](docs/10_su_kien_realtime.md) |

## Tài liệu theo thư mục

Mỗi thư mục mã nguồn có `README.md` riêng: nó làm gì, file nào làm gì, và luồng chạy qua những file nào.

| Thư mục | Tài liệu |
|---|---|
| Toàn bộ `lib/` | [lib/README.md](lib/README.md) |
| Điều hướng | [lib/app/README.md](lib/app/README.md) |
| Hằng số / mạng / theme | [lib/core/README.md](lib/core/README.md) · [constants](lib/core/constants/README.md) · [network](lib/core/network/README.md) · [theme](lib/core/theme/README.md) |
| Dữ liệu | [lib/data/README.md](lib/data/README.md) · [api](lib/data/api/README.md) · [models](lib/data/models/README.md) · [repositories](lib/data/repositories/README.md) |
| Màn hình | [lib/features/README.md](lib/features/README.md) · [auth](lib/features/auth/README.md) · [chat](lib/features/chat/README.md) · [feed](lib/features/feed/README.md) · [home](lib/features/home/README.md) · [matching](lib/features/matching/README.md) · [room](lib/features/room/README.md) · [call](lib/features/call/README.md) · [profile](lib/features/profile/README.md) |
| Dùng chung | [lib/shared/README.md](lib/shared/README.md) · [widgets](lib/shared/widgets/README.md) |
| Asset | [assets/README.md](assets/README.md) |
| Tài liệu chức năng | [docs/README.md](docs/README.md) |
| Test / tool | [test/README.md](test/README.md) · [tool/README.md](tool/README.md) · [integration_test/README.md](integration_test/README.md) |
| Project shell | [android](android/README.md) · [ios](ios/README.md) · [web](web/README.md) · [windows](windows/README.md) · [linux](linux/README.md) · [macos](macos/README.md) |
| Backend | [../backend/README.md](../backend/README.md) · [src](../backend/src/README.md) · [scripts](../backend/scripts/README.md) |

**Luồng code từ file này sang file khác** (ví dụ chat: `chat_detail_page.dart` → `chat_repository.dart` → `api_client.dart` → `routes.js` → `db.js` → `socket.js` → quay lại UI): xem [`../docs/LUONG_CODE_THEO_FILE.md`](../docs/LUONG_CODE_THEO_FILE.md).
