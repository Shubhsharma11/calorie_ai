import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/nutrition_plan_controller.dart';
import '../core/responsive.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'meal_type_icon.dart';

/// Home teaser for the AI meal plan — driven by GET `/nutrition/plan`.
class AiMealPlanCard extends StatelessWidget {
  const AiMealPlanCard({super.key});

  static const _fallbackMealType = '';
  static const _fallbackMealName = 'Your meal plan will appear here';
  static const _fallbackCalories = 0;
  static const _fallbackProteinG = 0;
  static const _fallbackTime = '';

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
        mealType: _fallbackMealType,
        mealName: _fallbackMealName,
        calories: _fallbackCalories,
        proteinG: _fallbackProteinG,
        timeLabel: _fallbackTime,
        isLoading: false,
        hasPlan: false,
        isMissing: true,
        errorMessage: null,
        onRetry: null,
      );
    }

    return Obx(() {
      final plan = planController.plan.value;
      final isLoading = planController.isLoading.value;
      final completed = planController.hasCompletedFetch.value;
      final error = planController.errorMessage.value;
      final _ = planController.revision.value;
      final hasPreview = planController.hasHomePreview;
      final showError = error != null && !isLoading;
      final showLoading = isLoading && !hasPreview;
      final showMissing =
          !showError && !showLoading && completed && !hasPreview;

      final preview = plan?.previewMeal;
      final mealType = hasPreview && preview!.title.trim().isNotEmpty
          ? preview.title
          : _fallbackMealType;
      final mealName = hasPreview
          ? preview!.displayName
          : (showLoading
              ? 'Loading your meal plan…'
              : showMissing
                  ? 'No meal plan yet'
                  : _fallbackMealName);
      final calories =
          hasPreview && preview!.calories > 0 ? preview.calories : 0;
      final proteinG =
          hasPreview && preview!.proteinG > 0 ? preview.proteinG : 0;
      final timeLabel =
          hasPreview && preview!.timeLabel?.trim().isNotEmpty == true
              ? preview.timeLabel!.trim()
              : _fallbackTime;

      return _buildCard(
        context,
        r: r,
        mealType: mealType.isEmpty ? 'Meal' : mealType,
        mealName: mealName,
        calories: calories,
        proteinG: proteinG,
        timeLabel: timeLabel,
        isLoading: showLoading,
        hasPlan: hasPreview,
        isMissing: showMissing,
        errorMessage: showError ? error : null,
        onRetry: showError ? planController.retryPlan : null,
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
    required String timeLabel,
    required bool isLoading,
    required bool hasPlan,
    required bool isMissing,
    required String? errorMessage,
    required Future<void> Function()? onRetry,
  }) {
    final subtitle = errorMessage != null
        ? 'Couldn’t load your nutrition plan'
        : hasPlan
            ? 'Personalized meals for your goals and taste'
            : (isLoading
                ? 'Fetching your nutrition plan…'
                : isMissing
                    ? 'Generate a plan to unlock personalized meals'
                    : 'Complete setup to unlock your meal plan');

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
                        subtitle,
                        style: TextStyle(
                          fontSize: r.scale(12),
                          color: errorMessage != null
                              ? AppColors.error
                              : AppColors.textSecondary,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: r.scale(12)),
            if (errorMessage != null)
              _NutritionErrorBlock(
                message: errorMessage,
                onRetry: () {
                  onRetry?.call();
                },
              )
            else
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openWeeklyPlan(),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
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
                            if (timeLabel.isNotEmpty)
                              Text(
                                timeLabel,
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
                        if (isLoading)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: r.scale(8)),
                            child: SizedBox(
                              width: r.scale(22),
                              height: r.scale(22),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        else
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
                              value: calories > 0 ? '$calories' : '—',
                              unit: calories > 0 ? 'kcal' : '',
                              label: 'Calories',
                            ),
                            SizedBox(width: r.scale(8)),
                            _StatChip(
                              value: proteinG > 0 ? '$proteinG' : '—',
                              unit: proteinG > 0 ? 'g' : '',
                              label: 'Protein',
                            ),
                            const Spacer(),
                            _ViewPlanButton(
                              label: isMissing ? 'Generate' : 'View Plan',
                              onPressed: _openWeeklyPlan,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openWeeklyPlan() {
    if (Get.isRegistered<NutritionPlanController>()) {
      Get.find<NutritionPlanController>().loadPlan();
    }
    Get.toNamed(AppRoutes.weeklyMealPlan);
  }
}

class _NutritionErrorBlock extends StatelessWidget {
  const _NutritionErrorBlock({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
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
          Text(
            message,
            style: TextStyle(
              fontSize: r.scale(13),
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          SizedBox(height: r.scale(10)),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.45),
                ),
                padding: EdgeInsets.symmetric(vertical: r.scale(10)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  fontSize: r.scale(14),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
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
                if (unit.isNotEmpty)
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
  const _ViewPlanButton({
    required this.onPressed,
    this.label = 'View Plan',
  });

  final VoidCallback onPressed;
  final String label;

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
                label,
                style: TextStyle(
                  fontSize: r.scale(13),
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              SizedBox(width: r.scale(2)),
              Icon(
                Icons.arrow_forward_rounded,
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
