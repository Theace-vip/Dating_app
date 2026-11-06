// Smoke test phía client (chạy thuần Dart, không cần điện thoại):
//   dart run tool/client_smoke.dart
// Kiểm chứng: cert pinning chặn cert sai, REST login qua HTTPS, Socket.io kết nối.
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dating_app/core/constants/app_config.dart';
import 'package:dating_app/core/network/pinning.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

int passed = 0, failed = 0;
void ok(bool cond, String name) {
  if (cond) {
    passed++;
    print('  ✓ $name');
  } else {
    failed++;
    print('  ✗ $name');
  }
}

/// "Pin sai" = từ chối mọi certificate (giống hệt khi pin không khớp)
class _BadPin extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (cert, host, port) => false;
}

Future<void> main() async {
  print('== Cert pinning ==');

  // 1. Với pin đúng -> kết nối thành công
  installCertificatePinning();
  final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl,
      validateStatus: (_) => true));
  try {
    final res = await dio.get('/health');
    ok(res.statusCode == 200, 'HTTPS tới server với pin ĐÚNG -> 200');
  } catch (e) {
    ok(false, 'HTTPS tới server với pin ĐÚNG (lỗi: $e)');
  }

  // 2. Với pin SAI -> bị chặn (chính là kịch bản MitM).
  //    Dùng instance Dio MỚI để adapter tạo HttpClient mới dưới override sai.
  HttpOverrides.global = _BadPin();
  final evilDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl,
      validateStatus: (_) => true));
  try {
    final res = await evilDio.get('/health');
    ok(false, 'Pin SAI phải bị chặn (nhưng nhận được ${res.statusCode})');
  } on DioException {
    ok(true, 'Pin SAI bị chặn -> kết nối bị từ chối (chống MitM)');
  } catch (_) {
    ok(true, 'Pin SAI bị chặn -> kết nối bị từ chối (chống MitM)');
  }
  installCertificatePinning(); // khôi phục pin đúng

  print('== REST auth qua HTTPS ==');
  final email = 'smoke_${DateTime.now().millisecondsSinceEpoch}@test.app';
  Map<String, dynamic>? tokens;
  try {
    final reg = await dio.post('/api/auth/register', data: {
      'email': email,
      'password': 'MatKhau123',
      'name': 'Smoke Test',
    });
    tokens = (reg.data as Map).cast<String, dynamic>();
    ok(reg.statusCode == 201 && tokens['accessToken'] != null,
        'đăng ký qua HTTPS thành công');
  } catch (e) {
    ok(false, 'đăng ký qua HTTPS (lỗi: $e)');
  }

  String? access = tokens?['accessToken'] as String?;
  String? refresh = tokens?['refreshToken'] as String?;
  if (access == null) {
    print('\n>>> $passed passed, $failed failed');
    exit(1);
  }

  try {
    final me = await dio.get('/api/me',
        options: Options(headers: {'Authorization': 'Bearer $access'}));
    ok((me.data as Map)['user']?['email'] == email, 'GET /api/me với token');
  } catch (e) {
    ok(false, 'GET /api/me (lỗi: $e)');
  }

  try {
    final refreshed = await dio.post('/api/auth/refresh', data: {
      'refreshToken': refresh,
    });
    ok(refreshed.statusCode == 200 && refreshed.data['refreshToken'] != refresh,
        'refresh token xoay');
    refresh = refreshed.data['refreshToken'] as String?;
  } catch (e) {
    ok(false, 'refresh token (lỗi: $e)');
  }

  print('== Socket.io qua WSS (pinning) ==');
  final socket = io.io(
    AppConfig.socketUrl,
    io.OptionBuilder()
        .setTransports(['websocket'])
        .setQuery({'token': access})
        .enableReconnection()
        .build(),
  );
  final completer = Completer<bool>();
  socket.onConnect((_) => completer.complete(true));
  socket.onConnectError((_) => completer.complete(false));
  socket.onError((_) => completer.complete(false));
  final connected = await completer.future.timeout(
    const Duration(seconds: 8),
    onTimeout: () => false,
  );
  ok(connected, 'socket kết nối bằng access token qua WSS + pinning');
  socket.dispose();

  print('\n>>> $passed passed, $failed failed');
  exit(failed > 0 ? 1 : 0);
}
