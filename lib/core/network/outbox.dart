import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dating_app/data/api/api_client.dart';
import 'package:dating_app/data/repositories/chat_repository.dart';

/// Hàng đợi OUTBOX: khi mất mạng, tin nhắn gửi đi được GIỮ LẠI (persist)
/// và TỰ ĐỘNG gửi lại ngay khi connectivity_plus báo có mạng trở lại.
final outboxProvider = Provider<Outbox>((ref) => Outbox(ref));

class Outbox {
  Outbox(this._ref);
  final Ref _ref;

  static const _prefsKey = 'soulmate.outbox';
  final List<Map<String, String>> _items = [];
  bool _flushing = false;

  int get length => _items.length;

  Future<void> _persist() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(
        _prefsKey, _items.map(jsonEncode).toList(growable: false));
  }

  /// Khôi phục hàng đợi từ lần chạy trước (gọi khi app khởi động).
  Future<void> init() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final list = sp.getStringList(_prefsKey) ?? [];
      _items
        ..clear()
        ..addAll(list
            .map((e) => jsonDecode(e) as Map<String, dynamic>)
            .map((e) => e.map((k, v) => MapEntry(k, '$v'))));
    } catch (_) {
      // hàng đợi hỏng -> bỏ qua
    }
  }

  /// Giữ tin nhắn lại để gửi sau (khi offline hoặc lỗi mạng).
  Future<void> enqueue(String conversationId, String content) async {
    _items.add({'conversationId': conversationId, 'content': content});
    await _persist();
  }

  /// Gửi lại toàn bộ hàng đợi. Dừng lại nếu vẫn chưa có mạng.
  Future<void> flush() async {
    if (_flushing || _items.isEmpty) return;
    _flushing = true;
    try {
      final api = _ref.read(apiClientProvider);
      for (final item in List.of(_items)) {
        final conversationId = item['conversationId']!;
        final content = item['content']!;
        try {
          await api.post('/api/conversations/$conversationId/messages', data: {
            'content': content,
            'clientMessageId':
                'outbox_${DateTime.now().microsecondsSinceEpoch}',
          });
          _items.remove(item);
          await _persist();
          _ref
              .read(chatProvider.notifier)
              .applySent(conversationId, content);
        } catch (_) {
          // còn offline hoặc server lỗi -> thử lại lần sau
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }
}
