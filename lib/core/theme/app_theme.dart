import 'package:flutter/material.dart';

class AppColors {
  // Primary brand (hồng tím - Litmatch style)
  static const Color primary = Color(0xFF7B5BFF);
  static const Color primaryDark = Color(0xFF5A3FD6);
  static const Color accent = Color(0xFFFF5C8A);
  static const Color accentSoft = Color(0xFFFFE3EC);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF9D7BFF), Color(0xFFFF5C8A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient soulGradient = LinearGradient(
    colors: [Color(0xFF7B5BFF), Color(0xFFB07BFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Neutrals
  static const Color background = Color(0xFFF7F7FB);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF8A8AA3);
  static const Color divider = Color(0xFFEDEDF2);

  // Semantic
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFFFB020);
  static const Color error = Color(0xFFFF4D4F);
  static const Color online = Color(0xFF2ECC71);

  // Chat bubbles
  static const Color bubbleMine = Color(0xFF7B5BFF);
  static const Color bubbleOther = Color(0xFFF0F0F6);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.bubbleOther,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
      );
}
