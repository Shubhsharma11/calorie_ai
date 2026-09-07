import 'package:flutter/material.dart';

abstract final class MealTypeIcons {
  static const breakfastSvgAsset = 'assets/image/dawn.svg';
  static const lunchSvgAsset = 'assets/image/contrast.svg';
  static const dinnerSvgAsset = 'assets/image/moon.svg';
  static const snacksSvgAsset = 'assets/image/coffee.svg';

  /// SVG asset for meal types that use custom artwork instead of [IconData].
  static String? svgAssetFor(String meal) {
    final normalized = meal.toLowerCase();
    if (normalized.contains('breakfast')) return breakfastSvgAsset;
    if (normalized.contains('lunch')) return lunchSvgAsset;
    if (normalized.contains('dinner')) return dinnerSvgAsset;
    if (normalized.contains('snack')) return snacksSvgAsset;
    return null;
  }

  static IconData iconFor(String meal) {
    final normalized = meal.toLowerCase();
    if (normalized.contains('breakfast')) return Icons.wb_sunny_rounded;
    if (normalized.contains('lunch')) return Icons.wb_sunny_outlined;
    if (normalized.contains('dinner')) return Icons.nightlight_round;
    if (normalized.contains('snack')) return Icons.local_cafe_rounded;
    return Icons.restaurant_rounded;
  }
}
