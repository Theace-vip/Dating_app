class AppConfig {
  // Backend chạy trên PC. Mặc định qua cáp USB (adb reverse tcp:3000 -> localhost).
  // Có thể đổi sang IP LAN / IP公网 trong app (Cá nhân -> thẻ Mạng -> Demo connectivity_plus
  // -> Máy chủ) — lưu vào SharedPreferences, áp dụng lại khi mở app.
  static String serverHost = 'localhost';
  static String apiBaseUrl = 'https://localhost:3000';
  static String socketUrl = 'https://localhost:3000';

  /// Đổi địa chỉ máy chủ lúc runtime. Nhận '192.168.1.5',
  /// '192.168.1.5:3000' hoặc 'https://192.168.1.5:3000'.
  static void applyServerHost(String raw) {
    var host = raw.trim();
    if (host.isEmpty) return;
    host = host.replaceFirst(RegExp(r'^https?://'), '');
    host = host.replaceFirst(RegExp(r'/.*$'), '');
    if (host.isEmpty) return;
    // Thêm cổng 3000 CHỈ khi host là IP/localhost trần;
    // domain có sẵnd (vd abc.trycloudflare.com) thì giữ nguyên cổng 443 của https.
    if (!_hasPort(host) && _looksLikeIpOrLocal(host)) host = '$host:3000';
    serverHost = host;
    apiBaseUrl = 'https://$host';
    socketUrl = 'https://$host';
  }

  static bool _looksLikeIpOrLocal(String host) {
    final bare = host.split(':').first;
    if (bare == 'localhost' || bare == '127.0.0.1') return true;
    // IPv4 trần: 192.168.1.5
    return RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(bare);
  }

  /// true nếu đang trỏ tới tunnel internet (cert do nhà cung cấp tunnel cấp,
  /// không phải cert SoulMate -> không thể pin theo cách cũ).
  static bool get isTunnelHost =>
      serverHost.endsWith('trycloudflare.com') ||
      serverHost.endsWith('ngrok-free.app') ||
      serverHost.endsWith('ngrok.app');

  static bool _hasPort(String host) {
    final i = host.lastIndexOf(':');
    if (i <= 0) return false;
    return int.tryParse(host.substring(i + 1)) != null;
  }

  // Cert pinning: SHA-256 (hex) của certificate server (xem server/certs/server.crt).
  // Nếu regenerate cert: chạy `node server/scripts/gen-cert.js` để lấy pin mới và cập nhật here.
  static const String certPinningSha256 =
      '179eae3cb876467b7a4f69a4949a7e70c74cf89b46853eddec890c05672df3a5';

  // Danh mục avatar, sở thích, thời lượng và giá/quà được tải từ API server.
  // ICE servers vẫn cần cấu hình cục bộ vì RTCPeerConnection chạy trên thiết bị.

  // App info
  static const String appName = 'SoulMate';
  static const String appVersion = '1.0.0';

  // ICE servers cho WebRTC (dùng public STUN test; thay bằng coturn khi deploy)
  static const List<Map<String, dynamic>> iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];

  /// Bỏ đường dẫn tương đối (vd: /uploads/x.jpg) thành URL đầy đủ.
  static String absoluteUrl(String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '$apiBaseUrl$url';
    return url;
  }
}

class AppConstants {
  // Giữ các lựa chọn giao diện thuần trình bày; catalog nghiệp vụ ở API.
}
