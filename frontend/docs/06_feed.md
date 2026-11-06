# 06 — Feed: bài viết, like, bình luận, chia sẻ

## Mục đích
Bảng tin cộng đồng: đăng bài kèm ảnh, like, bình luận (thêm/sửa/xoá), chia sẻ ra
ngoài hoặc đăng lại, phân trang. Mọi thay đổi được phát realtime.

## File chính
| File | Vai trò |
|---|---|
| `features/feed/feed_page.dart` | danh sách bài + `CommentsSheet` (dùng chung với trang cá nhân) |
| `features/feed/create_post_page.dart` | soạn bài, chọn ảnh |
| `data/repositories/chat_repository.dart` | `FeedNotifier`, `CommentsNotifier` |
| `features/profile/profile_page.dart` | hiển thị bài của chính mình (cùng widget thẻ bài) |

## State
- `feedProvider` — danh sách `PostModel`; có `load()`, `toggleLike()`,
  `addPost()`, `sharePost()`, `applyRealtime()`, `applyStats()`, `removePost()`.
- `commentsProvider(postId)` — `AsyncValue<List<CommentModel>>`, autoDispose theo
  bottom sheet.

## Luồng realtime
| Sự kiện | Xử lý |
|---|---|
| `feed:new` | chèn bài mới lên đầu (cả người đăng lẫn người khác) |
| `feed:updated` | thay nội dung bài đã sửa (giữ `likedByMe` của mình) |
| `feed:deleted` | xoá khỏi danh sách |
| `feed:stats` | cập nhật likes / comments / shares |
| `feed:comment:new` | thêm bình luận vào sheet đang mở |
| `feed:comment:updated` / `:deleted` | sửa / xoá bình luận |

`feedRealtimeProvider` được kích hoạt một lần ở `HomePage` nên mọi tab đều nhận
dữ liệu mới.

## Like & chia sẻ
- **Like**: optimistic (`likedByMe`, `likes ± 1`) → `POST /api/feed/:id/like` →
  đối chiếu số từ server; lỗi thì hoàn tác.
- **Chia sẻ**: mở `SharePlus` của hệ điều hành; chỉ khi kết quả
  `ShareResultStatus.success` mới gọi `POST /api/feed/:id/share {confirmed:true}`
  để tăng bộ đếm.
- **Đăng lại**: `POST /api/feed/:id/share {repostContent}` → server tạo bài mới
  tham chiếu bài gốc và phát `feed:new`.

## Phân trang
`GET /api/feed?limit=…&before=<ISO createdAt>`, trả `hasMore`; cuộn xuống cuối
danh sách thì tải trang tiếp.

## Ghi chú
- Bài viết/bình luận **không được seed**: nội dung chỉ đến từ người dùng thật.
- Nội dung bài tối đa 2000 ký tự, bình luận 500 ký tự (server cắt).
- Xoá/sửa chỉ cho tác giả; UI kiểm tra `isMine` trước khi hiện menu.
