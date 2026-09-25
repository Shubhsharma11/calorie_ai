import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../models/planned_meal.dart';
import '../../theme/app_colors.dart';
import '../meal_type_icon.dart';
import 'weekly_meal_macros.dart';

Future<void> showMealDetailSheet(
  BuildContext context, {
  required PlannedMeal meal,
  required VoidCallback onSwap,
  required VoidCallback onLog,
  required VoidCallback onDontSuggest,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      AppColors.syncFromContext(sheetContext);
      return _MealDetailSheet(
        meal: meal,
        onSwap: onSwap,
        onLog: onLog,
        onDontSuggest: onDontSuggest,
      );
    },
  );
}

class _MealDetailSheet extends StatelessWidget {
  const _MealDetailSheet({
    required this.meal,
    required this.onSwap,
    required this.onLog,
    required this.onDontSuggest,
  });

  final PlannedMeal meal;
  final VoidCallback onSwap;
  final VoidCallback onLog;
  final VoidCallback onDontSuggest;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final height = MediaQuery.sizeOf(context).height * 0.92;
    final logged = meal.status == PlannedMealStatus.completed;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.scale(24))),
      ),
      child: Column(
        children: [
          SizedBox(
            height: r.scale(220),
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.85),
                        AppColors.primaryDark.withValues(alpha: 0.95),
                      ],
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(r.scale(24)),
                    ),
                  ),
                ),
                Center(
                  child: MealTypeIcon(meal: meal.mealType, size: r.scale(72)),
                ),
                Positioned(
                  top: r.scale(10),
                  left: r.scale(8),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: Colors.white,
                  ),
                ),
                Positioned(
                  top: r.scale(10),
                  right: r.scale(8),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                r.scale(18),
                r.scale(18),
                r.scale(18),
                r.scale(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      MealTypeIcon(meal: meal.mealType, size: r.scale(26)),
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
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: r.scale(10)),
                  Text(
                    meal.name,
                    style: TextStyle(
                      fontSize: r.scale(24),
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  if (meal.description.trim().isNotEmpty) ...[
                    SizedBox(height: r.scale(6)),
                    Text(
                      meal.description,
                      style: TextStyle(
                        fontSize: r.scale(14),
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                  SizedBox(height: r.scale(16)),
                  WeeklyMealMacroPills(meal: meal),
                  if (meal.ingredients.isNotEmpty) ...[
                    SizedBox(height: r.scale(18)),
                    WeeklyMealIngredientsList(
                      ingredients: meal.ingredients,
                      showThumbnails: true,
                    ),
                  ],
                  if (meal.why.trim().isNotEmpty) ...[
                    SizedBox(height: r.scale(14)),
                    WeeklyMealWhyBox(why: meal.why),
                  ],
                  SizedBox(height: r.scale(20)),
                  if (!logged) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onSwap();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryDark,
                              side: const BorderSide(color: AppColors.primary),
                              padding: EdgeInsets.symmetric(
                                vertical: r.scale(14),
                              ),
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
                            onPressed: () {
                              Navigator.of(context).pop();
                              onLog();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                vertical: r.scale(14),
                              ),
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
                    SizedBox(height: r.scale(12)),
                  ],
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDontSuggest();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.do_not_disturb_on_outlined,
                          size: r.scale(18),
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: r.scale(8)),
                        Text(
                          "Don't suggest this meal again",
                          style: TextStyle(
                            fontSize: r.scale(14),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.viewPaddingOf(context).bottom),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
