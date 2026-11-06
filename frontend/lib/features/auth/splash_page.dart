// splash_page.dart — Màn hình chờ khi mở app.
//
// Vai trò: hiển thị logo trong lúc AuthNotifier khôi phục phiên từ token đã
// lưu; router sẽ tự chuyển sang login hoặc home tuỳ kết quả.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dating_app/core/theme/app_theme.dart';
import 'package:dating_app/data/repositories/auth_repository.dart';

/// Màn hình chờ trong lúc khôi phục phiên đăng nhập từ secure storage.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

/// Chờ khôi phục phiên đăng nhập rồi để router tự điều hướng.
class _SplashPageState extends ConsumerState<SplashPage> {
  Timer? _watchdog;

  // Bắt đầu khôi phục phiên và đặt giới hạn thời gian chờ.
  @override
  void initState() {
    super.initState();
    // Phòng hờ: nếu restore treo quá 8s (mạng chập chờn) -> về màn đăng nhập.
    _watchdog = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      ref.read(authProvider.notifier).forceStopRestore();
    });
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    super.dispose();
  }

  // Logo + hiệu ứng tải.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFFD297B),
                    size: 46,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'SoulMate',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
