import 'package:flutter/material.dart';

/// App color palette with light and dark variants.
abstract final class AppColors {
  static bool _isDark = false;

  /// Keeps [AppColors] getters in sync with the active [ThemeData].
  static void syncWithBrightness(Brightness brightness) {
    _isDark = brightness == Brightness.dark;
  }

  /// Prefer this at the top of a screen build so [AppColors] matches [Theme].
  static void syncFromContext(BuildContext context) {
    syncWithBrightness(Theme.of(context).brightness);
  }

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? darkTextPrimary : lightTextPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? darkTextSecondary : lightTextSecondary;

  static Color backgroundOf(BuildContext context) =>
      isDark(context) ? darkBackground : lightPageBackground;

  static Color cardOf(BuildContext context) =>
      isDark(context) ? darkCard : lightCard;

  static Color surfaceOf(BuildContext context) =>
      isDark(context) ? darkSurface : lightSurface;

  static Color borderOf(BuildContext context) =>
      isDark(context) ? darkBorder : lightBorder;

  // Brand (shared)
  static const primary = Color(0xFF34C759);
  static const primaryDark = Color(0xFF248A3D);
  static const onPrimary = Color(0xFFFFFFFF);
  static const error = Color(0xFFFF3B30);
  static const errorDark = Color(0xFFFF453A);
  static const warning = Color(0xFFFF9500);
  static const selectionText = primary;

  // Light palette
  /// Soft mint-grey page canvas — cards stay white on top.
  static const lightPageBackground = Color(0xFFF4FAF6);
  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFF2F2F7);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightTextPrimary = Color(0xFF1C1C1E);
  static const lightTextSecondary = Color(0xFF8E8E93);
  static const lightBorder = Color(0xFFE5E5EA);

  // Dark palette — soft greys (Material / iOS style), easier on the eyes than pure black.
  static const darkBackground = Color(0xFF121212);
  static const darkSurface = Color(0xFF1C1C1E);
  static const darkCard = Color(0xFF2C2C2E);
  static const darkTextPrimary = Color(0xFFE8E8ED);
  static const darkTextSecondary = Color(0xFF98989F);
  static const darkBorder = Color(0xFF3A3A3C);
  /// Subtle green-tinted header wash in dark mode (profile, etc.).
  static const darkHeaderWash = Color(0xFF1A231E);

  static Color get background =>
      _isDark ? darkBackground : lightPageBackground;

  static Color get surface => _isDark ? darkSurface : lightSurface;

  static Color get textPrimary =>
      _isDark ? darkTextPrimary : lightTextPrimary;

  static Color get textSecondary =>
      _isDark ? darkTextSecondary : lightTextSecondary;

  static Color get border => _isDark ? darkBorder : lightBorder;

  static Color get card => _isDark ? darkCard : lightCard;

  /// Soft green fill used for selected chips, cards, and tabs.
  static Color get selectionFill =>
      primary.withValues(alpha: _isDark ? 0.16 : 0.15);

  /// Border accent on selected interactive items.
  static Color get selectionBorder => primary.withValues(alpha: 0.35);

  /// Subtle shadow / overlay tint that works in both themes.
  static Color get shadowColor => _isDark
      ? Colors.black.withValues(alpha: 0.22)
      : Colors.black.withValues(alpha: 0.04);

  /// Icon accent on dark surfaces — brighter green for legibility.
  static Color get iconAccent => _isDark ? primary : primaryDark;

  static Color get dialogBarrier =>
      _isDark ? Colors.black87 : Colors.black54;
}
