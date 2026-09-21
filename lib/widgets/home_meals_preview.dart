import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/food_controller.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';
import 'meal_type_icon.dart';

/// Home "Today" meals strip: loading / success / empty / error+retry.
///
/// Scoped to the meal section only — never blocks the rest of Home.
class HomeMealsPreview extends StatelessWidget {
  const HomeMealsPreview({
    super.key,
    required this.food,
    required this.viewingToday,
    required this.dateLabel,
    required this.onAddFood,
    required this.onRetry,
  });

  final FoodController food;
  final bool viewingToday;
  final String dateLabel;
  final VoidCallback onAddFood;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Obx(() {
      food.entriesRevision.value;
      food.selectedLogDate.value;
      final loading = food.isLoadingMealsApi.value;
      final completed = food.hasCompletedMealsFetch.value;
      final error = food.mealsApiErrorMessage.value;
      final meals = food.selectedDateMeals;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            viewingToday ? 'Today' : dateLabel,
            style: TextStyle(
              fontSize: r.scale(18, tablet: 19, desktop: 20),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: r.scale(12)),
          if (error != null && !loading)
            _MealsErrorState(message: error, onRetry: onRetry)
          else if ((!completed || loading) && meals.isEmpty)
            const _MealsLoadingState()
          else if (meals.isEmpty)
            _MealsEmptyState(
              viewingToday: viewingToday,
              onAddFood: onAddFood,
            )
          else
            Column(
              children: meals
                  .take(3)
                  .map(
                    (e) => _MealPreview(
                      meal: e.meal,
                      hint: '${e.food.name} · ${e.calories} kcal',
                    ),
                  )
                  .toList(),
            ),
        ],
      );
    });
  }
}

class _MealsLoadingState extends StatelessWidget {
  const _MealsLoadingState();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(18),
        vertical: r.scale(28),
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: r.scale(22),
            height: r.scale(22),
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: r.scale(12)),
          Text(
            'Loading meals…',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: r.scale(13),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MealsErrorState extends StatelessWidget {
  const _MealsErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.scale(18)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: r.scale(42),
                height: r.scale(42),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: r.scale(22),
                ),
              ),
              SizedBox(width: r.scale(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Couldn’t load meals',
                      style: TextStyle(
                        fontSize: r.scale(16),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: r.scale(2)),
                    Text(
                      message,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: r.scale(13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: r.scale(14)),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.45)),
                padding: EdgeInsets.symmetric(vertical: r.scale(12)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  fontSize: r.scale(15),
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

class _MealsEmptyState extends StatelessWidget {
  const _MealsEmptyState({
    required this.viewingToday,
    required this.onAddFood,
  });

  final bool viewingToday;
  final VoidCallback onAddFood;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.all(r.scale(18)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: r.scale(42),
                height: r.scale(42),
                decoration: BoxDecoration(
                  color: AppColors.selectionFill,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  color: AppColors.primary,
                  size: r.scale(22),
                ),
              ),
              SizedBox(width: r.scale(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meals',
                      style: TextStyle(
                        fontSize: r.scale(18),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: r.scale(2)),
                    Text(
                      viewingToday
                          ? 'Tap Add Food to log your first meal today.'
                          : 'Nothing was logged on this day.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: r.scale(13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (viewingToday) ...[
            SizedBox(height: r.scale(16)),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAddFood,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    vertical: r.scale(12),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: Icon(Icons.add_rounded, size: r.scale(18)),
                label: Text(
                  'Add Food',
                  style: TextStyle(
                    fontSize: r.scale(15),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MealPreview extends StatelessWidget {
  const _MealPreview({required this.meal, required this.hint});

  final String meal;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      margin: EdgeInsets.only(bottom: r.scale(10)),
      padding: EdgeInsets.all(r.scale(16)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          MealTypeIcon(meal: meal, size: r.scale(36)),
          SizedBox(width: r.scale(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  hint,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
