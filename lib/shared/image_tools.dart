import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dating_app/data/api/api_client.dart';

final _picker = ImagePicker();

/// Chọn 1 ảnh từ thư viện (giữ max width, nén quality) rồi upload lên server.
/// Trả về URL (vd: /uploads/img_x.jpg); người dùng hủy -> null.
/// Ném [ApiException] nếu upload thất bại.
Future<String?> pickAndUploadImage(
  WidgetRef ref, {
  double maxWidth = 1280,
  int quality = 85,
}) async {
  final picked = await _picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: maxWidth,
    imageQuality: quality,
  );
  if (picked == null) return null;

  final bytes = await picked.readAsBytes();
  final path = picked.path.toLowerCase();
  final mime = path.endsWith('.png')
      ? 'png'
      : (path.endsWith('.webp') ? 'webp' : 'jpeg');
  return ref.read(apiClientProvider).uploadImage(bytes, mime: mime);
}
