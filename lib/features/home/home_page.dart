import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/network/connectivity_service.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/repositories/catalog_repository.dart';
import 'package:dating_app/data/repositories/chat_repository.dart';
import 'package:dating_app/features/chat/chat_list_page.dart';
import 'package:dating_app/features/feed/feed_page.dart';
import 'package:dating_app/features/room/room_list_page.dart';
import 'package:dating_app/features/profile/profile_page.dart';
import 'package:dating_app/features/matching/soul_game_page.dart';
import 'package:dating_app/features/matching/voice_game_page.dart';

/// Khung chính sau khi đăng nhập: 5 tab (chat, khám phá, feed, phòng, cá nhân).
/// Dùng IndexedStack để giữ state/scroll của từng tab khi chuyển qua lại;
/// dữ liệu nền được tải một lần và feed realtime được đăng ký tại đây.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;

  // Giữ nguyên instance của từng tab; IndexedStack chỉ ẩn/hiện thay vì dựng lại.
  final List<Widget> _pages = const [
    ChatListPage(),
    ExplorePage(),
    FeedPage(),
    RoomListPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    // Tải dữ liệu thật từ server một lần cho cả phiên làm việc.
    // feedRealtimeProvider lắng nghe socket để cập nhật bài viết/số đếm từ thiết bị khác.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(chatProvider.notifier).load();
      ref.read(feedProvider.notifier).load();
      ref.read(roomsProvider.notifier).load();
      // Kích hoạt lắng nghe feed realtime (đăng 1 lần cho cả phiên)
      ref.read(feedRealtimeProvider);
    });
  }

  // ===== Khung giao diện: appbar mạng, nội dung tab và bottom navigation =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'SoulMate',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              ref.watch(connectionTypeLabelProvider),
              key: const ValueKey('net-type'),
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          const NetworkBanner(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: AppColors.surface,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Tin nhắn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Khám phá mới',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline_outlined),
            activeIcon: Icon(Icons.timeline),
            label: 'Bảng tin',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: 'Phòng trò chuyện',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Trang cá nhân',
          ),
        ],
      ),
    );
  }
}

// Tab 2: Khám phá (Matching hub)
class ExplorePage extends ConsumerWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(appCatalogProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Khám phá người tâm giao',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Chơi ẩn danh, kết nối chân thành',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 36),
          _GameCard(
            title: 'Trò chơi tâm giao',
            subtitle: catalog.when(
              data: (value) => 'Trò chuyện ẩn danh ${value.textSeconds ~/ 60} phút',
              loading: () => 'Đang tải thời lượng từ máy chủ...',
              error: (_, _) => 'Không tải được cấu hình trò chơi',
            ),
            emoji: '💜',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SoulGamePage()),
            ),
          ),
          const SizedBox(height: 16),
          _GameCard(
            title: 'Trò chơi giọng nói',
            subtitle: catalog.when(
              data: (value) => 'Gọi thoại ẩn danh ${value.voiceSeconds ~/ 60} phút',
              loading: () => 'Đang tải thời lượng từ máy chủ...',
              error: (_, _) => 'Không tải được cấu hình trò chơi',
            ),
            emoji: '🎙️',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VoiceGamePage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emoji;
  final VoidCallback onTap;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 36)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white70, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
