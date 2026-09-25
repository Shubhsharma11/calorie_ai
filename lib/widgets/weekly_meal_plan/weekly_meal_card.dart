import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../models/planned_meal.dart';
import '../../theme/app_colors.dart';
import '../meal_type_icon.dart';
import 'weekly_meal_macros.dart';

class WeeklyMealPlanCard extends StatelessWidget {
  const WeeklyMealPlanCard({
    super.key,
    required this.meal,
    required this.onSwap,
    required this.onLog,
    required this.onOpenDetail,
    this.onMenu,
    this.compact = false,
  });

  final PlannedMeal meal;
  final VoidCallback onSwap;
  final VoidCallback onLog;
  final VoidCallback onOpenDetail;
  final VoidCallback? onMenu;
  final bool compact;

  bool get _isLogged => meal.status == PlannedMealStatus.completed;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final radius = BorderRadius.circular(r.scale(20));

    return Material(
      color: AppColors.card,
      borderRadius: radius,
      child: InkWell(
        onTap: onOpenDetail,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.all(r.scale(16)),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: radius,
            border: Border.all(
              color: _isLogged
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : AppColors.border.withValues(alpha: 0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MealTypeIcon(meal: meal.mealType, size: r.scale(28)),
                  SizedBox(width: r.scale(8)),
                  Expanded(
                    child: Text(
                      meal.mealType,
                      style: TextStyle(
                        fontSize: r.scale(14),
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Text(
                    meal.timeLabel,
                    style: TextStyle(
                      fontSize: r.scale(13),
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(width: r.scale(4)),
                  IconButton(
                    onPressed: onMenu ?? onOpenDetail,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: r.scale(32),
                      minHeight: r.scale(32),
                    ),
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: r.scale(22),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.scale(8)),
              Text(
                meal.name,
                style: TextStyle(
                  fontSize: r.scale(20),
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
              if (meal.description.trim().isNotEmpty) ...[
                SizedBox(height: r.scale(4)),
                Text(
                  meal.description,
                  style: TextStyle(
                    fontSize: r.scale(13),
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
              if (!compact) ...[
                SizedBox(height: r.scale(14)),
                WeeklyMealMacroPills(meal: meal),
                if (meal.ingredients.isNotEmpty) ...[
                  SizedBox(height: r.scale(16)),
                  WeeklyMealIngredientsList(ingredients: meal.ingredients),
                ],
                if (meal.why.trim().isNotEmpty) ...[
                  SizedBox(height: r.scale(12)),
                  WeeklyMealWhyBox(why: meal.why),
                ],
              ],
              SizedBox(height: r.scale(16)),
              if (_isLogged)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: r.scale(12)),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: r.scale(18),
                        color: AppColors.primaryDark,
                      ),
                      SizedBox(width: r.scale(8)),
                      Text(
                        'Logged',
                        style: TextStyle(
                          fontSize: r.scale(15),
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onSwap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          side: const BorderSide(color: AppColors.primary),
                          padding: EdgeInsets.symmetric(vertical: r.scale(14)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Swap meal',
                          style: TextStyle(
                            fontSize: r.scale(15),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: r.scale(10)),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onLog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: r.scale(14)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Log this meal',
                          style: TextStyle(
                            fontSize: r.scale(15),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
