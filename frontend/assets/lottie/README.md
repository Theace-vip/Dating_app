# `frontend/assets/lottie/` — animation Lottie

**Vai trò:** animation JSON nhẹ (định dạng Lottie/Bodymovin) dùng cho hiệu ứng giao diện.
**Ai dùng:** `frontend/lib/features/room/room_detail_page.dart` (hiệu ứng khi tặng quà), package `lottie`.

## File trong thư mục

| File | Dùng ở đâu |
|---|---|
| `gift_sparkle.json` | Hiệu ứng lấp lánh khi tặng quà trong phòng tiệc (`Lottie.asset('assets/lottie/gift_sparkle.json')`) |

## Luồng sử dụng

```text
room_detail_page.dart: nhận 'room:gift' từ socket
   └── hiển thị overlay Lottie.asset('assets/lottie/gift_sparkle.json')
         └── LottieController phát một lần → ẩn overlay
```

## Quy ước

1. File JSON phải đúng schema Lottie (kiểm tra bằng `lottie` preview trước khi commit).
2. Giữ dung lượng nhỏ (< 200KB); chi tiết phức tạp nên dùng SVGA.
3. Animation chỉ chạy khi có sự kiện thật (quà, hiệu ứng), không chạy nền liên tục để tiết kiệm pin.
4. Thêm file mới → dùng `Lottie.asset()` với đường dẫn đầy đủ và cập nhật bảng trên.
