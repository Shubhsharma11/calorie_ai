import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/food_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../models/custom_food_preset.dart';
import '../models/meal_type.dart';
import '../models/saved_meal_item.dart';
import '../theme/app_colors.dart';
import '../widgets/food_emoji_avatar.dart';
import '../widgets/meal_type_chip_row.dart';

/// Shows food details and lets the user pick Breakfast / Lunch / Dinner / Snacks.
Future<void> showLogHistorySheet(
  BuildContext context, {
  required SavedMealItem item,
  String? initialMeal,
  CustomFoodPreset? myFood,
  VoidCallback? onLogged,
}) async {
  final controller = Get.find<FoodController>();
  var selectedMeal = initialMeal ?? item.meal;
  if (!MealType.all.contains(selectedMeal)) {
    selectedMeal = MealType.breakfast;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final r = sheetContext.responsive;

      return StatefulBuilder(
        builder: (context, setState) {
          final food = item.food;
          final calories = item.calories;

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                r.scale(20),
                0,
                r.scale(20),
                r.scale(20) + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add to log',
                    style: TextStyle(
                      fontSize: r.scale(18),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: r.scale(16)),
                  Container(
                    padding: EdgeInsets.all(r.scale(14)),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        FoodEmojiAvatar(
                          emoji: food.emoji,
                          imageUrl: food.imageUrl,
                          size: 52,
                        ),
                        SizedBox(width: r.scale(14)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                food.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: r.scale(16),
                                ),
                              ),
                              SizedBox(height: r.scale(4)),
                              Text(
                                '${item.servingDescription} · $calories kcal',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: r.scale(13),
                                ),
                              ),
                              SizedBox(height: r.scale(6)),
                              Text(
                                'P ${item.protein.toStringAsFixed(0)}g · '
                                'C ${item.carbs.toStringAsFixed(0)}g · '
                                'F ${item.fat.toStringAsFixed(0)}g',
                                style: TextStyle(
                                  fontSize: r.scale(12),
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.scale(18)),
                  Text(
                    'Add to which meal?',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: r.scale(14),
                    ),
                  ),
                  SizedBox(height: r.scale(10)),
                  MealTypeChipRow(
                    selectedMeal: selectedMeal,
                    onSelected: (meal) =>
                        setState(() => selectedMeal = meal),
                  ),
                  SizedBox(height: r.scale(20)),
                  FilledButton(
                    onPressed: () {
                      final meal = selectedMeal;
                      if (myFood != null) {
                        controller.logMyFood(myFood, meal: meal);
                      } else {
                        controller.logFromHistory(
                          item,
                          meal: meal,
                        );
                      }
                      Navigator.pop(sheetContext);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        AppSnackbar.success(
                          '${food.name} added to $meal.',
                          title: 'Logged',
                        );
                        onLogged?.call();
                      });
                    },
                    child: Text('Add to $selectedMeal'),
                  ),
                  SizedBox(height: r.scale(8)),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
