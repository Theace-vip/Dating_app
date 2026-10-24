import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/constants/app_config.dart';
import 'package:dating_app/core/network/connectivity_service.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/api/api_client.dart';
import 'package:dating_app/data/repositories/chat_repository.dart';
import 'package:dating_app/shared/image_tools.dart';
import 'package:dating_app/shared/widgets/app_widgets.dart';

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final _controller = TextEditingController();
  final List<String> _media = [];
  bool _posting = false;
  bool _uploading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addMedia() async {
    if (_media.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tối đa 3 ảnh mỗi bài')));
      return;
    }
    if (!await ensureOnline(context, ref)) return;
    if (!mounted) return;
    setState(() => _uploading = true);
    try {
      final url = await pickAndUploadImage(ref,
          maxWidth: 1280, quality: 80);
      if (url != null && mounted) {
        setState(() => _media.add(url));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message),
                backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _mediaPreview(String e) {
    if (isNetworkAvatar(e)) {
      return Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(AppConfig.absoluteUrl(e),
                  fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => setState(() => _media.remove(e)),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close,
                    size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }
    return Center(child: Text(e, style: const TextStyle(fontSize: 32)));
  }

  Future<void> _post() async {
    final content = _controller.text.trim();
    if (content.isEmpty && _media.isEmpty) return;
    if (!await ensureOnline(context, ref)) return;
    setState(() => _posting = true);
    final error =
        await ref.read(feedProvider.notifier).addPost(content, _media);
    if (!mounted) return;
    setState(() => _posting = false);
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
      appBar: AppBar(title: const Text('Tạo bài viết')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              hint: 'Bạn đang nghĩ gì?',
              controller: _controller,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Hình ảnh (${_media.length}/3):',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_uploading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    onPressed: _addMedia,
                    icon: const Icon(Icons.add_photo_alternate_outlined,
                        color: AppColors.primary),
                    label: const Text('Chọn ảnh',
                        style: TextStyle(color: AppColors.primary)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _media
                  .map((e) => SizedBox(
                        width: 72,
                        height: 72,
                        child: _mediaPreview(e),
                      ))
                  .toList(),
            ),
            const Spacer(),
            _posting
                ? const Center(child: LoadingWidget())
                : AppButton(label: 'Đăng', onPressed: _post),
          ],
        ),
      ),
    );
  }
}
