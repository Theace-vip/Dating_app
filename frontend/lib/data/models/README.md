# `frontend/lib/data/models/` — model dữ liệu

**Vai trò:** định nghĩa hình dạng dữ liệu trao đổi với backend và hàm `fromJson`. Mọi tầng khác dùng chung các class này.
**Ai gọi tới:** `data/api/`, `data/repositories/`, mọi màn hình trong `features/`, test.
**Gọi đi:** không — đây là tầng thuần dữ liệu (chỉ import `dart:core`).

## File trong thư mục

| File | Nội dung |
|---|---|
| `models.dart` | Toàn bộ model trong một file, chia theo nhóm nghiệp vụ. |

## Danh sách class / enum

| Tên | Ý nghĩa | Trường chính |
|---|---|---|
| `Gender` | Giới tính | `male`, `female`, `other` |
| `MessageType` | Loại tin nhắn | `text`, `image`, `voice`, `emoji` |
| `UserModel` | Người dùng | `id`, `email`, `name`, `avatar`, `gender`, `age`, `bio`, `tags`, `photos`, `coins`, `diamonds`, `isVip`, `profileCompleted`, `createdAt` |
| `MessageModel` | Tin nhắn 1-1 | `id`, `conversationId`, `senderId`, `content`, `type`, `createdAt`, `isRead` |
| `ConversationModel` | Hội thoại | `id`, `partnerId/Name/Avatar`, `lastMessage`, `lastMessageAt`, `unreadCount`, `isOnline`, `copyWithLast()`, `copyWithUnread()`, `copyWithOnline()` |
| `OriginalPostModel` | Bản ghi bài gốc trong bài repost | thông tin tác giả + nội dung + media gốc |
| `PostModel` | Bài feed | `id`, `userId`, `userName`, `userAvatar`, `content`, `media`, `likes`, `comments`, `shares`, `likedByMe`, `createdAt`, `originalPost`, `copyWith()` |
| `RoomModel` | Phòng tiệc | `id`, `name`, `hostId`, `hostName`, `topic`, `backgroundEmoji`, `memberCount`, `memberAvatars`, `copyWithMembers()` |
| `CommentModel` | Bình luận | `id`, `postId`, `userId`, `userName`, `userAvatar`, `content`, `createdAt` |
| `RoomMessageModel` | Tin nhắn phòng | `id`, `roomId`, `senderId/Name/Avatar`, `content`, `createdAt` |

## Luồng dữ liệu

```text
backend/src/routes.js  (JSON)
   └── ApiClient.get(...)                     → Map<String, dynamic>
         └── Model.fromJson(map)              → object có kiểu
               └── repository state           → ref.watch ở UI
socket payload (Map)
   └── Model.fromJson(...)                    → cùng class, cùng cách parse
```

## Quy ước

1. Mọi class có `factory X.fromJson(Map<String, dynamic> json)`; trường thiếu phải có giá trị mặc định, không `!` bừa.
2. Số từ JSON dùng `(x as num?)?.toInt()` để chịu được `int` hoặc `double`.
3. Thời gian dùng `DateTime.tryParse()` và fallback `DateTime.now()`.
4. Model bất biến (`final`); muốn cập nhật thì tạo bản mới qua `copyWith`.
5. Thêm model mới: đặt trong `models.dart` nếu nhỏ, tách file riêng nếu lớn, và thêm vào bảng trên.
