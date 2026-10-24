import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/network/connectivity_service.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/api/api_client.dart';
import 'package:dating_app/data/models/models.dart';
import 'package:dating_app/shared/widgets/app_widgets.dart';
import 'package:dating_app/features/chat/chat_detail_page.dart';

class FriendsPage extends ConsumerStatefulWidget {
  const FriendsPage({super.key});

  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends ConsumerState<FriendsPage> {
  List<Map<String, dynamic>> _friends = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!await ensureOnline(context, ref)) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (!mounted) return;
    try {
      final data = await ref.read(apiClientProvider).get('/api/friends');
      if (!mounted) return;
      setState(() {
        _friends = (data['friends'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không tải được danh sách bạn bè';
          _loading = false;
        });
      }
    }
  }

  void _openChat(Map<String, dynamic> f) {
    final user = UserModel.fromJson(f);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          conversationId: f['conversationId'] as String,
          partnerId: user.id,
          partnerName: user.name,
          partnerAvatar: user.avatar,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bạn bè'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const LoadingWidget()
          : (_error != null
              ? EmptyState(message: _error!, emoji: '😕')
              : _friends.isEmpty
                  ? const EmptyState(
                      message:
                          'Chưa có bạn bè — hãy chơi Trò chơi tâm giao để kết bạn',
                      emoji: '💜')
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _load,
                      child: ListView.separated(
                        itemCount: _friends.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 76),
                        itemBuilder: (_, i) {
                          final f = _friends[i];
                          return ListTile(
                            leading: AppAvatar(
                              avatar: f['avatar'] as String? ?? '🙂',
                              size: 52,
                              isOnline: f['isOnline'] == true,
                            ),
                            title: Text(
                              f['name'] as String? ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            subtitle: Text(
                              'Kết bạn từ ${_formatDate(f['friendsSince'])}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary),
                            ),
                            trailing: const Icon(Icons.chat_bubble_outline,
                                color: AppColors.primary),
                            onTap: () => _openChat(f),
                          );
                        },
                      ),
                    )),
    );
  }

  String _formatDate(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return 'Soul Game';
    return '${d.day}/${d.month}/${d.year}';
  }
}
