import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/responsive.dart';
import '../models/planned_meal.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'meal_type_icon.dart';

Future<void> showLogMealPlanDialog(
  BuildContext context, {
  required PlannedMeal meal,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (dialogContext) {
      AppColors.syncFromContext(dialogContext);
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: dialogContext.responsive.scale(20),
          vertical: dialogContext.responsive.scale(24),
        ),
        child: _LogMealPlanDialog(meal: meal),
      );
    },
  );
}

class _LogMealPlanDialog extends StatelessWidget {
  const _LogMealPlanDialog({required this.meal});

  final PlannedMeal meal;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(r.scale(24)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          r.scale(18),
          r.scale(18),
          r.scale(18),
          r.scale(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                MealTypeIcon(meal: meal.mealType, size: r.scale(28)),
                SizedBox(width: r.scale(8)),
                Expanded(
                  child: Text(
                    meal.mealType,
                    style: TextStyle(
                      fontSize: r.scale(15),
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
                Icon(
                  Icons.chevron_right_rounded,
                  size: r.scale(18),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            SizedBox(height: r.scale(12)),
            Text(
              meal.name,
              style: TextStyle(
                fontSize: r.scale(20),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
            SizedBox(height: r.scale(6)),
            Text(
              meal.description,
              style: TextStyle(
                fontSize: r.scale(13),
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            SizedBox(height: r.scale(14)),
            Row(
              children: [
                Expanded(
                  child: _MacroTile(
                    value: '${meal.calories}',
                    unit: 'kcal',
                    label: 'Calories',
                  ),
                ),
                SizedBox(width: r.scale(8)),
                Expanded(
                  child: _MacroTile(
                    value: '${meal.proteinG}',
                    unit: 'g',
                    label: 'Protein',
                  ),
                ),
                SizedBox(width: r.scale(8)),
                Expanded(
                  child: _MacroTile(
                    value: '${meal.carbsG}',
                    unit: 'g',
                    label: 'Carbs',
                  ),
                ),
                SizedBox(width: r.scale(8)),
                Expanded(
                  child: _MacroTile(
                    value: '${meal.fatG}',
                    unit: 'g',
                    label: 'Fat',
                  ),
                ),
              ],
            ),
            SizedBox(height: r.scale(18)),
            Text(
              "What's in this meal",
              style: TextStyle(
                fontSize: r.scale(15),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: r.scale(10)),
            for (final item in meal.ingredients) ...[
              Padding(
                padding: EdgeInsets.only(bottom: r.scale(6)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: r.scale(7)),
                      child: Container(
                        width: r.scale(5),
                        height: r.scale(5),
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    SizedBox(width: r.scale(10)),
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
            SizedBox(height: r.scale(12)),
            Container(
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
                      Icons.auto_awesome_rounded,
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
                          meal.why,
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
            ),
            SizedBox(height: r.scale(16)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      side: BorderSide(color: AppColors.primary),
                      padding: EdgeInsets.symmetric(vertical: r.scale(14)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Not Now',
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
                    onPressed: () {
                      Navigator.of(context).pop();
                      Get.toNamed(AppRoutes.addFood);
                    },
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
    );
  }
}

class _MacroTile extends StatelessWidget {
  const _MacroTile({
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
