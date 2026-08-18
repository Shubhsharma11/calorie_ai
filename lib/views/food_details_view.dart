import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/food_controller.dart';
import '../core/app_snackbar.dart';
import '../models/food_item.dart';
import '../models/saved_meal_item.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/food_emoji_avatar.dart';
import '../widgets/meal_ingredients_section.dart';
import '../widgets/media_viewer.dart';
import '../widgets/meal_type_chip_row.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_page.dart';
import '../widgets/serving_quantity_stepper.dart';

class FoodDetailsView extends StatefulWidget {
  const FoodDetailsView({super.key});

  @override
  State<FoodDetailsView> createState() => _FoodDetailsViewState();
}

class _FoodDetailsViewState extends State<FoodDetailsView> {
  late final FoodController _controller = Get.find<FoodController>();
  FoodItem? _food;
  double _servingCount = 1;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is FoodItem) {
      _food = args;
      _servingCount =
          args.usesHouseholdServing ? 1 : args.servingQuantity;
    }
  }

  int get _grams => _food?.gramsForServings(_servingCount) ?? 100;

  List<SavedMealItem> get _displayIngredients =>
      _food?.ingredientsForPortions(_servingCount) ?? const [];

  @override
  Widget build(BuildContext context) {
    final food = _food;
    if (food == null) {
      return Scaffold(
        appBar: const AppAppBar(title: 'Food'),
        body: Center(
          child: TextButton(
            onPressed: () => Get.back(),
            child: const Text('Go back'),
          ),
        ),
      );
    }

    final grams = _grams;
    final kcal = food.totalCaloriesForPortions(_servingCount);
    final category = food.category?.trim();

    return Scaffold(
      appBar: AppAppBar(
        title: food.name,
        actions: [
          Obx(() {
            final isFavorite = _controller.isFavoriteFood(food);
            return IconButton(
              onPressed: () async {
                final added = await _controller.toggleFavoriteFood(
                  food: food,
                  grams: grams,
                  meal: _controller.selectedMeal.value,
                );
                if (added == null) return;
                AppSnackbar.success(
                  added
                      ? 'Added to favourites.'
                      : 'Removed from favourites.',
                  title: added ? 'Saved' : 'Removed',
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
                emoji: food.displayEmoji,
                imageUrl: food.imageUrl,
                size: 120,
                fontSize: 64,
                onTap: mediaViewerOpener(
                  context: context,
                  imageUrl: food.imageUrl,
                  title: food.name,
                ),
              ),
            ),
            if (category != null && category.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  category,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              '$kcal kcal',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MacroChip(
                  label: 'Protein',
                  value:
                      '${food.totalProteinForPortions(_servingCount).toStringAsFixed(1)}g',
                ),
                _MacroChip(
                  label: 'Carbs',
                  value:
                      '${food.totalCarbsForPortions(_servingCount).toStringAsFixed(1)}g',
                ),
                _MacroChip(
                  label: 'Fat',
                  value:
                      '${food.totalFatForPortions(_servingCount).toStringAsFixed(1)}g',
                ),
              ],
            ),
            if (food.isCompositeMeal) ...[
              const SizedBox(height: 32),
              MealIngredientsSection(items: _displayIngredients),
            ],
            const SizedBox(height: 32),
            const Text('Meal', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Obx(
              () => MealTypeChipRow(
                selectedMeal: _controller.selectedMeal.value,
                onSelected: _controller.setSelectedMeal,
              ),
            ),
            const SizedBox(height: 24),
            ServingQuantityStepper(
              food: food,
              quantity: _servingCount,
              onChanged: (value) => setState(() => _servingCount = value),
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: 'Add to Log',
              onPressed: () {
                final meal = _controller.selectedMeal.value;
                if (food.isCompositeMeal) {
                  for (final item in food.ingredientsForPortions(_servingCount)) {
                    _controller.logFromHistory(
                      item.copyWith(meal: meal),
                      meal: meal,
                    );
                  }
                } else {
                  _controller.addToLog(food, grams: grams);
                }

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
        Text(label, style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ],
    );
  }
}
