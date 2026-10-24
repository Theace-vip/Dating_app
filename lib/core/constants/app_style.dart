import 'package:flutter/material.dart';

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppTextStyle {
  static const TextStyle heading = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColorsText.textPrimary,
  );
  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColorsText.textPrimary,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColorsText.textPrimary,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColorsText.textSecondary,
  );
}

class AppColorsText {
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF8A8AA3);
}
