import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/constants/app_style.dart';
import 'package:dating_app/core/network/connectivity_service.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/models/models.dart';
import 'package:dating_app/data/repositories/catalog_repository.dart';
import 'package:dating_app/data/repositories/auth_repository.dart';
import 'package:dating_app/shared/image_tools.dart';
import 'package:dating_app/shared/widgets/app_widgets.dart';

class ProfileSetupPage extends ConsumerStatefulWidget {
  const ProfileSetupPage({super.key});
  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  final _nameController = TextEditingController();
  String _avatar = '🙂';
  List<String> _avatars = const [];
  List<String> _interests = const [];
  bool _catalogLoaded = false;
  int _age = 20;
  Gender _gender = Gender.female;
  final _bioController = TextEditingController();
  final Set<String> _tags = {};

  @override
  void initState() {
    super.initState();
    // Nạp các lựa chọn hồ sơ từ backend để app không tự giữ catalog nghiệp vụ.
    Future.microtask(_loadCatalog);
  }

  Future<void> _loadCatalog() async {
    try {
      final catalog = await ref.read(appCatalogProvider.future);
      if (!mounted) return;
      setState(() {
        _avatars = catalog.avatars;
        _interests = catalog.interests;
        _avatar = _avatars.isNotEmpty ? _avatars.first : '🙂';
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tải được ảnh lên')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thiết lập hồ sơ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text('Chọn avatar hoạt hình',
                  style: AppTextStyle.title),
            ),
            const SizedBox(height: 12),
            Center(
              child: AppAvatar(avatar: _avatar, size: 90, vipFrame: '👑'),
            ),
            Center(
              child: TextButton.icon(
                onPressed: _pickAvatar,
                icon: const Icon(Icons.photo_camera,
                    size: 18, color: AppColors.primary),
                label: const Text('Dùng ảnh của bạn',
                    style: TextStyle(color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _avatars
                  .map((e) => GestureDetector(
                        onTap: () => setState(() => _avatar = e),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _avatar == e
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : AppColors.bubbleOther,
                            border: _avatar == e
                                ? Border.all(color: AppColors.primary, width: 2)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(e, style: const TextStyle(fontSize: 24)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text('Tên hiển thị', style: AppTextStyle.title),
            const SizedBox(height: 8),
            AppTextField(hint: 'Nhập tên', controller: _nameController),
            const SizedBox(height: 16),
            const Text('Tuổi', style: AppTextStyle.title),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _age = (_age - 1).clamp(16, 80)),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Expanded(
                  child: Text('$_age tuổi',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  onPressed: () => setState(() => _age = (_age + 1).clamp(16, 80)),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Giới tính', style: AppTextStyle.title),
            const SizedBox(height: 8),
            Row(
              children: Gender.values
                  .map((g) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AppChip(
                            label: g == Gender.male
                                ? 'Nam'
                                : g == Gender.female
                                    ? 'Nữ'
                                    : 'Khác',
                            selected: _gender == g,
                            onTap: () => setState(() => _gender = g),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            const Text('Tiểu sử', style: AppTextStyle.title),
            const SizedBox(height: 8),
            AppTextField(hint: 'Viết vài dòng về bạn...',
                controller: _bioController, maxLines: 3),
            const SizedBox(height: 16),
            const Text('Sở thích', style: AppTextStyle.title),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _interests
                  .map((t) => AppChip(
                        label: t,
                        selected: _tags.contains(t),
                        onTap: () => setState(() {
                          _tags.contains(t) ? _tags.remove(t) : _tags.add(t);
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 28),
            AppButton(
              label: 'Bắt đầu',
              onPressed: !_catalogLoaded ? null : () async {
                if (_nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập tên')));
                  return;
                }
                if (!await ensureOnline(context, ref)) return;
                final error =
                    await ref.read(authProvider.notifier).completeProfile(
                          name: _nameController.text.trim(),
                          avatar: _avatar,
                          age: _age,
                          gender: _gender,
                          bio: _bioController.text.trim(),
                          tags: _tags.toList(),
                        );
                if (error != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(error),
                        backgroundColor: AppColors.error),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
