import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/responsive.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

/// Compact iOS-only entry point to scientific citations (App Store Guideline 1.4.1).
/// Hidden on Android.
class HealthSourcesLink extends StatelessWidget {
  const HealthSourcesLink({
    super.key,
    this.alignment = MainAxisAlignment.center,
    this.compact = false,
  });

  final MainAxisAlignment alignment;
  final bool compact;

  static bool get isSupported => Platform.isIOS;

  static void open() {
    if (!isSupported) return;
    Get.toNamed(AppRoutes.healthInformationSources);
  }

  @override
  Widget build(BuildContext context) {
    if (!isSupported) return const SizedBox.shrink();

    AppColors.syncFromContext(context);
    final r = context.responsive;
    final labelSize = r.scale(compact ? 12 : 13, tablet: compact ? 13 : 14);

    return TextButton(
      onPressed: open,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: EdgeInsets.symmetric(
          horizontal: r.scale(8),
          vertical: r.scale(compact ? 4 : 8),
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignment,
        children: [
          Icon(Icons.menu_book_outlined, size: r.scale(compact ? 15 : 16)),
          SizedBox(width: r.scale(6)),
          Flexible(
            child: Text(
              'Health information & sources',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: labelSize,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
