import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';

/// App-wide toast helper — same top snackbar on every screen.
abstract final class AppSnackbar {
  static void success(String message, {String title = 'Saved'}) {
    _show(
      title: title,
      message: message,
      icon: Icons.check_circle_rounded,
      accent: AppColors.primary,
    );
  }

  static void error(
    String message, {
    String title = 'Something went wrong',
    Duration duration = const Duration(seconds: 2),
  }) {
    _show(
      title: title,
      message: message,
      icon: Icons.error_rounded,
      accent: AppColors.error,
      duration: duration,
    );
  }

  static void info(String message, {String title = 'Heads up'}) {
    _show(
      title: title,
      message: message,
      icon: Icons.info_rounded,
      accent: AppColors.primaryDark,
    );
  }

  static void _show({
    required String title,
    required String message,
    required IconData icon,
    required Color accent,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }

    final context = Get.overlayContext ?? Get.context;
    final topInset = context == null
        ? 12.0
        : MediaQuery.paddingOf(context).top;

    Get.rawSnackbar(
      titleText: Text(
        title,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      messageText: Text(
        message,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.3,
        ),
      ),
      icon: Icon(icon, color: accent, size: 26),
      backgroundColor: AppColors.card,
      borderColor: AppColors.border.withValues(alpha: 0.6),
      borderWidth: 1,
      borderRadius: 14,
      // Clear the status bar / notch — top snackbars otherwise sit under the
      // camera cutout right after logout/login transitions.
      margin: EdgeInsets.fromLTRB(16, topInset + 8, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      snackPosition: SnackPosition.TOP,
      duration: duration,
      animationDuration: const Duration(milliseconds: 350),
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
