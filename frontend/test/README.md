# `frontend/test/` — unit test và widget test

**Vai trò:** kiểm thử chạy trên máy, không cần thiết bị và **không cần backend**. Tập trung vào parse JSON của model và trạng thái khởi tạo của auth.
**Chạy:** `cd frontend && flutter test` (hiện 8 test, tất cả pass).

## File trong thư mục

| File | Nội dung |
|---|---|
| `widget_test.dart` | Các nhóm test: `UserModel.fromJson` (đủ trường / thiếu trường), `PostModel` có bài gốc (repost), `ConversationModel`, `MessageModel`, `AuthState` (mặc định và sau đăng nhập). |

## Những gì được kiểm tra

| Nhóm | Mục đích |
|---|---|
| `UserModel.fromJson` | Dữ liệu server thiếu trường vẫn parse được, không ném exception |
| `PostModel` (repost) | `originalPost` được đọc đúng từ snapshot JSON trong `media` |
| `ConversationModel` | `copyWithLast`, `copyWithUnread`, `copyWithOnline` cập nhật đúng trường |
| `MessageModel` | Parse `type` (text/image), `createdAt`, `isRead` |
| `AuthState` | Trạng thái ban đầu `unauthenticated`/`restoring`; state sau đăng nhập có `user` |

## Khi viết test mới

1. Không gọi mạng thật: dùng `Map<String, dynamic>` mẫu thay vì `ApiClient` (nếu cần HTTP, dùng `MockDio`/`DioAdapter`).
2. Đặt tên test theo hành vi: `test('thiếu trường tags vẫn parse được', ...)`.
3. Test thuần logic (repository, model) đặt ở đây; test cần thiết bị thật đặt ở `integration_test/`.
4. Chạy `flutter analyze` trước khi commit để không lọt cảnh báo vào test.
