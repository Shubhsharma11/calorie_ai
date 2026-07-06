import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/food_controller.dart';
import '../core/app_snackbar.dart';
import '../models/food_item.dart';
import '../models/meal_type.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/food_emoji_avatar.dart';
import '../widgets/filter_chip_pill.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_page.dart';

class FoodDetailsView extends GetView<FoodController> {
  const FoodDetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments;
    if (args is! FoodItem) {
      return Scaffold(
        appBar: AppBar(title: const Text('Food')),
        body: Center(
          child: TextButton(
            onPressed: () => Get.back(),
            child: const Text('Go back'),
          ),
        ),
      );
    }

    final food = args;

    return Scaffold(
      appBar: AppBar(
        title: Text(food.name),
        actions: [
          Obx(() {
            final isFavorite = controller.isFavoriteFood(
              food,
              controller.selectedMeal.value,
            );
            return IconButton(
              onPressed: () async {
                await controller.toggleFavoriteFood(
                  food: food,
                  grams: controller.selectedGrams.value,
                  meal: controller.selectedMeal.value,
                );
                AppSnackbar.success(
                  isFavorite
                      ? 'Removed from quick meals.'
                      : 'Added to quick meals.',
                  title: isFavorite ? 'Removed' : 'Saved',
                );
              },
              icon: Icon(
                isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                color: isFavorite ? const Color(0xFFFFB800) : null,
              ),
            );
          }),
        ],
      ),
      body: ResponsivePage(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: FoodEmojiAvatar(
                emoji: food.emoji,
                size: 120,
                fontSize: 64,
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              final grams = controller.selectedGrams.value;
              final kcal = food.caloriesForGrams(grams);
              return Text(
                '$kcal kcal',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              );
            }),
            const SizedBox(height: 24),
            Obx(() {
              final g = controller.selectedGrams.value;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MacroChip(
                    label: 'Protein',
                    value:
                        '${food.macroForGrams(food.protein, g).toStringAsFixed(1)}g',
                  ),
                  _MacroChip(
                    label: 'Carbs',
                    value:
                        '${food.macroForGrams(food.carbs, g).toStringAsFixed(1)}g',
                  ),
                  _MacroChip(
                    label: 'Fat',
                    value:
                        '${food.macroForGrams(food.fat, g).toStringAsFixed(1)}g',
                  ),
                ],
              );
            }),
            const SizedBox(height: 32),
            const Text(
              'Meal',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Obx(
              () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MealType.all.map((meal) {
                  return FilterChipPill(
                    label: meal,
                    selected: controller.selectedMeal.value == meal,
                    onTap: () => controller.setSelectedMeal(meal),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Quantity (grams)'),
            Obx(
              () => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      if (controller.selectedGrams.value > 50) {
                        controller.selectedGrams.value -= 50;
                      }
                    },
                    icon: Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '${controller.selectedGrams.value}g',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => controller.selectedGrams.value += 50,
                    icon: Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: 'Add to Log',
              onPressed: () {
                controller.addToLog(food);
                if (Get.previousRoute == AppRoutes.addFood) {
                  Get.close(2);
                } else {
                  Get.back();
                }
              },
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
          ],
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
