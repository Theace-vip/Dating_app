# `frontend/lib/core/` — nền tảng dùng chung

**Vai trò:** những thứ mọi màn hình đều cần nhưng không thuộc nghiệp vụ: hằng số cấu hình, theme, xử lý mạng, hàng đợi offline, ghim chứng chỉ TLS.
**Ai gọi tới:** gần như toàn bộ `features/`, `data/` và `main.dart`.
**Gọi đi:** `data/api/api_client.dart` (outbox dùng để gửi lại tin), không có phụ thuộc ngược vào UI của `features/`.

## Thư mục con

| Thư mục | Nội dung | README |
|---|---|---|
| `constants/` | `AppConfig` (địa chỉ server, URL API/socket, ICE servers, cert pin), `AppSpacing`/`AppTextStyle` | [`constants/README.md`](constants/README.md) |
| `network/` | `connectivityProvider`, `ensureOnline()`, `NetworkBanner`, `Outbox`, certificate pinning | [`network/README.md`](network/README.md) |
| `theme/` | `AppColors`, `AppTheme.light` | [`theme/README.md`](theme/README.md) |

## Nguyên tắc

1. **Một nguồn sự thật cho cấu hình:** địa chỉ server chỉ đổi qua `AppConfig.applyServerHost()`; không hard-code URL ở màn hình.
2. **Không nghiệp vụ ở đây:** giá quà, danh mục avatar, thời lượng game nằm ở backend (`backend/src/catalog.js`) và được tải qua `data/repositories/catalog_repository.dart`. `core/` chỉ giữ thứ thuần kỹ thuật/giao diện.
3. **Chặn thao tác khi offline:** mọi hành động ghi dữ liệu gọi `ensureOnline(context, ref)` trước; riêng chat còn có outbox để gửi bù.
4. **Bảo mật mặc định:** pinning được cài một lần trong `main()` trước `runApp`, áp dụng cho cả HTTP và WebSocket.

## Luồng mất mạng (tóm tắt)

```text
connectivity_plus đổi trạng thái
   └── main.dart: ref.listen(connectivityProvider)
         ├── socket.connect()                       (kết nối lại realtime)
         └── outboxProvider.flush()                 (gửi tin đang chờ)
               └── data/api/api_client.dart → POST /api/conversations/:id/messages
```

Chi tiết file: [`network/README.md`](network/README.md).
