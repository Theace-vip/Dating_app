# `backend/` — máy chủ SoulMate (Node.js)

**Vai trò:** toàn bộ API REST, kênh realtime Socket.IO, database SQLite và dữ liệu ảnh upload.
App Flutter **không** đọc database trực tiếp: mọi thứ đi qua thư mục này.
**Ai gọi tới:** `frontend/lib/data/api/api_client.dart` (REST) và `frontend/lib/data/api/socket_client.dart` (WebSocket).
**Được gọi từ đâu khi chạy:** `backend/src/index.js` (entrypoint) — xem [`src/README.md`](src/README.md).

## Chạy

```bash
cd backend
npm install          # lần đầu
npm start            # = node src/index.js  → https://localhost:3000
```

Hoặc từ thư mục gốc: `cai_dat.bat` (cài đặt), `ket_noi_internet.bat` (server + tunnel), `sao_luu.bat` (backup).

## File ở thư mục này

| File | Dùng để làm gì |
|---|---|
| `package.json` | Khai báo dependency (express, socket.io, jsonwebtoken, helmet, cors, express-rate-limit, selfsigned) và script `start`, `gen-cert`. Yêu cầu Node ≥ 22.5 vì dùng `node:sqlite`. |
| `package-lock.json` | Khóa phiên bản dependency; commit để cài lại giống nhau. |
| `config.example.json` | Mẫu cấu hình (`port`, `accessTokenTtlSec`, `refreshTokenTtlSec`) — không chứa secret. |
| `config.json` | Cấu hình thật + `jwtSecret`; **bị `.gitignore`**, server tự sinh nếu thiếu. |
| `tunnel.bat` | Chạy Cloudflare Tunnel trỏ vào server local để lấy URL công khai. |
| `cloudflared.exe` | Binary tunnel; **không commit** (dung lượng lớn, tải lại tự động). |

## Thư mục con và thư mục dữ liệu

| Đường dẫn | Vai trò | Commit? |
|---|---|---|
| `src/` | Mã nguồn server — xem [`src/README.md`](src/README.md) | Có |
| `scripts/` | Sinh cert, backup, kiểm thử end-to-end — xem [`scripts/README.md`](scripts/README.md) | Có |
| `data/` | `soulmate.db` + file WAL/SHM. **Toàn bộ dữ liệu thật nằm ở đây.** | Không |
| `uploads/` | Ảnh người dùng upload, phục vụ tĩnh tại `/uploads/...` (khai báo trong `src/index.js`). | Không |
| `certs/` | `server.key` + `server.crt` cho HTTPS, sinh bởi `scripts/gen-cert.js`. | Không |
| `backups/` | Snapshot database do `scripts/backup_db.js` tạo (giữ 14 bản gần nhất). | Không |
| `node_modules/` | Dependency, cài bằng `npm install`. | Không |

> Vì `data/`, `uploads/`, `certs/`, `backups/` bị `.gitignore`, tài liệu của chúng được gộp vào chính file này thay vì đặt `README.md` bên trong (sẽ không được commit).

## Luồng hoạt động (tóm tắt)

```text
HTTP  → src/index.js (helmet, cors, rate limit)
        → /api/auth/*            src/auth.js        (đăng ký, đăng nhập, refresh, logout)
        → /api/*  (cần token)    src/routes.js      (hồ sơ, bạn bè, chat, feed, phòng, upload)
                                   └── src/db.js    (SQLite: đọc/ghi)
                                   └── src/security.js (hash, JWT)
                                   └── src/catalog.js  (giá quà, gói Xu, thời lượng game)
                                   └── emitToUser / emitFeedSafe → src/socket.js
WebSocket → src/socket.js (xác thực token khi handshake)
        → presence, soul game, call, room chat/gift/mic, chat:typing
        → emit ngược lại room `user:<id>` / `room:<id>`
```

- Dữ liệu bền vững (tài khoản, hồ sơ, bài viết, tin nhắn, phòng) đi qua REST.
- Sự kiện tức thời (tin mới, đang gõ, presence, ghép đôi, cuộc gọi, quà) đi qua Socket.IO.
- Server là nơi quyết định **quyền, thời gian và giá** — client chỉ gửi ý định.

Chi tiết từng bước `file → file`: [`docs/LUONG_CODE_THEO_FILE.md`](../docs/LUONG_CODE_THEO_FILE.md).

## Bảng tra nhanh

| Cần sửa | Vào file |
|---|---|
| Đổi cổng, thời hạn token | `src/config.js` / `config.json` |
| Thêm API mới | `src/routes.js` (rồi client: `api_client.dart` → repository) |
| Thêm sự kiện realtime | `src/socket.js` + `frontend/lib/data/api/socket_client.dart` |
| Thêm bảng/cột database | `src/db.js` (lưu ý: chưa có migration cho DB cũ) |
| Giá quà, gói Xu, thời lượng game | `src/catalog.js` |
| Luật bảo mật, hash, JWT | `src/security.js`, `src/auth.js` |
| Quy tắc validate hồ sơ | `src/routes.js: validateProfileOptions` |

## Khi thêm file mới

1. Route nghiệp vụ → thêm vào `src/routes.js` theo đúng nhóm (catalog / hồ sơ / hội thoại / feed / phòng).
2. Sự kiện realtime → thêm handler trong `src/socket.js`, đặt cạnh nhóm tương ứng.
3. Helper dùng chung (user, hội thoại, bạn bè) → `src/db.js`, không lặp SQL rải rác.
4. Script kiểm thử/tiện ích → `scripts/`, chạy độc lập bằng `node scripts/<tên>.js`.
