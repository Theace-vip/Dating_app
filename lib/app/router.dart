import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dating_app/data/repositories/auth_repository.dart';
import 'package:dating_app/features/auth/login_page.dart';
import 'package:dating_app/features/auth/profile_setup_page.dart';
import 'package:dating_app/features/auth/splash_page.dart';
import 'package:dating_app/features/home/home_page.dart';

/// Navigator cấp root — dùng để push màn hình từ ngoài router
/// (vd: màn hình gọi đến).
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final location = state.matchedLocation;
      final onLogin = location == '/login' || location == '/profile-setup';

      // Đang khôi phục phiên đăng nhập -> màn hình chờ
      if (auth.isRestoring) {
        return location == '/splash' ? null : '/splash';
      }
      // Đã khôi phục xong mà còn ở splash -> chuyển vào màn hình chính
      if (location == '/splash') return '/';

      if (!auth.isLoggedIn && location != '/login') return '/login';
      if (auth.isLoggedIn && !auth.profileCompleted &&
          location != '/profile-setup') {
        return '/profile-setup';
      }
      if (auth.isLoggedIn && auth.profileCompleted && onLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashPage()),
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
      GoRoute(
        path: '/profile-setup',
        builder: (c, s) => const ProfileSetupPage(),
      ),
      GoRoute(path: '/', builder: (c, s) => const HomePage()),
    ],
  );
});
