import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/constants/app_config.dart';
import 'package:dating_app/core/network/connectivity_service.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/api/api_client.dart';
import 'package:dating_app/data/models/models.dart';
import 'package:dating_app/shared/widgets/app_widgets.dart';
import 'package:dating_app/features/chat/chat_detail_page.dart';
import 'package:dating_app/features/call/call_page.dart';

/// Hồ sơ công khai của người dùng khác (từ feed / tìm kiếm / danh sách bạn).
class PublicProfilePage extends ConsumerStatefulWidget {
  const PublicProfilePage({super.key, required this.userId, this.initial});
  final String userId;
  final UserModel? initial;

  @override
  ConsumerState<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends ConsumerState<PublicProfilePage> {
  UserModel? _user;
  bool _isFriend = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _user = widget.initial;
    _load();
  }

  /// Tải hồ sơ công khai và trạng thái bạn bè từ server.
  /// `initial` (nếu có) được dùng để render ngay trước khi request xong.
  Future<void> _load() async {
    if (!await ensureOnline(context, ref)) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!mounted) return;
    try {
      final data = await ref
          .read(apiClientProvider)
          .get('/api/users/${widget.userId}');
      if (!mounted) return;
      setState(() {
        _user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        _isFriend = data['isFriend'] == true;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không tải được hồ sơ';
          _loading = false;
        });
      }
    }
  }

  /// Mở hoặc tạo chat trước, rồi thay màn hồ sơ bằng hội thoại 1-1.
  Future<void> _message() async {
    final user = _user;
    if (user == null) return;
    if (!await ensureOnline(context, ref)) return;
    if (!mounted) return;
    try {
      final data = await ref
          .read(apiClientProvider)
          .post('/api/conversations/ensure', data: {'partnerId': user.id});
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatDetailPage(
            conversationId: data['conversationId'] as String,
            partnerId: user.id,
            partnerName: user.name,
            partnerAvatar: user.avatar,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// Tạo lời mời gọi ngay từ hồ sơ; server vẫn xác minh online/bận và người nhận phải chấp nhận.
  Future<void> _startCall({required bool video}) async {
    final user = _user;
    if (user == null || !await ensureOnline(context, ref)) return;
    if (!mounted) return;
    if (!user.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Người này hiện không trực tuyến')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallPage(
          peerId: user.id,
          partnerName: user.name,
          partnerAvatar: user.avatar,
          isVideo: video,
          callId: 'call_${DateTime.now().microsecondsSinceEpoch}',
        ),
      ),
    );
  }

  String _genderText(Gender g) => switch (g) {
    Gender.male => 'Nam',
    Gender.female => 'Nữ',
    Gender.other => 'Khác',
  };

  // ===== Giao diện: avatar, thông tin, ảnh và các nút nhắn/gọi =====
  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ')),
      body: _loading
          ? const LoadingWidget()
          : (user == null
                ? EmptyState(message: _error ?? 'Không tìm thấy', emoji: '😕')
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Center(
                          child: AppAvatar(
                            avatar: user.avatar,
                            size: 110,
                            vipFrame: user.isVip
                                ? (user.vipFrame ?? '👑')
                                : null,
                            isOnline: user.isOnline,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (user.isOnline) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'Đang online',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${user.age} tuổi • ${_genderText(user.gender)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (_isFriend) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '💜 Các bạn đã là bạn bè',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                        if (user.bio != null && user.bio!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            user.bio!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: user.tags
                              .map((t) => AppChip(label: t, selected: true))
                              .toList(),
                        ),
                        if (user.photos.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 90,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: user.photos.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, i) => SizedBox(
                                width: 90,
                                child: isNetworkAvatar(user.photos[i])
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          AppConfig.absoluteUrl(user.photos[i]),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const SizedBox.shrink(),
                                        ),
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.bubbleOther,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          user.photos[i],
                                          style: const TextStyle(fontSize: 40),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        AppButton(label: 'Nhắn tin', onPressed: _message),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _startCall(video: false),
                                icon: const Icon(Icons.call),
                                label: const Text('Gọi thoại'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _startCall(video: true),
                                icon: const Icon(Icons.videocam),
                                label: const Text('Gọi video'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )),
    );
  }
}
