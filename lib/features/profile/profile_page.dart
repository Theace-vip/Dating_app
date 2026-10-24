import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dating_app/core/network/connectivity_service.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/api/api_client.dart';
import 'package:dating_app/data/models/models.dart';
import 'package:dating_app/data/repositories/auth_repository.dart';
import 'package:dating_app/shared/widgets/app_widgets.dart';
import 'package:dating_app/features/profile/edit_profile_page.dart';
import 'package:dating_app/features/profile/network_demo_page.dart';
import 'package:dating_app/features/profile/wallet_page.dart';
import 'package:dating_app/features/profile/vip_page.dart';

/// Tab Cá nhân: hiển thị hồ sơ hiện tại, số dư ví, VIP, đổi mật khẩu,
/// chỉnh sửa hồ sơ, kiểm tra mạng/máy chủ và đăng xuất.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  String _genderText(Gender g) {
    switch (g) {
      case Gender.male:
        return 'Nam';
      case Gender.female:
        return 'Nữ';
      case Gender.other:
        return 'Khác';
    }
  }

  /// Đổi mật khẩu qua API: kiểm tra nhập lại, gọi server, sau đó server
  /// thu hồi các phiên cũ và trả token mới cho thiết bị hiện tại.
  Future<void> _showChangePassword(BuildContext context, WidgetRef ref) async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đổi mật khẩu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              obscureText: true,
              decoration:
                  const InputDecoration(hintText: 'Mật khẩu hiện tại'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                  hintText: 'Mật khẩu mới (8+ ký tự, có chữ và số)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration:
                  const InputDecoration(hintText: 'Nhập lại mật khẩu mới'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Lưu',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (saved != true || !context.mounted) return;
    if (oldCtrl.text.isEmpty || newCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập đủ mật khẩu')));
      return;
    }
    if (newCtrl.text != confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mật khẩu nhập lại không khớp')));
      return;
    }
    final err = await ref
        .read(authProvider.notifier)
        .changePassword(oldCtrl.text, newCtrl.text);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      err == null
          ? const SnackBar(
              content: Text(
                  'Đã đổi mật khẩu! Các thiết bị khác cần đăng nhập lại'))
          : SnackBar(content: Text(err), backgroundColor: AppColors.error),
    );
  }

  // ===== Giao diện hồ sơ: thông tin cá nhân, số dư và các mục cài đặt =====
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cá nhân')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: AppAvatar(
                avatar: user.avatar,
                size: 110,
                vipFrame: user.isVip ? user.vipFrame : null,
              ),
            ),
            const SizedBox(height: 12),
            Text(user.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${user.age} tuổi • ${_genderText(user.gender)}',
                style: const TextStyle(color: AppColors.textSecondary)),
            if (user.bio != null && user.bio!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(user.bio!,
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: user.tags.map((t) => AppChip(label: t, selected: true)).toList(),
            ),
            const SizedBox(height: 12),
            if (user.photos.isNotEmpty)
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: user.photos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Container(
                    width: 90,
                    decoration: BoxDecoration(
                      color: AppColors.bubbleOther,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(user.photos[i], style: const TextStyle(fontSize: 40)),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(label: 'Xu', value: '${user.coins}', emoji: '🪙'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                      label: 'Kim cương', value: '${user.diamonds}', emoji: '💎'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _NetworkStatusCard(),
            const SizedBox(height: 16),
            AppButton(
              label: 'Chỉnh sửa',
              onPressed: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditProfilePage()));
              },
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Ví & Xu',
              outline: true,
              onPressed: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WalletPage()));
              },
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'VIP',
              outline: true,
              onPressed: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VipPage()));
              },
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Đổi mật khẩu',
              outline: true,
              onPressed: () => _showChangePassword(context, ref),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Đăng xuất',
              outline: true,
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label, required this.value, required this.emoji});
  final String label;
  final String value;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Thẻ trạng thái mạng + máy chủ (tận dụng connectivity_plus):
/// hiển thị LOẠI kết nối (WiFi/4G...) và ping /health của server.
class _NetworkStatusCard extends ConsumerStatefulWidget {
  const _NetworkStatusCard();

  @override
  ConsumerState<_NetworkStatusCard> createState() =>
      _NetworkStatusCardState();
}

class _NetworkStatusCardState extends ConsumerState<_NetworkStatusCard> {
  String? _serverStatus;

  @override
  void initState() {
    super.initState();
    _ping();
  }

  Future<void> _ping() async {
    final type = ref.read(connectionTypeLabelProvider);
    if (type == 'Offline') {
      setState(() => _serverStatus = 'Mất mạng');
      return;
    }
    setState(() => _serverStatus = 'Đang kiểm tra...');
    final start = DateTime.now();
    try {
      await ref
          .read(apiClientProvider)
          .get('/health', query: {'t': start.millisecondsSinceEpoch});
      final ms = DateTime.now().difference(start).inMilliseconds;
      if (mounted) setState(() => _serverStatus = 'Máy chủ: online (${ms}ms)');
    } catch (_) {
      if (mounted) setState(() => _serverStatus = 'Máy chủ: không kết nối được');
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = ref.watch(connectionTypeLabelProvider);
    final online = ref.watch(isOnlineProvider);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const NetworkDemoPage())),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Icon(
              online ? Icons.wifi : Icons.wifi_off,
              color: online ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mạng: $type',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(_serverStatus ?? '',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
