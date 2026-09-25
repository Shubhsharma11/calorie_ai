import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Cupertino shell for every onboarding screen (not just chrome buttons).
///
/// Uses [CupertinoPageScaffold] + [CupertinoTheme], but forces the app’s
/// Material font family so Android doesn’t paint yellow “missing glyph”
/// underlines from San Francisco (.SF Pro Text).
///
/// Also provides a transparent [Material] ancestor so shared app widgets
/// like [TextField] work inside the Cupertino page.
class OnboardingCupertinoShell extends StatelessWidget {
  const OnboardingCupertinoShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final isDark = AppColors.isDark(context);
    final bg = AppColors.backgroundOf(context);
    final primaryText = AppColors.textPrimaryOf(context);
    final secondaryText = AppColors.textSecondaryOf(context);
    // Avoid Cupertino’s default .SF Pro Text on Android (yellow underlines).
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;

    TextStyle style({
      required double size,
      FontWeight weight = FontWeight.w400,
      Color? color,
      double letterSpacing = -0.4,
      double? height,
    }) {
      return TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: const ['sans-serif', 'Roboto'],
        fontSize: size,
        fontWeight: weight,
        color: color ?? primaryText,
        letterSpacing: letterSpacing,
        height: height,
        decoration: TextDecoration.none,
      );
    }

    return CupertinoTheme(
      data: CupertinoThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primaryColor: AppColors.primary,
        primaryContrastingColor: CupertinoColors.white,
        barBackgroundColor: bg,
        scaffoldBackgroundColor: bg,
        textTheme: CupertinoTextThemeData(
          primaryColor: AppColors.primary,
          textStyle: style(size: 17),
          navTitleTextStyle: style(size: 17, weight: FontWeight.w600),
          navLargeTitleTextStyle: style(
            size: 28,
            weight: FontWeight.w700,
            letterSpacing: -0.6,
            height: 1.15,
          ),
          tabLabelTextStyle: style(
            size: 13,
            weight: FontWeight.w500,
            color: secondaryText,
            letterSpacing: -0.1,
          ),
          actionTextStyle: style(
            size: 17,
            weight: FontWeight.w600,
            color: AppColors.primary,
          ),
          pickerTextStyle: style(size: 22, weight: FontWeight.w500),
          dateTimePickerTextStyle: style(size: 22, weight: FontWeight.w500),
        ),
      ),
      child: DefaultTextStyle(
        style: style(size: 17),
        child: CupertinoPageScaffold(
          backgroundColor: bg,
          child: Material(
            type: MaterialType.transparency,
            child: child,
          ),
        ),
      ),
    );
  }
}
