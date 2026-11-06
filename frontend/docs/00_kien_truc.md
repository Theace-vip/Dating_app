# 00 — Kiến trúc & luồng dữ liệu

## Mục đích
Giải thích cách frontend tổ chức code, dữ liệu đi từ server tới UI theo đường nào,
và vì sao mọi chức năng đều cập nhật realtime.

## Các lớp

```text
UI (features/*_page.dart)
        │ watch / read
        ▼
Provider (data/repositories/*)
        │ gọi hàm
        ▼
ApiClient (REST, dio)   SocketService (Socket.IO)
        │                        │
        └──────────► backend ◄───┘
```

1. **UI** chỉ đọc state từ provider và gọi method của notifier; không tự gọi HTTP
   trong `build`.
2. **Repository/Notifier** giữ state, gọi API, và áp dụng dữ liệu realtime.
3. **ApiClient** gắn Bearer token, tự refresh khi gặp 401 (single-flight), dịch lỗi
   sang tiếng Việt (`ApiException.message`).
4. **SocketService** giữ một kết nối duy nhất; mỗi sự kiện có một
   `StreamController.broadcast` riêng nên nhiều widget cùng nghe được.

## Provider quan trọng

| Provider | Nội dung | Nguồn |
|---|---|---|
| `authProvider` | `AuthState` (restoring/authenticated/unauthenticated + user) | `/api/me`, login |
| `currentUserProvider` | `UserModel` của chính mình | dẫn xuất từ `authProvider` |
| `chatProvider` | danh sách hội thoại | `/api/conversations` |
| `messagesProvider(id)` | tin nhắn của một hội thoại (autoDispose) | `/api/conversations/:id/messages` |
| `feedProvider` | bài viết toàn hệ thống | `/api/feed` |
| `commentsProvider(postId)` | bình luận của một bài (autoDispose) | `/api/feed/:id/comments` |
| `roomsProvider` | phòng tiệc | `/api/rooms` |
| `friendsProvider` | bạn bè | `/api/friends` |
| `catalogRepositoryProvider` | avatar, sở thích, quà, gói Xu, VIP | `/api/catalog…` |
| `socketProvider` | `SocketService` | — |

## Vòng đời kết nối
`main.dart` → `_MyAppState.build` dùng `ref.listen(authProvider)`:

- đăng nhập thành công → `socket.connect()`
- đăng xuất → `socket.disconnect()` và **invalidate** `chatProvider`,
  `feedProvider`, `roomsProvider`, `friendsProvider` để tài khoản kế tiếp không
  thấy dữ liệu của người trước.
- mạng trở lại (`connectivityProvider`) → kết nối lại socket + gửi bù outbox.

## Realtime
Ba kiểu áp dụng dữ liệu realtime:

1. **Thay thế toàn bộ** (dữ liệu nhỏ, ít thay đổi): `friends.load()`,
   `rooms.load()` khi nhận `friends:changed` / `rooms:changed`.
2. **Áp dụng từng bản ghi**: `feedProvider.applyRealtime(post)`,
   `commentsProvider.applyAdded(comment)`, `chatProvider.applyIncoming(...)`.
3. **Chỉ áp dụng số đếm**: `feedProvider.applyStats(postId, likes:)`.

Danh sách sự kiện đầy đủ: [10_su_kien_realtime.md](10_su_kien_realtime.md).

## Quy ước viết code
- Không hard-code dữ liệu nghiệp vụ (giá, danh mục, thời lượng) — tải từ catalog.
- Không tạo dữ liệu mẫu trong DB hay trong app.
- Mọi lời gọi API có thể lỗi đều bắt `ApiException` và hiển thị `e.message`.
- Trước thao tác ghi, gọi `ensureOnline(context, ref)` để chặn khi mất mạng.
- Dùng `mounted` trước `setState` sau `await`.
