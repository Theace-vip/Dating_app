# Nguồn và bản quyền các file .svga

Các file trong thư mục này được tải từ:

- https://github.com/svga/SVGA-Samples

README của repo gốc ghi (nguyên văn): *"以下动画版权归 YY Inc. 所有，仅用于学习使用，禁止商业使用。"*

Nghĩa là: **bản quyền các animation thuộc YY Inc., chỉ dùng cho mục đích học tập, cấm dùng cho mục đích thương mại.**

Repo không kèm file LICENSE riêng.

## Phạm vi sử dụng trong dự án này

Dự án hiện là đồ án học tập, không phát hành thương mại, nên các animation này
được dùng để minh hoạ hiệu ứng quà tặng trong phòng. Nếu sau này chuyển sang
mục đích thương mại, **phải thay toàn bộ** bằng asset có giấy phép phù hợp
(mua từ svga.io hoặc tự xuất bằng SVGAPlayer Designer / After Effects).

## Không dùng

`Rocket.svga` trong repo mẫu là **SVGA 1.0** (định dạng ZIP), trong khi player
Flutter chỉ hỗ trợ **SVGA 2.0** (zlib) — giải mã sẽ báo `Filter error, bad data`.
Vì vậy quà "Tên lửa" đã bị bỏ khỏi catalog. Nếu cần lại, phải xuất/xin một file
`rocket.svga` định dạng 2.0.

## Danh sách file đang dùng

| File | Dùng cho quà |
|---|---|
| `rose.svga` | Hoa hồng |
| `heartbeat.svga` | Nhịp tim |
| `TwitterHeart.svga` | Trái tim bay |
| `angel.svga` | Thiên thần |
| `halloween.svga` | Bí ngô |
| `kingset.svga` | Vương miện |
| `posche.svga` | Siêu xe |
