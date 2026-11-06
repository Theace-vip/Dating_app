# `frontend/lib/features/home/` — khung ứng dụng và tab Khám phá

**Vai trò:** `HomePage` là "vỏ" sau khi đăng nhập: 5 tab + banner mạng; `ExplorePage` là tab khám phá, nơi vào Soul Game / Voice Game.
**Ai gọi tới:** `app/router.dart` (route `/`).
**Gọi đi:** mọi màn hình chính (`ChatListPage`, `FeedPage`, `RoomListPage`, `ProfilePage`), `features/matching/*`, `data/repositories/*` (tải dữ liệu nền), `core/network/connectivity_service.dart` (`NetworkBanner`), `data/repositories/catalog_repository.dart` (thẻ game).

## File trong thư mục

| File | Nội dung |
|---|---|
| `home_page.dart` | `HomePage` + `_HomePageState`: `IndexedStack` 5 tab — **Tin nhắn**, **Khám phá mới**, **Bảng tin**, **Phòng trò chuyện**, **Trang cá nhân**; `NavigationBar` có badge tin chưa đọc; `NetworkBanner` khi mất mạng. `ExplorePage` + `_GameCard`: hai thẻ vào Soul Game (chat ẩn danh) và Voice Game (thoại ẩn danh), thời lượng lấy từ `appCatalogProvider`. |

## Dữ liệu tải khi mở HomePage

```text
home_page.dart: initState()
   ├── chatProvider.notifier.load()      → GET /api/conversations
   ├── feedProvider.notifier.load()      → GET /api/feed
   ├── roomsProvider.notifier.load()     → GET /api/rooms
   ├── ref.read(feedRealtimeProvider)    → đăng ký feed:*, feed:comment:*
   └── ref.read(socialRealtimeProvider)  → tải bạn bè + nghe friends:changed
```

Chỉ tải một lần khi vào trang; sau đó mọi thay đổi đến qua socket (nút làm mới chỉ là dự phòng).

## Điều hướng trong trang

```text
NavigationBar (index)
   ├── 0 → ChatListPage        features/chat/chat_list_page.dart
   ├── 1 → ExplorePage         (trong file này) ─► SoulGamePage / VoiceGamePage
   ├── 2 → FeedPage            features/feed/feed_page.dart
   ├── 3 → RoomListPage        features/room/room_list_page.dart
   └── 4 → ProfilePage         features/profile/profile_page.dart
```

## Ghi chú

- Dùng `IndexedStack` để giữ state từng tab (không tải lại khi chuyển tab).
- Badge tin chưa đọc lấy tổng `unreadCount` từ `chatProvider`.
- Banner mạng đặt trong `Scaffold` của HomePage nên hiện trên mọi tab.
- Không đặt logic nghiệp vụ ở đây: chỉ tải dữ liệu nền và bố cục.
