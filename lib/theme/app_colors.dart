import 'package:flutter/material.dart';

/// App color palette with light and dark variants.
abstract final class AppColors {
  static bool _isDark = false;

  /// Keeps [AppColors] getters in sync with the active [ThemeData].
  static void syncWithBrightness(Brightness brightness) {
    _isDark = brightness == Brightness.dark;
  }

  // Brand (shared)
  static const primary = Color(0xFF34C759);
  static const primaryDark = Color(0xFF248A3D);
  static const onPrimary = Color(0xFFFFFFFF);
  static const error = Color(0xFFFF3B30);
  static const errorDark = Color(0xFFFF453A);
  static const selectionText = primary;

  // Light palette
  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFF2F2F7);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightTextPrimary = Color(0xFF1C1C1E);
  static const lightTextSecondary = Color(0xFF8E8E93);
  static const lightBorder = Color(0xFFE5E5EA);

  // Dark palette
  static const darkBackground = Color(0xFF000000);
  static const darkSurface = Color(0xFF1C1C1E);
  static const darkCard = Color(0xFF1C1C1E);
  static const darkTextPrimary = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFF8E8E93);
  static const darkBorder = Color(0xFF38383A);

  static Color get background =>
      _isDark ? darkBackground : lightBackground;

  static Color get surface => _isDark ? darkSurface : lightSurface;

  static Color get textPrimary =>
      _isDark ? darkTextPrimary : lightTextPrimary;

  static Color get textSecondary =>
      _isDark ? darkTextSecondary : lightTextSecondary;

  static Color get border => _isDark ? darkBorder : lightBorder;

  static Color get card => _isDark ? darkCard : lightCard;

  /// Soft green fill used for selected chips, cards, and tabs.
  static Color get selectionFill =>
      primary.withValues(alpha: _isDark ? 0.22 : 0.15);

  /// Border accent on selected interactive items.
  static Color get selectionBorder => primary.withValues(alpha: 0.35);

  /// Subtle shadow / overlay tint that works in both themes.
  static Color get shadowColor => _isDark
      ? Colors.black.withValues(alpha: 0.35)
      : Colors.black.withValues(alpha: 0.04);

  static Color get dialogBarrier =>
      _isDark ? Colors.black87 : Colors.black54;
}
