import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';

/// Shared app bar — consistent back button and title across the app.
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({
    super.key,
    required this.title,
    this.actions,
    this.onBack,
    this.centerTitle = true,
    this.automaticallyImplyLeading = true,
  });

  /// Toolbar with only the standard back button (onboarding / setup flows).
  const AppAppBar.backOnly({
    super.key,
    this.onBack,
  })  : title = '',
        actions = null,
        centerTitle = true,
        automaticallyImplyLeading = true;

  final String title;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final bool centerTitle;
  final bool automaticallyImplyLeading;

  static const backIcon = Icons.arrow_back_ios_new_rounded;
  static const backIconSize = 20.0;

  static Widget backButton({
    VoidCallback? onPressed,
    Color? color,
  }) {
    return IconButton(
      onPressed: onPressed ?? () => Get.back<void>(),
      icon: Icon(backIcon, size: backIconSize, color: color),
      tooltip: 'Back',
    );
  }

  static TextStyle titleStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.appBarTheme.titleTextStyle ??
        theme.textTheme.titleLarge?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ) ??
        const TextStyle(fontSize: 17, fontWeight: FontWeight.w700);
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      automaticallyImplyLeading: false,
      leading: automaticallyImplyLeading
          ? backButton(onPressed: onBack)
          : null,
      title: title.isEmpty
          ? null
          : Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: AppColors.textPrimary,
              ),
            ),
      actions: actions,
    );
  }
}

/// Centered header row for bottom sheets — matches [AppAppBar] styling.
class AppSheetHeader extends StatelessWidget {
  const AppSheetHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);

    return Row(
      children: [
        AppAppBar.backButton(onPressed: onBack),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppAppBar.titleStyle(context),
          ),
        ),
        SizedBox(
          width: 48,
          child: trailing ?? const SizedBox.shrink(),
        ),
      ],
    );
  }
}
