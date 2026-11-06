# `frontend/linux/` — project shell Linux (desktop)

**Vai trò:** mã C++ tối thiểu để chạy app Flutter trên Linux (GTK). Được tạo tự động bởi `flutter create`, **chưa được kiểm thử** trong dự án này (máy phát triển là Windows).
**Ai dùng:** `flutter build linux` / `flutter run -d linux` trên máy Linux có đủ toolchain.

## File / thư mục chính

| Đường dẫn | Nội dung |
|---|---|
| `runner/main.cc` | Hàm `main`: khởi tạo `FlMyApplication`, chạy vòng lặp GTK. |
| `runner/my_application.cc/.h` | Tạo cửa sổ GTK, gắn `FlutterViewController`, header bar, xử lý đóng cửa sổ. |
| `CMakeLists.txt`, `flutter/CMakeLists.txt` | Cấu hình CMake, liên kết Flutter engine (do `flutter` sinh/điều khiển). |

## Điều kiện build

Cần trên máy Linux: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, và Flutter SDK.

```bash
flutter config --enable-linux-desktop
flutter build linux --release
# → build/linux/x64/release/bundle/dating_app
```

## Ghi chú

- Trên Windows không build được thư mục này — dùng `windows/` hoặc Android.
- `flutter/ephemeral/` sinh tự động, bị `.gitignore`.
- Nếu port sang Linux thật: kiểm tra quyền micro/camera (PulseAudio), chứng chỉ tự ký của backend và package `flutter_webrtc` cho Linux.
- Không đặt logic nghiệp vụ ở đây; sửa giao diện trong `../lib/`.
