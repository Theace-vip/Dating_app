# `frontend/lib/features/` — màn hình theo nghiệp vụ

**Vai trò:** chứa toàn bộ giao diện người dùng, mỗi thư mục con là một nhóm chức năng. Màn hình chỉ đọc state qua provider và gọi hành động qua notifier.
**Ai gọi tới:** `app/router.dart` (splash, login, profile-setup, home), `main.dart` (mở `CallPage` khi có cuộc gọi đến), các màn hình gọi nhau bằng `Navigator.push`.
**Gọi đi:** `data/repositories/` (state), `data/api/socket_client.dart` (chỉ để `emit`), `shared/widgets/`, `core/theme/`.

## Thư mục con

| Thư mục | Chức năng | README |
|---|---|---|
| `auth/` | Splash, đăng nhập/đăng ký, thiết lập hồ sơ lần đầu | [`auth/README.md`](auth/README.md) |
| `home/` | Khung 5 tab + tab Khám phá (vào Soul Game / Voice Game) | [`home/README.md`](home/README.md) |
| `chat/` | Danh sách hội thoại, chat 1-1, bạn bè, tìm người | [`chat/README.md`](chat/README.md) |
| `feed/` | Bảng tin, đăng bài, bình luận | [`feed/README.md`](feed/README.md) |
| `matching/` | Soul Game (text) và Voice Game (thoại ẩn danh) | [`matching/README.md`](matching/README.md) |
| `room/` | Danh sách phòng, phòng tiệc, quà SVGA | [`room/README.md`](room/README.md) |
| `call/` | Gọi thoại/video WebRTC | [`call/README.md`](call/README.md) |
| `profile/` | Trang cá nhân, chỉnh sửa, ví, VIP, chẩn đoán mạng | [`profile/README.md`](profile/README.md) |

## Sơ đồ màn hình

```text
/splash (auth) ──► /login (auth) ──► /profile-setup (auth) ──► / (home)
                                                                  │
   ┌──────────────┬─────────────────┬──────────────┬─────────────┴────────────┐
   ▼              ▼                 ▼              ▼                          ▼
chat/          home: Explore     feed/          room/                     profile/
ChatListPage   ─► SoulGamePage   FeedPage       RoomListPage              ProfilePage
   │            ─► VoiceGamePage    │           └► RoomDetailPage           ├► EditProfilePage
   ├► ChatDetailPage ───────────────┼───────────────────────────────────────┤► WalletPage / VipPage
   │     └► CallPage               └► CreatePostPage                        ├► NetworkDemoPage
   ├► FriendsPage                                                           └► (Đăng xuất)
   └► SearchUsersPage ─► PublicProfilePage ─► ChatDetailPage / CallPage
```

## Quy ước chung

1. Widget cần state → `ConsumerWidget` / `ConsumerStatefulWidget`; đọc bằng `ref.watch`, hành động bằng `ref.read(...notifier)`.
2. Trước mọi thao tác ghi dữ liệu gọi `ensureOnline(context, ref)` (`core/network/connectivity_service.dart`).
3. Hủy `StreamSubscription`, `Timer`, `TextEditingController` trong `dispose()`.
4. Màu/khoảng cách dùng `AppColors`, `AppSpacing`; không hard-code màu.
5. Trạng thái rỗng phải hiển thị `EmptyState` — app không có dữ liệu mẫu.
6. Mỗi file có comment đầu file mô tả mục đích + luồng chính; giữ comment đó khi sửa.
