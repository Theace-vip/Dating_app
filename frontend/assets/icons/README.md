# `frontend/assets/icons/` — icon tuỳ chỉnh

**Vai trò:** chỗ đặt icon riêng của app (SVG hoặc PNG) khi bộ icon Material không đủ.
**Hiện trạng:** **trống** (chỉ có `.gitkeep`). Giao diện hiện dùng `Icons.*` của Material; một số chỗ dùng `flutter_svg` nếu cần icon vector riêng.

## Khi nào dùng

| Dùng | Không dùng |
|---|---|
| Icon thương hiệu (logo mạng xã hội, icon quà đặc biệt) | Icon có sẵn trong Material (`Icons.favorite`, `Icons.send`…) |
| Icon cần đúng thiết kế nhận diện | Ảnh chụp/minh hoạ (→ `assets/images/`) |

## Cách dùng

1. Đặt file `.svg` (ưu tiên) hoặc `.png` vào đây.
2. SVG: `SvgPicture.asset('assets/icons/logo.svg')` (package `flutter_svg` đã có trong `pubspec.yaml`).
3. PNG: `Image.asset('assets/icons/x.png', width: 24, height: 24)`.
4. Icon app (launcher) **không** đặt ở đây — xem `frontend/android/README.md` và `frontend/ios/README.md`.

## Quy ước

- SVG nên có `viewBox`, không nhúng font, kích thước < 50KB.
- Tên file theo chức năng: `ic_gift.svg`, `ic_vip.svg`…
- Màu icon nên để `currentColor` để đổi theo theme nếu có thể.
