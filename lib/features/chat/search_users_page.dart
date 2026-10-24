import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/api/api_client.dart';
import 'package:dating_app/data/models/models.dart';
import 'package:dating_app/shared/widgets/app_widgets.dart';
import 'package:dating_app/features/profile/public_profile_page.dart';

class SearchUsersPage extends ConsumerStatefulWidget {
  const SearchUsersPage({super.key});

  @override
  ConsumerState<SearchUsersPage> createState() => _SearchUsersPageState();
}

class _SearchUsersPageState extends ConsumerState<SearchUsersPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<UserModel> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);
    try {
      final data =
          await ref.read(apiClientProvider).get('/api/users', query: {'q': q});
      if (!mounted) return;
      setState(() {
        _results = (data['users'] as List)
            .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
        _searched = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _searched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tìm kiếm')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: AppTextField(
              hint: 'Tìm theo tên hoặc email...',
              controller: _controller,
              onChanged: _onChanged,
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.primary),
            ),
          ),
          Expanded(
            child: !_searched
                ? const EmptyState(
                    message: 'Nhập tên hoặc email để tìm bạn mới', emoji: '🔍')
                : (_loading
                    ? const LoadingWidget()
                    : (_results.isEmpty
                        ? const EmptyState(
                            message: 'Không tìm thấy ai', emoji: '🙈')
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final u = _results[i];
                              return ListTile(
                                leading: AppAvatar(
                                  avatar: u.avatar,
                                  size: 48,
                                  isOnline: u.isOnline,
                                ),
                                title: Text(u.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    '${u.age} tuổi • ${u.bio ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary)),
                                trailing: const Icon(Icons.chevron_right,
                                    color: AppColors.textSecondary),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PublicProfilePage(
                                        userId: u.id, initial: u),
                                  ),
                                ),
                              );
                            },
                          ))),
          ),
        ],
      ),
    );
  }
}
