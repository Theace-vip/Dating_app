import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:dating_app/core/constants/app_config.dart';
import 'package:dating_app/data/api/api_client.dart';

/// Provider gốc dùng chung một client socket đã xác thực cho toàn ứng dụng.
final socketProvider = Provider<SocketService>((ref) => SocketService());

/// Quản lý 1 kết nối Socket.io duy nhất (authenticated).
/// Các widget lắng nghe sự kiện qua stream của [on] và hủy khi dispose.
class SocketService {
  io.Socket? _socket;
  bool _connecting = false;
  // Mỗi event có một broadcast controller riêng để nhiều widget cùng nghe
  // mà không tranh nhau một Stream duy nhất.
  final Map<String, StreamController<dynamic>> _controllers = {};

  bool get connected => _socket?.connected ?? false;

  /// Stream của 1 sự kiện server phát xuống (chat:message, room:heart, ...).
  Stream<dynamic> on(String event) => _controllers
      .putIfAbsent(event, () => StreamController<dynamic>.broadcast())
      .stream;

  void _relay(String event, dynamic data) {
    _controllers[event]?.add(data);
  }

  /// Lấy access token rồi mở WebSocket có reconnect; giữ một stream riêng mỗi event.
  Future<void> connect() async {
    if ((_socket?.connected ?? false) || _connecting) return;
    _connecting = true;
    try {
      final token = await secureStorage.read(key: kAccessKey);
      if (token == null) return;
      _socket = io.io(
        AppConfig.socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setQuery({'token': token})
            .enableReconnection()
            .build(),
      );
      // Danh sách event server phát xuống; thêm event mới ở đây thì [on]
      // mới nhận được dữ liệu tương ứng.
      final events = [
        'chat:message',
        'chat:message-edited',
        'chat:message-deleted',
        'chat:typing',
        'presence:changed',
        'soul:queued',
        'soul:matched',
        'soul:message',
        'soul:heart-available',
        'soul:like:sent',
        'soul:like:received',
        'soul:like:error',
        'soul:mutual-like',
        'soul:revealed',
        'soul:continued',
        'soul:time-ended',
        'soul:continue:error',
        'soul:partner-left',
        'soul:rtc:signal',
        'room:presence',
        'room:message',
        'room:heart',
        'room:gift',
        'room:error',
        'room:rtc:peers',
        'room:rtc:joined',
        'room:rtc:left',
        'room:rtc:signal',
        'call:invite',
        'call:accepted',
        'call:rejected',
        'call:ended',
        'call:error',
        'rtc:signal',
        'feed:comment:new',
        'feed:comment:updated',
        'feed:comment:deleted',
        'user:wallet',
        'feed:new',
        'feed:updated',
        'feed:deleted',
        'feed:stats',
      ];
      for (final e in events) {
        _socket!.on(e, (data) => _relay(e, data));
      }
      // Các event vòng đời được chuẩn hoá thành stream để UI/theo dõi mạng
      // không phải phụ thuộc trực tiếp vào socket.io.
      _socket!.onConnect((_) => _relay('connect', true));
      _socket!.onDisconnect((_) => _relay('connect', false));
      _socket!.onConnectError((err) => _relay('connect_error', err));
    } finally {
      _connecting = false;
    }
  }

  /// Gửi hành động lên server; event trả về được chuyển qua [on].
  void emit(String event, [dynamic data]) {
    _socket?.emit(event, data);
  }

  /// Đóng kết nối nhưng giữ các stream để lần connect sau vẫn dùng lại được.
  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  /// Dọn hẳn service: đóng socket và tất cả stream (dùng khi app/provider bị hủy).
  void dispose() {
    disconnect();
    for (final c in _controllers.values) {
      c.close();
    }
    _controllers.clear();
  }
}
