# `frontend/web/` — project shell web

**Vai trò:** cho phép chạy thử app trên trình duyệt (`flutter run -d chrome`). **Không phải nền tảng chính** — app được thiết kế cho mobile/desktop.
**Ai dùng:** khi cần xem nhanh giao diện hoặc debug UI mà không mở thiết bị.

## File trong thư mục

| File | Nội dung |
|---|---|
| `index.html` | Trang khung: thẻ `<title>`, meta viewport, nạp `flutter_bootstrap.js`. |
| `manifest.json` | Manifest PWA: tên app, màu nền, icon — dùng khi "Add to Home Screen". |
| `favicon.png` | Icon tab trình duyệt. |
| `icons/` | `Icon-192.png`, `Icon-512.png`, `Icon-maskable-192/512.png` cho PWA. |

## Cách chạy

```bash
cd frontend
flutter run -d chrome --web-port 5000
```

Nếu gặp lỗi CORS/cert với backend tự ký, mở trước `https://localhost:3000/health` trong tab mới và chấp nhận cảnh báo chứng chỉ của trình duyệt.

## Hạn chế trên web

| Tính năng | Tình trạng |
|---|---|
| Certificate pinning | Không áp dụng — `pinning.dart` dùng `dart:io`, chỉ chạy trên mobile/desktop |
| Lưu token | `flutter_secure_storage` dùng localStorage trên web (kém an toàn hơn keychain/keystore) |
| Gọi thoại/video, mic phòng | Phụ thuộc quyền trình duyệt và yêu cầu HTTPS |
| Thông báo cuộc gọi đến | Chỉ hoạt động khi tab đang mở |

## Ghi chú

- Không sửa `index.html` trừ khi cần đổi meta/PWA.
- Không dùng web để kiểm chứng bảo mật hay WebRTC — hãy test trên Android/Windows.
