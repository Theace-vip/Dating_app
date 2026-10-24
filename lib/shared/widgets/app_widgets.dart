import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:dating_app/core/constants/app_config.dart';
import 'package:dating_app/core/theme/app_theme.dart';

/// true nếu giá trị là URL ảnh (http... hoặc /uploads/...) thay vì emoji.
bool isNetworkAvatar(String avatar) =>
    avatar.startsWith('http') || avatar.startsWith('/uploads/');

class AppAvatar extends StatelessWidget {
  final String avatar; // emoji hoặc url
  final double size;
  final bool isOnline;
  final String? vipFrame;
  final bool isUrl;

  const AppAvatar({
    super.key,
    required this.avatar,
    this.size = 48,
    this.isOnline = false,
    this.vipFrame,
    this.isUrl = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: vipFrame != null ? AppColors.primaryGradient : null,
            color: vipFrame == null ? AppColors.bubbleOther : null,
          ),
          padding: vipFrame != null
              ? const EdgeInsets.all(2)
              : EdgeInsets.zero,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            alignment: Alignment.center,
            child: isUrl || isNetworkAvatar(avatar)
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: AppConfig.absoluteUrl(avatar),
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                      placeholder: (_, _) => const SizedBox.shrink(),
                      errorWidget: (_, _, _) =>
                          Text('🙂', style: TextStyle(fontSize: size * 0.5)),
                    ),
                  )
                : Text(avatar, style: TextStyle(fontSize: size * 0.5)),
          ),
        ),
        if (vipFrame != null)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
              ),
              padding: const EdgeInsets.all(2),
              child: Text(vipFrame!, style: TextStyle(fontSize: size * 0.22)),
            ),
          ),
        if (isOnline)
          Positioned(
            bottom: size * 0.05,
            right: size * 0.05,
            child: Container(
              width: size * 0.26,
              height: size * 0.26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.online,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isGradient;
  final bool outline;
  final double height;
  final Widget? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isGradient = true,
    this.outline = false,
    this.height = 52,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 8)],
        Text(label,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
      ],
    );

    if (outline) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isGradient ? null : AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
        ),
        child: isGradient
            ? Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: child,
              )
            : child,
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  final String? hint;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final ValueChanged<String>? onChanged;

  const AppTextField({
    super.key,
    this.hint,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.bubbleOther,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final String? emoji;
  const EmptyState({super.key, required this.message, this.emoji});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (emoji != null) Text(emoji!, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
