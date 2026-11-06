# `docs/` — tài liệu dự án (mức toàn cục)

**Vai trò:** tài liệu nằm ngoài mã nguồn, mô tả kiến trúc, danh mục file và luồng chạy của toàn dự án.
Tài liệu chi tiết theo **từng thư mục** nằm ngay trong thư mục đó (`backend/README.md`, `frontend/lib/.../README.md`).
Tài liệu theo **từng chức năng phía client** nằm ở [`frontend/docs/`](../frontend/docs/README.md).

## File trong thư mục

| File | Nội dung |
|---|---|
| [`LUONG_CODE_THEO_FILE.md`](LUONG_CODE_THEO_FILE.md) | **Luồng code theo từng file**: chart UI → notifier → ApiClient → route → SQLite → socket → UI cho chat, feed, phòng, Soul Game, gọi điện, hồ sơ, catalog, presence. Có bảng "muốn sửa X thì đọc file nào". |
| [`CODE_FLOWS_VI.md`](CODE_FLOWS_VI.md) | Luồng chạy theo chức năng, viết theo góc nhìn nghiệp vụ (auth, feed, chat, gọi, Soul Game, phòng, ví). |
| [`FILE_GUIDE_VI.md`](FILE_GUIDE_VI.md) | Danh mục thư mục/file toàn dự án và gợi ý nên sửa ở đâu. |
| [`PROJECT_GUIDE_VI.md`](PROJECT_GUIDE_VI.md) | Kiến trúc tổng thể, WebRTC, feed/bình luận, các quyết định thiết kế. |

> Ba file `*_VI.md` được viết trước khi tách `backend/` + `frontend/`; đầu mỗi file có ghi chú quy đổi đường dẫn (`lib/` → `frontend/lib/`, `server/` → `backend/`).

## Mục lục tài liệu theo thư mục

| Thư mục | Tài liệu |
|---|---|
| Gốc dự án | [`README.md`](../README.md) |
| Backend | [`backend/README.md`](../backend/README.md) |
| Backend — mã nguồn | [`backend/src/README.md`](../backend/src/README.md) |
| Backend — script | [`backend/scripts/README.md`](../backend/scripts/README.md) |
| Frontend | [`frontend/README.md`](../frontend/README.md) |
| Flutter — tổng quan `lib/` | [`frontend/lib/README.md`](../frontend/lib/README.md) |
| Điều hướng | [`frontend/lib/app/README.md`](../frontend/lib/app/README.md) |
| Nền tảng dùng chung | [`frontend/lib/core/README.md`](../frontend/lib/core/README.md) |
| — hằng số | [`frontend/lib/core/constants/README.md`](../frontend/lib/core/constants/README.md) |
| — mạng / offline / bảo mật | [`frontend/lib/core/network/README.md`](../frontend/lib/core/network/README.md) |
| — giao diện | [`frontend/lib/core/theme/README.md`](../frontend/lib/core/theme/README.md) |
| Dữ liệu | [`frontend/lib/data/README.md`](../frontend/lib/data/README.md) |
| — API & socket | [`frontend/lib/data/api/README.md`](../frontend/lib/data/api/README.md) |
| — model | [`frontend/lib/data/models/README.md`](../frontend/lib/data/models/README.md) |
| — state/repository | [`frontend/lib/data/repositories/README.md`](../frontend/lib/data/repositories/README.md) |
| Màn hình | [`frontend/lib/features/README.md`](../frontend/lib/features/README.md) |
| — auth | [`frontend/lib/features/auth/README.md`](../frontend/lib/features/auth/README.md) |
| — chat | [`frontend/lib/features/chat/README.md`](../frontend/lib/features/chat/README.md) |
| — feed | [`frontend/lib/features/feed/README.md`](../frontend/lib/features/feed/README.md) |
| — home | [`frontend/lib/features/home/README.md`](../frontend/lib/features/home/README.md) |
| — matching (Soul/Voice Game) | [`frontend/lib/features/matching/README.md`](../frontend/lib/features/matching/README.md) |
| — room | [`frontend/lib/features/room/README.md`](../frontend/lib/features/room/README.md) |
| — room/widgets | [`frontend/lib/features/room/widgets/README.md`](../frontend/lib/features/room/widgets/README.md) |
| — call | [`frontend/lib/features/call/README.md`](../frontend/lib/features/call/README.md) |
| — profile | [`frontend/lib/features/profile/README.md`](../frontend/lib/features/profile/README.md) |
| Widget/tiện ích dùng chung | [`frontend/lib/shared/README.md`](../frontend/lib/shared/README.md) |
| — widgets | [`frontend/lib/shared/widgets/README.md`](../frontend/lib/shared/widgets/README.md) |
| Asset | [`frontend/assets/README.md`](../frontend/assets/README.md) |
| Tài liệu chức năng frontend | [`frontend/docs/README.md`](../frontend/docs/README.md) |
| Test / tool / integration test | [`frontend/test/README.md`](../frontend/test/README.md), [`frontend/tool/README.md`](../frontend/tool/README.md), [`frontend/integration_test/README.md`](../frontend/integration_test/README.md) |
| Project shell | [`frontend/android/README.md`](../frontend/android/README.md), [`ios`](../frontend/ios/README.md), [`web`](../frontend/web/README.md), [`windows`](../frontend/windows/README.md), [`linux`](../frontend/linux/README.md), [`macos`](../frontend/macos/README.md) |

## Thư mục sinh tự động (không có tài liệu riêng, không commit)

`frontend/build/`, `frontend/.dart_tool/`, `frontend/android/.gradle/`, `frontend/*/ephemeral/`, `backend/node_modules/`, `backend/data/`, `backend/uploads/`, `backend/certs/`, `backend/backups/`, `dist/`, `qa-artifacts/`, `*.log`.

## Khi thêm thư mục mới

Thêm `README.md` ngay trong thư mục đó theo mẫu: **Vai trò → Ai gọi tới → Bảng file → Luồng hoạt động → Quy ước**, rồi bổ sung một dòng vào bảng mục lục trên và vào [`docs/README.md`](README.md).
