import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../models/planned_meal.dart';
import '../../theme/app_colors.dart';

class WeeklyMealMacroPills extends StatelessWidget {
  const WeeklyMealMacroPills({super.key, required this.meal});

  final PlannedMeal meal;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Row(
      children: [
        Expanded(
          child: _MacroPill(
            value: '${meal.calories}',
            unit: 'kcal',
            label: 'Calories',
          ),
        ),
        SizedBox(width: r.scale(8)),
        Expanded(
          child: _MacroPill(
            value: '${meal.proteinG}',
            unit: 'g',
            label: 'Protein',
          ),
        ),
        SizedBox(width: r.scale(8)),
        Expanded(
          child: _MacroPill(
            value: '${meal.carbsG}',
            unit: 'g',
            label: 'Carbs',
          ),
        ),
        SizedBox(width: r.scale(8)),
        Expanded(
          child: _MacroPill(
            value: '${meal.fatG}',
            unit: 'g',
            label: 'Fat',
          ),
        ),
      ],
    );
  }
}

class _MacroPill extends StatelessWidget {
  const _MacroPill({
    required this.value,
    required this.unit,
    required this.label,
  });

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(6),
        vertical: r.scale(10),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: r.scale(13),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: unit,
                  style: TextStyle(
                    fontSize: r.scale(10),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: r.scale(2)),
          Text(
            label,
            style: TextStyle(
              fontSize: r.scale(10),
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class WeeklyMealWhyBox extends StatelessWidget {
  const WeeklyMealWhyBox({super.key, required this.why});

  final String why;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    if (why.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.all(r.scale(12)),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: r.scale(2)),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              size: r.scale(18),
              color: AppColors.primaryDark,
            ),
          ),
          SizedBox(width: r.scale(8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why this meal?',
                  style: TextStyle(
                    fontSize: r.scale(13),
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                SizedBox(height: r.scale(3)),
                Text(
                  why,
                  style: TextStyle(
                    fontSize: r.scale(12),
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WeeklyMealIngredientsList extends StatelessWidget {
  const WeeklyMealIngredientsList({
    super.key,
    required this.ingredients,
    this.showThumbnails = false,
  });

  final List<String> ingredients;
  final bool showThumbnails;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    if (ingredients.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What's in this meal",
          style: TextStyle(
            fontSize: r.scale(15),
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: r.scale(10)),
        for (final item in ingredients) ...[
          Padding(
            padding: EdgeInsets.only(bottom: r.scale(8)),
            child: Row(
              children: [
                if (showThumbnails)
                  Container(
                    width: r.scale(36),
                    height: r.scale(36),
                    margin: EdgeInsets.only(right: r.scale(10)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      Icons.restaurant_rounded,
                      size: r.scale(16),
                      color: AppColors.primaryDark,
                    ),
                  )
                else
                  Padding(
                    padding: EdgeInsets.only(
                      top: r.scale(7),
                      right: r.scale(10),
                    ),
                    child: Container(
                      width: r.scale(5),
                      height: r.scale(5),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: r.scale(14),
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
