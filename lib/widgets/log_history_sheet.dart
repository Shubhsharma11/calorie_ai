import 'package:flutter/material.dart';

import '../models/custom_food_preset.dart';
import '../models/saved_meal_item.dart';
import 'app_bottom_sheet.dart';
import 'log_preview_sheet.dart';

/// Shows food details and lets the user pick Breakfast / Lunch / Dinner / Snacks.
Future<void> showLogHistorySheet(
  BuildContext context, {
  required SavedMealItem item,
  String? initialMeal,
  CustomFoodPreset? myFood,
  VoidCallback? onLogged,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => AdjustableFoodLogSheet(
      food: item.foodWithServing,
      initialMeal: initialMeal ?? item.meal,
      historyItem: item,
      myFood: myFood,
      onLogged: onLogged,
    ),
  );
}
