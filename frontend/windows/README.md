# `frontend/windows/` — project shell Windows (desktop)

**Vai trò:** mã C++ tối thiểu để chạy app Flutter dưới dạng cửa sổ Win32. Đây là nền tảng đang dùng để chạy thử trên máy phát triển (cùng với Android).
**Ai dùng:** `flutter run -d windows`, `flutter build windows`.

## File / thư mục chính

| Đường dẫn | Nội dung |
|---|---|
| `runner/main.cpp` | Hàm `wWinMain`: khởi tạo COM, tạo `FlutterWindow`, chạy vòng lặp message. |
| `runner/flutter_window.cpp/.h` | Tạo `FlutterViewController`, đăng ký plugin, đặt kích thước cửa sổ ban đầu. |
| `runner/win32_window.cpp/.h` | Lớp cửa sổ Win32: tạo/đăng ký window class, xử lý DPI, resize, đóng. |
| `runner/utils.cpp/.h` | Tiện ích chuyển chuỗi UTF-8 ↔ UTF-16, lấy handle instance. |
| `runner/Runner.rc`, `runner/resources/app_icon.ico` | Thông tin phiên bản (tên app, version) và icon của file `.exe`. |
| `runner/runner.exe.manifest` | Manifest (DPI awareness, phiên bản Windows hỗ trợ). |
| `CMakeLists.txt`, `flutter/CMakeLists.txt` | Cấu hình CMake: biên dịch runner + liên kết Flutter engine (do `flutter` sinh/điều khiển). |

## Luồng build / chạy

```text
flutter build windows            (từ frontend/)
   ├── CMake configure + build runner C++
   ├── copy flutter_windows.dll, plugin DLL, data/ (asset + AOT)
   └── build/windows/x64/runner/Release/dating_app.exe

flutter run -d windows           → build Debug và chạy ngay
   └── build/windows/x64/runner/Debug/dating_app.exe
```

Backend phải chạy (`https://localhost:3000`); đổi địa chỉ trong app: **Cá nhân → ⋯ → Kiểm tra máy chủ & Mạng → Máy chủ**.

## Ghi chú

- Thư mục `flutter/ephemeral/` sinh tự động (bị `.gitignore`) — **không sửa**.
- Ứng dụng desktop Windows cần quyền micro/camera ở mức hệ điều hành; nếu gọi điện không lên hình, kiểm tra **Settings → Privacy → Microphone/Camera**.
- Đổi icon: thay `runner/resources/app_icon.ico` rồi build lại.
- Không thêm logic nghiệp vụ vào C++: mọi thứ nằm ở `../lib/`.
