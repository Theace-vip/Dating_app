# `frontend/macos/` — project shell macOS (desktop)

**Vai trò:** cấu hình đóng gói app Flutter cho macOS. **Chưa được kiểm thử** trong dự án (máy phát triển là Windows); build cần macOS + Xcode.
**Ai dùng:** `flutter build macos` / `flutter run -d macos` trên máy Mac.

## File / thư mục chính

| Đường dẫn | Nội dung |
|---|---|
| `Runner/AppDelegate.swift` | Điểm vào ứng dụng, đăng ký plugin, tạo cửa sổ chính. |
| `Runner/MainFlutterWindow.swift` | Tạo `FlutterViewController` và đặt kích thước cửa sổ. |
| `Runner/Info.plist` | Metadata app (tên, bundle id, phiên bản). |
| `Runner/Configs/AppInfo.xcconfig` | `PRODUCT_NAME`, bundle identifier — đổi tên app ở đây. |
| `Runner/DebugProfile.entitlements`, `Runner/Release.entitlements` | Quyền sandbox của app; cần bật **network client** để gọi backend, và quyền micro/camera nếu dùng gọi điện. |
| `Runner/Base.lproj/MainMenu.xib` | Menu ứng dụng macOS. |
| `Runner/Assets.xcassets/` | Icon app (`app_icon_*.png`). |
| `Runner.xcodeproj/`, `Runner.xcworkspace/` | Project/workspace Xcode. |
| `Flutter/*.xcconfig` | Cấu hình build Flutter (sinh/điều khiển bởi `flutter`). |

## Luồng build (trên macOS)

```text
flutter build macos --release
   ├── CocoaPods cài plugin
   ├── Xcode build Runner.xcworkspace
   └── build/macos/Build/Products/Release/dating_app.app
```

## Ghi chú

- Nếu app không gọi được server: kiểm tra `*.entitlements` có `com.apple.security.network.client`.
- Gọi thoại/video cần khai báo mô tả quyền micro/camera trong `Info.plist` (giống iOS).
- Chứng chỉ backend tự ký có thể bị ATS chặn — dùng tunnel cert hợp lệ hoặc cấu hình ngoại lệ.
- Không đặt logic nghiệp vụ ở đây; sửa giao diện trong `../lib/`.
