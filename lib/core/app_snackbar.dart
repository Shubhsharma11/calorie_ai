import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';

/// App-wide toast helper — same top snackbar on every screen.
abstract final class AppSnackbar {
  static DateTime? _lastShownAt;
  static String? _lastFingerprint;
  static const _dedupeWindow = Duration(milliseconds: 900);

  static void success(String message, {String? title}) {
    _show(
      title: title,
      message: message,
      icon: Icons.check_circle_rounded,
      accent: AppColors.primary,
    );
  }

  static void error(String message, {String? title}) {
    _show(
      title: title,
      message: message,
      icon: Icons.error_rounded,
      accent: AppColors.error,
    );
  }

  static void info(String message, {String? title}) {
    _show(
      title: title,
      message: message,
      icon: Icons.info_rounded,
      accent: AppColors.primaryDark,
    );
  }

  static void _show({
    required String? title,
    required String message,
    required IconData icon,
    required Color accent,
  }) {
    final fingerprint = '${title ?? ''}|$message|$icon';
    final now = DateTime.now();
    if (_lastFingerprint == fingerprint &&
        _lastShownAt != null &&
        now.difference(_lastShownAt!) < _dedupeWindow) {
      return;
    }
    _lastFingerprint = fingerprint;
    _lastShownAt = now;

    // Never stack toasts — replace whatever is already visible.
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }

    final hasTitle = title != null && title.trim().isNotEmpty;

    Get.rawSnackbar(
      titleText: hasTitle
          ? Text(
              title.trim(),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
      messageText: Text(
        message,
        style: TextStyle(
          color: hasTitle ? AppColors.textSecondary : AppColors.textPrimary,
          fontSize: hasTitle ? 13 : 14,
          fontWeight: hasTitle ? FontWeight.w500 : FontWeight.w600,
          height: 1.3,
        ),
      ),
      icon: Icon(icon, color: accent, size: 26),
      backgroundColor: AppColors.card,
      borderColor: AppColors.border.withValues(alpha: 0.6),
      borderWidth: 1,
      borderRadius: 14,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
      animationDuration: const Duration(milliseconds: 280),
      boxShadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}
