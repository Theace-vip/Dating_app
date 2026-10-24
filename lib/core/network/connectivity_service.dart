import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Trạng thái LOẠI kết nối THẬT từ connectivity_plus.
/// Ưu tiên hiển thị: Ethernet > WiFi > VPN > Di động > Bluetooth > Khác.
final connectivityProvider = StreamProvider<ConnectivityResult>((ref) async* {
  final connectivity = Connectivity();
  yield _primary(await connectivity.checkConnectivity());
  await for (final results in connectivity.onConnectivityChanged) {
    yield _primary(results);
  }
});

ConnectivityResult _primary(List<ConnectivityResult> results) {
  const priority = [
    ConnectivityResult.ethernet,
    ConnectivityResult.wifi,
    ConnectivityResult.vpn,
    ConnectivityResult.mobile,
    ConnectivityResult.bluetooth,
    ConnectivityResult.satellite,
    ConnectivityResult.other,
  ];
  for (final p in priority) {
    if (results.contains(p)) return p;
  }
  return ConnectivityResult.none;
}

/// true nếu có ít nhất một loại kết nối.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).maybeWhen(
        data: (type) => type != ConnectivityResult.none,
        orElse: () => true,
      );
});

/// Nhãn loại mạng để hiển thị: 'WiFi', '4G', 'Ethernet'...
final connectionTypeLabelProvider = Provider<String>((ref) {
  final type = ref.watch(connectivityProvider).valueOrNull;
  return switch (type) {
    ConnectivityResult.wifi => 'WiFi',
    ConnectivityResult.ethernet => 'Ethernet',
    ConnectivityResult.mobile => '4G/5G',
    ConnectivityResult.vpn => 'VPN',
    ConnectivityResult.bluetooth => 'Bluetooth',
    ConnectivityResult.satellite => 'Vệ tinh',
    ConnectivityResult.other => 'Khác',
    ConnectivityResult.none => 'Offline',
    null => 'Đang kiểm tra...',
  };
});

/// Kiểm tra MẠNG TRỰC TIẾP (không tin cache) trước mỗi thao tác quan trọng:
/// gọi `Connectivity().checkConnectivity()` mới nhất từ hệ điều hành.
/// Trả về false + hiện SnackBar nếu offline.
Future<bool> ensureOnline(BuildContext context, WidgetRef ref) async {
  final results = await Connectivity().checkConnectivity();
  final online = results.any((r) => r != ConnectivityResult.none);
  if (!online) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có kết nối mạng — vui lòng kiểm tra WiFi/4G'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    return false;
  }
  return true;
}

/// Banner trạng thái mạng: đỏ khi mất mạng, xám mờ hiện LOẠI mạng
/// (4G/WiFi) khi đang dùng dữ liệu di động để người dùng biết.
class NetworkBanner extends ConsumerWidget {
  const NetworkBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider);
    final type = ref.watch(connectionTypeLabelProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: !online
          ? Container(
              key: const ValueKey('offline'),
              width: double.infinity,
              color: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Text(
                '⚠ Mất kết nối mạng — một số chức năng bị tạm dừng',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            )
          : (type == '4G/5G'
              ? Container(
                  key: const ValueKey('mobile'),
                  width: double.infinity,
                  color: const Color(0xFFFFB020),
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(
                    '📡 Đang dùng dữ liệu di động ($type) — tải ảnh có thể chậm',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('ok'))),
    );
  }
}
