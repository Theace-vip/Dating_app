import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dating_app/core/constants/app_config.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/api/api_client.dart';
import 'package:dating_app/data/api/socket_client.dart';
import 'package:dating_app/data/repositories/auth_repository.dart';

/// Lưu địa chỉ máy chủ mới + áp dụng ngay cho Dio/Socket.
/// Trả về host đã chuẩn hóa (vd 'xxx.trycloudflare.com' hoặc '192.168.1.5:3000').
Future<String> saveServerHost(WidgetRef ref, String raw) async {
  AppConfig.applyServerHost(raw);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('server_host', AppConfig.serverHost);
  ref.read(apiClientProvider).applyServerHost();
  final socket = ref.read(socketProvider);
  socket.disconnect();
  if (ref.read(authProvider).isLoggedIn) socket.connect();
  return AppConfig.serverHost;
}

/// Dialog đặt địa chỉ máy chủ — dùng được cả khi CHƯA đăng nhập
/// (màn đăng nhập) lẫn trong app (trang Cá nhân).
/// Nếu [hint] != null sẽ hiện dòng cảnh báo màu đỏ phía trên (vd: lỗi kết nối).
/// Tự kiểm tra /health sau khi lưu; thành công thì tự đóng.
Future<void> showServerHostDialog(
  BuildContext context,
  WidgetRef ref, {
  String? hint,
}) async {
  final ctrl = TextEditingController(text: AppConfig.serverHost);
  String? status;
  bool saving = false;

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Địa chỉ máy chủ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hint != null) ...[
              Text(hint,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.error)),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'https://xxx.trycloudflare.com  hoặc  192.168.1.5',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Text('Hiện tại: ${AppConfig.apiBaseUrl}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            if (status != null) ...[
              const SizedBox(height: 6),
              Text(status!,
                  style: TextStyle(
                      fontSize: 13,
                      color: status!.startsWith('✓')
                          ? AppColors.success
                          : AppColors.textSecondary)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: saving
                ? null
                : () async {
                    setState(() {
                      saving = true;
                      status = 'Đang kiểm tra kết nối...';
                    });
                    await saveServerHost(ref, ctrl.text);
                    final start = DateTime.now();
                    try {
                      await ref.read(apiClientProvider).get('/health',
                          query: {'t': start.millisecondsSinceEpoch});
                      final ms = DateTime.now().difference(start).inMilliseconds;
                      if (!dialogContext.mounted) return;
                      setState(() => status = '✓ Kết nối thành công (${ms}ms)');
                      await Future.delayed(const Duration(milliseconds: 400));
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    } catch (_) {
                      if (!dialogContext.mounted) return;
                      setState(() {
                        saving = false;
                        status =
                            '✗ Chưa kết nối được — kiểm tra URL/IP, server và tunnel đang chạy';
                      });
                    }
                  },
            child: const Text('Lưu & kiểm tra',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    ),
  );
}
