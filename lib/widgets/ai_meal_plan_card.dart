import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../bindings/home_binding.dart';
import '../controllers/nutrition_plan_controller.dart';
import '../core/app_page_transitions.dart';
import '../core/responsive.dart';
import '../models/meal_type.dart';
import '../theme/app_colors.dart';
import '../views/weekly_meal_plan_view.dart';
import 'meal_type_icon.dart';

/// Promotional AI meal-plan teaser shown on Home below the calorie card.
class AiMealPlanCard extends StatelessWidget {
  const AiMealPlanCard({super.key});

  static const _previewMealType = MealType.lunch;
  static const _previewMealName = 'Oats + Banana + Almonds';
  static const _previewCalories = 420;
  static const _previewProteinG = 20;
  static const _previewTime = '9:30 AM';

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final planController = Get.isRegistered<NutritionPlanController>()
        ? Get.find<NutritionPlanController>()
        : null;

    if (planController == null) {
      return _buildCard(
        context,
        r: r,
        mealType: _previewMealType,
        mealName: _previewMealName,
        calories: _previewCalories,
        proteinG: _previewProteinG,
      );
    }

    return Obx(() {
      final plan = planController.plan.value;
      final _ = planController.revision.value;

      final firstMeal =
          plan?.meals.isNotEmpty == true ? plan!.meals.first : null;
      final mealType = firstMeal?.title.trim().isNotEmpty == true
          ? firstMeal!.title
          : _previewMealType;
      final mealName = firstMeal != null && firstMeal.items.isNotEmpty
          ? firstMeal.items.take(3).join(' + ')
          : _previewMealName;
      final calories = firstMeal != null && firstMeal.calories > 0
          ? firstMeal.calories
          : _previewCalories;
      final proteinG = plan != null && plan.proteinG > 0
          ? (plan.proteinG / (plan.meals.isEmpty ? 4 : plan.meals.length))
              .round()
              .clamp(1, 999)
          : _previewProteinG;

      return _buildCard(
        context,
        r: r,
        mealType: mealType,
        mealName: mealName,
        calories: calories,
        proteinG: proteinG,
      );
    });
  }

  Widget _buildCard(
    BuildContext context, {
    required Responsive r,
    required String mealType,
    required String mealName,
    required int calories,
    required int proteinG,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(r.scale(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/image/meal_bowl.png',
                  width: r.scale(44),
                  height: r.scale(44),
                  fit: BoxFit.contain,
                ),
                SizedBox(width: r.scale(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI-Meal Plan',
                        style: TextStyle(
                          fontSize: r.scale(16),
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: r.scale(2)),
                      Text(
                        'Personalized meals for your goals and taste',
                        style: TextStyle(
                          fontSize: r.scale(12),
                          color: AppColors.textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: r.scale(12)),
            Container(
              padding: EdgeInsets.all(r.scale(12)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.85),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      MealTypeIcon(meal: mealType, size: r.scale(28)),
                      SizedBox(width: r.scale(8)),
                      Expanded(
                        child: Text(
                          mealType,
                          style: TextStyle(
                            fontSize: r.scale(14),
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Text(
                        _previewTime,
                        style: TextStyle(
                          fontSize: r.scale(13),
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: r.scale(18),
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  SizedBox(height: r.scale(10)),
                  Text(
                    mealName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: r.scale(17),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: r.scale(12)),
                  Row(
                    children: [
                      _StatChip(
                        value: '$calories',
                        unit: 'kcal',
                        label: 'Calories',
                      ),
                      SizedBox(width: r.scale(8)),
                      _StatChip(
                        value: '$proteinG',
                        unit: 'g',
                        label: 'Protein',
                      ),
                      const Spacer(),
                      _ViewPlanButton(
                        onPressed: () {
                          Get.to(
                            () => const WeeklyMealPlanView(),
                            binding: HomeBinding(),
                            transition: AppPageTransitions.transition,
                            duration: AppPageTransitions.duration,
                          );
                        },
                      ),
                    ],
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

class _StatChip extends StatelessWidget {
  const _StatChip({
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
        horizontal: r.scale(10),
        vertical: r.scale(8),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: r.scale(14),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: unit,
                  style: TextStyle(
                    fontSize: r.scale(11),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.scale(1)),
          Text(
            label,
            style: TextStyle(
              fontSize: r.scale(11),
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewPlanButton extends StatelessWidget {
  const _ViewPlanButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: AppColors.primary.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(12),
            vertical: r.scale(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'View Plan',
                style: TextStyle(
                  fontSize: r.scale(13),
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              SizedBox(width: r.scale(2)),
              Icon(
                Icons.chevron_right_rounded,
                size: r.scale(16),
                color: AppColors.primaryDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
