// app_style.dart — Hằng số trình bày dùng lại nhiều nơi.
//
// Vai trò: khoảng cách (AppSpacing), kiểu chữ (AppTextStyle), màu chữ
// (AppColorsText) cho các khối giao diện kiểu mạng xã hội. Không chứa
// logic, chỉ là số đo để các trang nhìn thống nhất.

import 'package:flutter/material.dart';

// Các mức khoảng cách (4/8/12/16/24) dùng thay số thô.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

// Kiểu chữ cho tiêu đề, phụ đề, nội dung bài viết.
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

// Màu chữ theo vai trò (chính, phụ, mờ, nhấn).
class AppColorsText {
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF8A8AA3);
}
