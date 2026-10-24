import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/network/connectivity_service.dart';
import 'package:dating_app/core/constants/app_config.dart';
import 'package:dating_app/shared/server_host.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/api/api_client.dart';

/// Màn DEMO thư viện connectivity_plus:
/// - Stream `onConnectivityChanged` ghi log thời gian thực (bật/tắt WiFi, 4G...)
/// - Nút gọi `checkConnectivity()` (kiểm tra TRỰC TIẾP 1 lần)
/// - Ping /health của server đo latency
/// Cách demo: mở màn này, bật/tắt WiFi hoặc Chế độ máy bay, xem log chạy.
class NetworkDemoPage extends ConsumerStatefulWidget {
  const NetworkDemoPage({super.key});

  @override
  ConsumerState<NetworkDemoPage> createState() => _NetworkDemoPageState();
}

class _NetworkDemoPageState extends ConsumerState<NetworkDemoPage> {
  final List<String> _log = [];
  final Connectivity _connectivity = Connectivity();
  late final TextEditingController _hostCtrl;
  String? _oneShotResult;
  String? _pingResult;

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController(text: AppConfig.serverHost);
    // Ghi nhận MỌI sự kiện thay đổi kết nối từ hệ điều hành.
    _connectivity.onConnectivityChanged.listen((results) {
      if (!mounted) return;
      _addLog('onConnectivityChanged → ${_label(results)}');
    });
    _oneShot();
  }

  String _label(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return 'NONE (offline)';
    }
    return results.map((r) => r.name).join(' + ');
  }

  void _addLog(String message) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() => _log.insert(0, '[$ts] $message'));
    if (_log.length > 50) _log.removeLast();
  }

  Future<void> _oneShot() async {
    final results = await _connectivity.checkConnectivity();
    if (!mounted) return;
    setState(() => _oneShotResult = _label(results));
    _addLog('checkConnectivity() → ${_label(results)}');
  }

  Future<void> _ping() async {
    setState(() => _pingResult = 'Đang ping...');
    final start = DateTime.now();
    try {
      await ref
          .read(apiClientProvider)
          .get('/health', query: {'t': start.millisecondsSinceEpoch});
      final ms = DateTime.now().difference(start).inMilliseconds;
      setState(() => _pingResult = '✓ Máy chủ online — ${ms}ms');
    } catch (_) {
      setState(() => _pingResult = '✗ Không kết nối được máy chủ');
    }
  }

  Future<void> _saveHost() async {
    final raw = _hostCtrl.text.trim();
    if (raw.isEmpty) return;
    await saveServerHost(ref, raw);
    _hostCtrl.text = AppConfig.serverHost;
    _addLog('Đổi máy chủ → ${AppConfig.apiBaseUrl}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Đã lưu máy chủ: ${AppConfig.apiBaseUrl}')));
    }
    await _ping();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = ref.watch(connectionTypeLabelProvider);
    final online = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Demo connectivity_plus')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thẻ trạng thái hiện tại (StreamProvider)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(online ? Icons.wifi : Icons.wifi_off,
                          color: online ? AppColors.success : AppColors.error),
                      const SizedBox(width: 8),
                      Text('Trạng thái: $type',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    online
                        ? 'Có kết nối — mọi chức năng hoạt động'
                        : 'Mất kết nối — app tự chặn thao tác và xếp tin vào hàng đợi',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Nút demo
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _oneShot,
                    icon: const Icon(Icons.search),
                    label: const Text('checkConnectivity()'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _ping,
                    icon: const Icon(Icons.speed),
                    label: const Text('Ping server'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_oneShotResult != null)
              Text('  Một lần: $_oneShotResult',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            if (_pingResult != null)
              Text('  $_pingResult',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            // ==== Cấu hình máy chủ (kết nối online qua LAN / internet) ====
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Máy chủ (Server)',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text(
                    'Nhập IP của PC (ví dụ 192.168.1.5) nếu cùng WiFi, hoặc '
                    'URL tunnel từ ket_noi_internet.bat '
                    '(https://....trycloudflare.com) để vào từ bất kỳ đâu.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hostCtrl,
                          decoration: const InputDecoration(
                            hintText: '192.168.1.5  hoặc  https://....trycloudflare.com',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _saveHost,
                        child: const Text('Lưu'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Hiện tại: ${AppConfig.apiBaseUrl}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Nhật ký sự kiện (thời gian thực)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Thử: bật/tắt WiFi, chuyển WiFi ↔ 4G, bật Chế độ máy bay',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(minHeight: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _log.isEmpty
                  ? const Text('Chưa có sự kiện — hãy đổi trạng thái mạng',
                      style: TextStyle(color: Colors.white54, fontSize: 13))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _log
                          .map((l) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(l,
                                    style: const TextStyle(
                                        color: Color(0xFF7EE787),
                                        fontSize: 13,
                                        fontFamily: 'monospace')),
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
