import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dating_app/core/constants/app_config.dart';
import 'package:dating_app/core/network/connectivity_service.dart';
import 'package:dating_app/core/network/outbox.dart';
import 'package:dating_app/core/network/pinning.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/app/router.dart';
import 'package:dating_app/data/api/socket_client.dart';
import 'package:dating_app/data/repositories/auth_repository.dart';
import 'package:dating_app/features/call/call_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Chống MitM: chỉ chấp nhận certificate có pin đúng với SoulMate server.
  installCertificatePinning();
  // Khôi phục địa chỉ máy chủ đã lưu (IP LAN / IP公网) nếu người dùng đã đổi.
  final prefs = await SharedPreferences.getInstance();
  final savedHost = prefs.getString('server_host');
  if (savedHost != null && savedHost.isNotEmpty) {
    AppConfig.applyServerHost(savedHost);
  }
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

/// Lớp điều phối cấp ứng dụng: giữ socket chung, ví realtime và cuộc gọi đến.
class _MyAppState extends ConsumerState<MyApp> {
  StreamSubscription<dynamic>? _walletSub;
  StreamSubscription<dynamic>? _callSub;

  @override
  void initState() {
    super.initState();
    // Khôi phục hàng đợi tin nhắn offline từ lần chạy trước (nếu có)
    Future.microtask(() async {
      final outbox = ref.read(outboxProvider);
      await outbox.init();
      if (ref.read(isOnlineProvider)) await outbox.flush();
    });

    // Cập nhật số dư ví khi server báo (gửi quà trong phòng...)
    _walletSub = ref.read(socketProvider).on('user:wallet').listen((data) {
      final map = data as Map;
      ref
          .read(authProvider.notifier)
          .applyWallet(
            (map['coins'] as num?)?.toInt() ?? 0,
            (map['diamonds'] as num?)?.toInt() ?? 0,
          );
    });

    // Cuộc gọi đến: mở giao diện accept/reject trên root navigator;
    // nếu app đã có màn gọi thì từ chối để không chiếm cùng lúc hai phiên media.
    _callSub = ref.read(socketProvider).on('call:invite').listen((data) {
      if (!mounted) return;
      final map = data as Map;
      if (map['callId'] is! String || map['from'] is! String) return;
      if (gInCall) {
        ref.read(socketProvider).emit('call:reject', {
          'to': map['from'],
          'callId': map['callId'],
        });
        return;
      }
      final navigator = rootNavigatorKey.currentState;
      navigator?.push(
        MaterialPageRoute(
          builder: (_) => CallPage(
            peerId: (map['from'] ?? '').toString(),
            partnerName: (map['fromName'] ?? 'Người gọi').toString(),
            partnerAvatar: (map['fromAvatar'] ?? '🙂').toString(),
            isVideo: map['isVideo'] == true,
            callId: (map['callId'] ?? '').toString(),
            incoming: true,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _walletSub?.cancel();
    _callSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Socket kết nối khi đã đăng nhập, ngắt khi đăng xuất
    ref.listen(authProvider, (previous, next) {
      final socket = ref.read(socketProvider);
      if (next.isLoggedIn) {
        socket.connect();
      } else if (previous?.isLoggedIn == true) {
        socket.disconnect();
      }
    });

    // Mạng quay lại -> đảm bảo socket được kết nối + gửi lại hàng đợi offline
    ref.listen(connectivityProvider, (previous, next) {
      final now = next.valueOrNull;
      final before = previous?.valueOrNull;
      final online = now != null && now != ConnectivityResult.none;
      final wasOffline = before == null || before == ConnectivityResult.none;
      if (online && wasOffline && ref.read(authProvider).isLoggedIn) {
        ref.read(socketProvider).connect();
        ref.read(outboxProvider).flush();
      }
    });

    return MaterialApp.router(
      title: 'SoulMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
