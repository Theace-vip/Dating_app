import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dating_app/core/constants/app_config.dart';

/// Chống tấn công MitM (man-in-the-middle): chỉ chấp nhận certificate
/// có SHA-256 khớp với pin của SoulMate server.
///
/// Áp dụng TOÀN CỤC qua [HttpOverrides.global] nên cả Dio (REST)
/// lẫn WebSocket/Socket.io đều được bảo vệ.
class PinningHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // cert.der là DER encoding -> sha256 giống hệt pin server công bố
        final digest = sha256.convert(cert.der).toString();
        if (digest == AppConfig.certPinningSha256) return true;
        // Chế độ TUNNEL internet: TLS do nhà cung cấp tunnel (Cloudflare/ngrok)
        // terminates với cert của HỌ, không pin được theo cách cũ.
        // Chỉ chấp nhận đúng host tunnel mà người dùng đã chủ động nhập,
        // mọi host khác vẫn bắt buộc đúng pin.
        if (AppConfig.isTunnelHost && host == AppConfig.serverHost.split(':').first) {
          return true;
        }
        return false;
      };
  }
}

/// Gọi một lần trong main() trước khi runApp.
void installCertificatePinning() {
  HttpOverrides.global = PinningHttpOverrides();
}

/// Helper để in SHA-256 của cert khi cần cập nhật pin (dùng khi regenerate cert).
String fingerprintOfPem(String pem) {
  final b64 = pem
      .replaceAll('-----BEGIN CERTIFICATE-----', '')
      .replaceAll('-----END CERTIFICATE-----', '')
      .replaceAll(RegExp(r'\s+'), '');
  return sha256.convert(base64Decode(b64)).toString();
}
