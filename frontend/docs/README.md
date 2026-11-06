# `frontend/docs/` — tài liệu chức năng phía client

**Vai trò:** mỗi chức năng của app có một tệp riêng, mô tả mục đích, file liên quan, luồng chạy và các sự kiện realtime.
**Ai đọc:** người phát triển cần hiểu/sửa một chức năng cụ thể. Tài liệu theo **thư mục** nằm ngay trong thư mục (`frontend/lib/.../README.md`); luồng code chi tiết `file → file` ở [`../../docs/LUONG_CODE_THEO_FILE.md`](../../docs/LUONG_CODE_THEO_FILE.md).

## Danh sách tài liệu

| # | Tệp | Nội dung |
|---|---|---|
| 0 | [`00_kien_truc.md`](00_kien_truc.md) | Kiến trúc tổng thể, 3 lớp UI → state → vận chuyển, luồng dữ liệu, quy ước provider |
| 1 | [`01_xac_thuc.md`](01_xac_thuc.md) | Đăng ký/đăng nhập, refresh token, khôi phục phiên, đăng xuất, đổi mật khẩu |
| 2 | [`02_ho_so_ca_nhan.md`](02_ho_so_ca_nhan.md) | Trang cá nhân, chỉnh sửa hồ sơ, hồ sơ người khác, bạn bè, tìm kiếm |
| 3 | [`03_chat_1_1.md`](03_chat_1_1.md) | Chat 1-1: gửi/nhận, optimistic, outbox, typing, đã đọc, phân trang, sửa/xoá |
| 4 | [`04_soul_game.md`](04_soul_game.md) | Soul Game và Voice Game: hàng đợi, phiên, nút tim, reveal, gia hạn, WebRTC |
| 5 | [`05_phong_tiec_qua_tang.md`](05_phong_tiec_qua_tang.md) | Phòng tiệc: tạo/vào phòng, chat, thả tim, tặng quà trừ Xu, mic mesh |
| 6 | [`06_feed.md`](06_feed.md) | Bảng tin: đăng bài, like, bình luận, chia sẻ/repost, phân trang, realtime |
| 7 | [`07_goi_dien.md`](07_goi_dien.md) | Gọi thoại/video: đổ chuông, accept/reject, SDP/ICE, kết thúc, xử lý mất mạng |
| 8 | [`08_mang_offline_bao_mat.md`](08_mang_offline_bao_mat.md) | connectivity, outbox, certificate pinning, đổi server, tunnel |
| 9 | [`09_catalog_vi_vip.md`](09_catalog_vi_vip.md) | Catalog server, ví Xu/Kim cương, gói nạp, VIP |
| 10 | [`10_su_kien_realtime.md`](10_su_kien_realtime.md) | Bảng toàn bộ sự kiện Socket.IO: server phát gì, client xử lý ở đâu |

## Cách đọc

1. Muốn hiểu tổng thể → `00_kien_truc.md`.
2. Muốn sửa một chức năng → tệp tương ứng + `README.md` của thư mục chứa màn hình đó.
3. Muốn biết "code chạy từ file nào tới file nào" → [`../../docs/LUONG_CODE_THEO_FILE.md`](../../docs/LUONG_CODE_THEO_FILE.md).
4. Muốn biết sự kiện realtime nào tồn tại → `10_su_kien_realtime.md`.

## Khi thêm chức năng mới

Thêm tệp `11_<ten_chuc_nang>.md` theo mẫu: **Mục đích → File chính → Luồng hoạt động → Realtime → Ghi chú**, rồi thêm một dòng vào bảng trên và vào [`../README.md`](../README.md).
