import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../models/saved_meal_item.dart';
import '../theme/app_colors.dart';
import 'food_emoji_avatar.dart';
import 'media_viewer.dart';

/// Read-only ingredient list for composite / public meals.
class MealIngredientsSection extends StatelessWidget {
  const MealIngredientsSection({
    super.key,
    required this.items,
    this.title = 'Ingredients',
  });

  final List<SavedMealItem> items;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final r = context.responsive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: r.scale(14),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: r.scale(8)),
        ...items.map((item) => _IngredientCard(item: item)),
      ],
    );
  }
}

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({required this.item});

  final SavedMealItem item;

  static const _carbs = Color(0xFF2196F3);
  static const _protein = Color(0xFF4CAF50);
  static const _fat = Color(0xFFE91E63);

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final carbs = item.carbs.round();
    final protein = item.protein.round();
    final fat = item.fat.round();

    return Padding(
      padding: EdgeInsets.only(bottom: r.scale(8)),
      child: Container(
        padding: EdgeInsets.all(r.scale(12)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FoodEmojiAvatar(
                  emoji: item.food.displayEmoji,
                  imageUrl: item.food.imageUrl,
                  size: r.scale(42),
                  onTap: mediaViewerOpener(
                    context: context,
                    imageUrl: item.food.imageUrl,
                    title: item.food.name,
                  ),
                ),
                SizedBox(width: r.scale(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.food.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: r.scale(15),
                          height: 1.2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: r.scale(4)),
                      Text(
                        'Serving · ${item.servingDescription}',
                        style: TextStyle(
                          fontSize: r.scale(11.5),
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: r.scale(10)),
            Container(
              padding: EdgeInsets.symmetric(vertical: r.scale(9)),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _NutritionValue(
                      label: 'Calories',
                      value: '${item.calories}',
                      unit: 'kcal',
                      color: AppColors.primary,
                    ),
                  ),
                  const _NutritionDivider(),
                  Expanded(
                    child: _NutritionValue(
                      label: 'Carbs',
                      value: '$carbs',
                      unit: 'g',
                      color: _carbs,
                    ),
                  ),
                  const _NutritionDivider(),
                  Expanded(
                    child: _NutritionValue(
                      label: 'Protein',
                      value: '$protein',
                      unit: 'g',
                      color: _protein,
                    ),
                  ),
                  const _NutritionDivider(),
                  Expanded(
                    child: _NutritionValue(
                      label: 'Fat',
                      value: '$fat',
                      unit: 'g',
                      color: _fat,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionValue extends StatelessWidget {
  const _NutritionValue({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: r.scale(10),
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: r.scale(3)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: r.scale(13),
                fontWeight: FontWeight.w800,
                color: color,
              ),
              children: [
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: r.scale(9),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NutritionDivider extends StatelessWidget {
  const _NutritionDivider();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Container(
      width: 1,
      height: r.scale(28),
      color: AppColors.border,
    );
  }
}
