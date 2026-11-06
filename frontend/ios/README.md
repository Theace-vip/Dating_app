# `frontend/ios/` — project shell iOS

**Vai trò:** cấu hình để đóng gói app cho iPhone/iPad bằng Xcode. Không chứa logic nghiệp vụ.
**Điều kiện build:** cần **macOS + Xcode** (không build được trên Windows). Trên máy Windows thư mục này chỉ được giữ để đồng bộ cấu trúc project.

## File / thư mục chính

| Đường dẫn | Nội dung |
|---|---|
| `Runner/Info.plist` | Tên hiển thị, `NSMicrophoneUsageDescription`, `NSCameraUsageDescription` (bắt buộc khi dùng mic/camera cho gọi điện, mic phòng). Thiếu các key này app sẽ bị iOS từ chối quyền và crash khi gọi. |
| `Runner/AppDelegate.swift`, `Runner/SceneDelegate.swift` | Điểm vào ứng dụng iOS, đăng ký plugin Flutter. |
| `Runner/Base.lproj/LaunchScreen.storyboard`, `Main.storyboard` | Màn hình khởi động và storyboard chính. |
| `Runner/Assets.xcassets/` | Icon app (`AppIcon.appiconset`) và ảnh launch (`LaunchImage.imageset`). |
| `Runner/GeneratedPluginRegistrant.*` | Sinh tự động từ plugin — không sửa tay. |
| `Runner.xcodeproj/`, `Runner.xcworkspace/` | Project/workspace Xcode; mở `Runner.xcworkspace` khi build. |
| `Flutter/Debug.xcconfig`, `Release.xcconfig`, `AppFrameworkInfo.plist` | Cấu hình build Flutter do `flutter` sinh/điều khiển. |
| `RunnerTests/` | Test mặc định của template (chưa dùng). |

## Luồng build (trên macOS)

```text
flutter build ios --release        (từ frontend/)
   ├── đọc pubspec.yaml + lib/
   ├── CocoaPods cài plugin (flutter_webrtc, image_picker, …)
   ├── Xcode build Runner.xcworkspace
   └── Runner.app  → ký bằng Apple Developer account trước khi cài/phát hành
```

## Ghi chú

- Gọi thoại/video cần cả `NSMicrophoneUsageDescription` và `NSCameraUsageDescription`; thiếu một cái là bị crash khi mở `CallPage`.
- Backend dùng HTTPS tự ký: trên iOS, chính sách ATS có thể chặn — cần dùng tunnel có cert hợp lệ hoặc cấu hình ngoại lệ trong `Info.plist`.
- Đổi tên app/bundle id: sửa `Info.plist` và phần General trong Xcode.
- `Flutter/ephemeral/` là sinh tự động, bị `.gitignore`.
