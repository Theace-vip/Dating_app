# `backend/scripts/` — công cụ, kiểm thử và bảo trì

**Vai trò:** các script chạy độc lập bằng `node scripts/<tên>.js`, không nằm trong luồng phục vụ request.
Dùng khi cài đặt máy mới, kiểm tra sau khi sửa code, sao lưu hoặc dọn dữ liệu thử.
**Ai gọi tới:** con người (terminal), `cai_dat.bat`, `sao_luu.bat`, và `backend/src/index.js` (import `ensureCert`).

## File trong thư mục

| File | Cách chạy | Kiểm tra / làm gì |
|---|---|---|
| `gen-cert.js` | `npm run gen-cert` hoặc tự chạy khi server khởi động | Sinh chứng chỉ HTTPS tự ký vào `certs/` nếu chưa có, in **SHA-256 pin** để dán vào `AppConfig.certPinningSha256`. Export `ensureCert()` cho `src/index.js`. |
| `backup_db.js` | `node scripts/backup_db.js` (hoặc `sao_luu.bat`) | Snapshot SQLite bằng `VACUUM INTO` (an toàn khi server đang chạy) vào `backups/soulmate-<ngày-giờ>.db`, giữ 14 bản gần nhất. |
| `cleanup_demo_content.js` | `node scripts/cleanup_demo_content.js` | Xoá nội dung mẫu cũ (bài viết, bình luận, phòng, tin nhắn) để app chỉ còn dữ liệu thật; giữ 2 tài khoản demo. |
| `e2e_test.js` | `node scripts/e2e_test.js` | Smoke test REST cơ bản: health, đăng ký/đăng nhập/refresh, hồ sơ, feed, bình luận, chia sẻ, hội thoại, phòng, vài kiểm tra bảo mật. |
| `e2e_test2.js` | `node scripts/e2e_test2.js` | Smoke test mở rộng: upload ảnh, tìm kiếm, đổi mật khẩu, tạo phòng, sửa/xoá bài & bình luận, phân trang tin nhắn, ảnh trong chat, Soul Game + `chat:typing`. |
| `socket_test.js` | `node scripts/socket_test.js` | Test realtime: xác thực socket, Soul Game (queue, timer, reveal), room presence/chat/gift, call signaling, heart, mic trong phòng. |
| `realtime_feed_test.js` | `node scripts/realtime_feed_test.js` | Test riêng các event feed: `feed:new/updated/deleted/stats`, `feed:comment:new`. |

## Trước khi chạy

- Server phải đang chạy (`npm start`), mặc định `https://localhost:3000`; các script dùng `socket.io-client` (devDependency) và `NODE_TLS_REJECT_UNAUTHORIZED=0` cho cert tự ký.
- Script tạo tài khoản/bài viết thử trong database thật → chạy xong nên kiểm tra lại feed/phòng nếu không muốn dữ liệu test.
- `backup_db.js` không cần server chạy, nhưng cần có `data/soulmate.db`.

## Liên quan đến code nào

```text
gen-cert.js      → certs/server.key + server.crt → src/index.js (https.createServer)
                 → in pin → frontend/lib/core/constants/app_config.dart (certPinningSha256)
backup_db.js     → backend/data/soulmate.db  → backend/backups/
e2e_test*.js     → gọi API của src/routes.js, src/auth.js (đi đúng đường như app)
socket_test.js   → gọi event của src/socket.js
cleanup_demo_content.js → xoá dữ liệu trong src/db.js (bảng posts, comments, rooms, messages)
```

## Khi thêm script mới

1. Đặt ở đây, chạy trực tiếp bằng `node`, không import từ `src/index.js` (tránh khởi động server ngoài ý muốn).
2. Nếu script cần đường dẫn dữ liệu, dùng `serverRoot` từ `../src/config.js` thay vì hard-code ổ đĩa.
3. Ghi mục đích + cách chạy ở đầu file và thêm vào bảng trên.
