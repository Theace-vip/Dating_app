# `frontend/lib/features/feed/` — bảng tin, đăng bài, bình luận

**Vai trò:** 2 màn hình của tab "Bảng tin": danh sách bài viết (kèm like, bình luận, chia sẻ, sửa/xoá) và trang soạn bài mới.
**Ai gọi tới:** `features/home/home_page.dart` (tab 2), `features/feed/feed_page.dart` mở `CreatePostPage`, `features/profile/profile_page.dart` dùng lại cách render bài (`_FbPostCard` riêng của trang cá nhân).
**Gọi đi:** `data/repositories/chat_repository.dart` (`feedProvider`, `commentsProvider`, `FeedNotifier`, `CommentsNotifier`), `data/repositories/auth_repository.dart` (`currentUserProvider`), `shared/image_tools.dart`, `data/api/socket_client.dart`.

## File trong thư mục

| File | Nội dung chính |
|---|---|
| `feed_page.dart` | `FeedPage` + `_PostCard` (thẻ bài: tác giả, nội dung, media, like/comment/share, menu sửa/xoá), `CommentsSheet` + `_CommentsSheetState` (bottom sheet bình luận: tải, gửi, sửa, xoá, realtime, né bàn phím), `_OriginalPostCard` (bài gốc của repost), `_Action` (nút hành động). Cuộn gần cuối → `FeedNotifier.loadMore()`. |
| `create_post_page.dart` | Soạn bài: nội dung + tối đa 3 ảnh (chọn → nén → upload lấy URL), gọi `FeedNotifier.addPost()`; hiển thị lỗi từ `ApiException`. |

## Luồng hoạt động

### Tải và phân trang

```text
home_page.dart → feedProvider.notifier.load()          data/repositories/chat_repository.dart
   └── GET /api/feed                                    backend/src/routes.js: router.get('/feed')
         └── SQL posts + post_likes + comments + likedByMe   (backend/src/db.js)
   └── FeedNotifier.state = List<PostModel>
feed_page.dart: build() → ref.watch(feedProvider) → ListView.builder → _PostCard
cuộn gần cuối → FeedNotifier.loadMore()  → GET /api/feed?before=<bài cuối>&limit=30
```

### Like

```text
_PostCard → FeedNotifier.toggleLike(post.id)
   ├── optimistic: đảo likedByMe, +1/-1 likes
   ├── POST /api/feed/:id/like        → toggle bảng post_likes → trả likes, likedByMe
   ├── phát feed:stats                → các client khác cập nhật số
   └── lỗi mạng → rollback về state trước
```

### Bình luận

```text
_PostCard → _showComments() → showModalBottomSheet(CommentsSheet)
   └── CommentsSheet.initState() → commentsProvider(postId).notifier.load()
         └── GET /api/feed/:id/comments  → CommentsNotifier.load() (_mergeLoaded giữ comment realtime)
gửi: _submit() → CommentsNotifier.add(text)
   └── POST /api/feed/:id/comments → INSERT comments
         ├── feed:stats            (số bình luận trên thẻ bài)
         └── feed:comment:new      (nội dung + tác giả)
               └── feedRealtimeProvider → CommentsNotifier.applyAdded()   (khử trùng theo id)
```

Sửa/xoá: `PATCH/DELETE /api/feed/:id/comments/:cid` → `feed:comment:updated` / `feed:comment:deleted`.

### Chia sẻ / repost / sửa / xoá bài

| Thao tác | Code | Server |
|---|---|---|
| Chia sẻ ra ngoài | `_showShareOptions()` → `share_plus` → chỉ khi thành công mới `FeedNotifier.sharePost(confirmed: true)` | `POST /api/feed/:id/share` tăng `shares_count` |
| Đăng lại (repost) | `sharePost(createRepost: true, repostContent: ...)` | Tạo post mới + snapshot bài gốc trong `media`, phát `feed:new` |
| Sửa bài | dialog → `PATCH /api/feed/:id` | `feed:updated` → `FeedNotifier.updatePost()` |
| Xoá bài | dialog xác nhận → `DELETE /api/feed/:id` | `feed:deleted` → `FeedNotifier.removePost()` |

## Ghi chú

- `feedRealtimeProvider` được đăng ký **một lần** ở `HomePage`; màn hình chỉ `ref.watch(feedProvider)`.
- Sheet bình luận đọc `MediaQuery.viewInsets.bottom` bên trong chính nó để né bàn phím (builder ngoài chỉ chạy lúc mở sheet).
- Bài của chính mình ở trang Cá nhân dùng `myPostsProvider` (tải `GET /api/feed?userId=`), không dựa vào phần đã tải trong feed chung.
- Tài liệu chức năng: [`frontend/docs/06_feed.md`](../../../docs/06_feed.md).
