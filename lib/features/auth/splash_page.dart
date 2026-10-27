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

class _SplashPageState extends ConsumerState<SplashPage> {
  Timer? _watchdog;

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
