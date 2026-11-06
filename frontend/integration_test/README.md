# `frontend/integration_test/` — kiểm thử tích hợp trên thiết bị

**Vai trò:** chạy app thật trên máy ảo/điện thoại thật, bấm theo luồng người dùng và chụp ảnh màn hình để kiểm tra giao diện.
**Chạy:** `cd frontend && flutter test integration_test/app_test.dart -d <device-id>` (cần backend đang chạy và thiết bị đã kết nối).

## File trong thư mục

| File | Nội dung |
|---|---|
| `app_test.dart` | Kịch bản: khởi động app, đăng nhập, đi qua các tab/màn hình chính, chụp ảnh từng bước bằng `adb exec-out screencap`. Có helper `_shot(name)` và `_tapByText(tester, text)`. |

## Trước khi chạy trên máy của bạn

File đang **hard-code** thông tin máy tác giả — phải sửa 3 hằng số ở đầu file:

| Hằng số | Ý nghĩa | Sửa thành |
|---|---|---|
| `_outDir` | Thư mục lưu ảnh chụp | thư mục bất kỳ trên máy bạn |
| `_adb` | Đường dẫn `adb.exe` | đường dẫn Android SDK trên máy bạn |
| `_device` | Serial thiết bị | kết quả `adb devices` |

## Luồng kiểm thử

```text
IntegrationTestWidgetsFlutterBinding.ensureInitialized()
   └── app.main() → pumpAndSettle
         ├── đăng nhập (demo1@soulmate.app / Demo@1234)
         ├── _tapByText(...) từng tab: Tin nhắn / Khám phá / Bảng tin / Phòng / Cá nhân
         ├── mở chat, gửi tin, mở phòng, xem ví…
         └── _shot('01_login') … → ảnh PNG trong _outDir
```

## Ghi chú

- Test này phụ thuộc dữ liệu thật trong database (bài viết, hội thoại, phòng) → kết quả có thể khác nhau giữa các máy.
- Không chạy trong CI vì cần thiết bị và backend; dùng `flutter test` (thư mục `test/`) cho kiểm thử nhanh.
- Ảnh chụp chỉ để xem lại giao diện, không phải artifact commit.
