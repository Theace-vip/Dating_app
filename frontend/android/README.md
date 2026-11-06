# `frontend/android/` — project shell Android

**Vai trò:** cấu hình để Flutter đóng gói app thành APK/AAB: quyền hệ thống, tên app, icon, cấu hình Gradle. Không chứa logic nghiệp vụ (logic nằm ở `../lib/`).
**Ai dùng:** `flutter build apk`, `flutter run -d <android>`, `cai_dat.bat`.

## File / thư mục chính

| Đường dẫn | Nội dung |
|---|---|
| `app/src/main/AndroidManifest.xml` | Quyền `INTERNET`, `CAMERA`, `RECORD_AUDIO` (chat ảnh, gọi thoại/video, mic phòng); activity chính; `android:label` = **SoulMate**; `windowSoftInputMode=adjustResize` để bàn phím không che ô nhập. |
| `app/build.gradle.kts` | `applicationId`, `minSdk`/`targetSdk`, Java 17, bật R8/ProGuard cho release. Hiện ký bằng debug key — **phải đổi keystore trước khi phát hành**. |
| `app/proguard-rules.pro` | Quy tắc giữ class cho các thư viện khi minify. |
| `app/src/main/kotlin/com/datingapp/dating_app/MainActivity.kt` | `FlutterActivity` mặc định — điểm vào phía Android. |
| `app/src/main/res/` | Icon app (`mipmap-*`), launch background, theme sáng/tối (`values`, `values-night`). |
| `build.gradle.kts`, `settings.gradle.kts`, `gradle.properties` | Cấu hình Gradle toàn project, đường dẫn Flutter SDK. |
| `gradle/wrapper/` + `gradlew`, `gradlew.bat` | Gradle wrapper — giữ nguyên phiên bản để build ổn định. |
| `local.properties` | Đường dẫn SDK trên máy — **bị `.gitignore`**, mỗi máy tự sinh. |

## Luồng build

```text
flutter build apk --release            (từ frontend/)
   ├── đọc pubspec.yaml (asset, dependency)
   ├── biên dịch lib/main.dart → Dart AOT
   ├── Gradle: AndroidManifest + res + MainActivity → APK
   └── build/app/outputs/flutter-apk/app-release.apk
```

Chạy trên máy thật không dây: `adb reverse tcp:3000 tcp:3000` (backend ở `localhost:3000`) hoặc nhập IP LAN trong app.

## Ghi chú

- **Icon/tên app:** sửa `res/mipmap-*/ic_launcher.png` và `android:label`.
- **Quyền mới:** khai báo trong `AndroidManifest.xml`, đồng thời xin quyền runtime trong code nếu là quyền nguy hiểm.
- **Ký release:** tạo keystore, cấu hình `signingConfigs` trong `app/build.gradle.kts` và **không commit** file keystore/mật khẩu.
- Thư mục `.gradle/`, `.kotlin/`, `build/`, `local.properties`, `generated_plugin_registrant.*` là sinh tự động — không sửa, không commit.
