import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/network/connectivity_service.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/models/models.dart';
import 'package:dating_app/data/repositories/catalog_repository.dart';
import 'package:dating_app/data/repositories/auth_repository.dart';
import 'package:dating_app/shared/image_tools.dart';
import 'package:dating_app/shared/widgets/app_widgets.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late int _age;
  late Gender _gender;
  late String _avatar;
  late List<String> _tags;
  List<String> _avatars = const [];
  List<String> _interests = const [];
  bool _catalogLoaded = false;

  @override
  void initState() {
    super.initState();
    final u = ref.read(currentUserProvider);
    _nameCtrl = TextEditingController(text: u.name);
    _bioCtrl = TextEditingController(text: u.bio ?? '');
    _age = u.age;
    _gender = u.gender;
    _avatar = u.avatar;
    _tags = List.from(u.tags);
    // Các lựa chọn avatar/sở thích lấy từ server, thay vì hằng số trong app.
    Future.microtask(_loadCatalog);
  }

  Future<void> _loadCatalog() async {
    try {
      final catalog = await ref.read(appCatalogProvider.future);
      if (!mounted) return;
      setState(() {
        _avatars = catalog.avatars;
        _interests = catalog.interests;
        _catalogLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _catalogLoaded = false);
    }
  }

  Future<void> _pickAvatar() async {
    if (!await ensureOnline(context, ref)) return;
    if (!mounted) return;
    try {
      final url = await pickAndUploadImage(ref,
          maxWidth: 512, quality: 85);
      if (url != null && mounted) setState(() => _avatar = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tải được ảnh lên')));
      }
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tên cần ít nhất 2 ký tự')));
      return;
    }
    if (!await ensureOnline(context, ref)) return;
    final error = await ref.read(authProvider.notifier).completeProfile(
          name: _nameCtrl.text.trim(),
          avatar: _avatar,
          age: _age,
          gender: _gender,
          bio: _bioCtrl.text.trim(),
          tags: _tags,
        );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa hồ sơ'),
        actions: [
          TextButton(
              onPressed: _catalogLoaded ? _save : null,
              child: const Text('Lưu',
                  style: TextStyle(color: AppColors.primary))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tên', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            AppTextField(hint: 'Tên của bạn', controller: _nameCtrl),
            const SizedBox(height: 16),
            const Text('Giới thiệu',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            AppTextField(
                hint: 'Viết vài dòng về bạn',
                controller: _bioCtrl,
                maxLines: 3),
            const SizedBox(height: 16),
            const Text('Tuổi', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton(
                  onPressed: () =>
                      setState(() => _age = _age > 1 ? _age - 1 : _age),
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppColors.primary),
                ),
                Text('$_age',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => setState(() => _age = _age + 1),
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Giới tính',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                AppChip(
                    label: 'Nam',
                    selected: _gender == Gender.male,
                    onTap: () => setState(() => _gender = Gender.male)),
                AppChip(
                    label: 'Nữ',
                    selected: _gender == Gender.female,
                    onTap: () => setState(() => _gender = Gender.female)),
                AppChip(
                    label: 'Khác',
                    selected: _gender == Gender.other,
                    onTap: () => setState(() => _gender = Gender.other)),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Avatar', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                AppAvatar(avatar: _avatar, size: 64, vipFrame: '👑'),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _pickAvatar,
                  icon: const Icon(Icons.photo_camera,
                      size: 18, color: AppColors.primary),
                  label: const Text('Chọn ảnh làm avatar',
                      style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _avatars
                  .map((a) => GestureDetector(
                        onTap: () => setState(() => _avatar = a),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _avatar == a
                                ? AppColors.accentSoft
                                : AppColors.bubbleOther,
                            borderRadius: BorderRadius.circular(24),
                            border: _avatar == a
                                ? Border.all(color: AppColors.primary, width: 2)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(a, style: const TextStyle(fontSize: 26)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            const Text('Sở thích',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _interests
                  .map((t) => AppChip(
                        label: t,
                        selected: _tags.contains(t),
                        onTap: () => setState(() {
                          if (_tags.contains(t)) {
                            _tags.remove(t);
                          } else {
                            _tags.add(t);
                          }
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Lưu thay đổi',
              onPressed: _catalogLoaded ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}
