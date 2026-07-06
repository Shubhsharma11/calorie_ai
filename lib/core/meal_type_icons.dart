import 'package:flutter/material.dart';

import '../models/meal_type.dart';

abstract final class MealTypeIcons {
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
