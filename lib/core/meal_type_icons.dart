import 'package:flutter/material.dart';

import '../models/meal_type.dart';

abstract final class MealTypeIcons {
  static const breakfastSvgAsset = 'assets/image/dawn.svg';
  static const lunchSvgAsset = 'assets/image/contrast.svg';
  static const dinnerSvgAsset = 'assets/image/moon.svg';
  static const snacksSvgAsset = 'assets/image/coffee.svg';

  /// SVG asset for meal types that use custom artwork instead of [IconData].
  static String? svgAssetFor(String meal) {
    return switch (meal) {
      MealType.breakfast => breakfastSvgAsset,
      MealType.lunch => lunchSvgAsset,
      MealType.dinner => dinnerSvgAsset,
      MealType.snacks => snacksSvgAsset,
      _ => null,
    };
  }

  static IconData iconFor(String meal) {
    return switch (meal) {
      MealType.breakfast => Icons.wb_sunny_rounded,
      MealType.lunch => Icons.wb_sunny_outlined,
      MealType.dinner => Icons.nightlight_round,
      MealType.snacks => Icons.local_cafe_rounded,
      _ => Icons.restaurant_rounded,
    };
  }
}
