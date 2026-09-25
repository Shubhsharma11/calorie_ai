import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../models/planned_meal.dart';
import '../../theme/app_colors.dart';
import '../meal_type_icon.dart';

Future<PlannedMeal?> showSwapMealSheet(
  BuildContext context, {
  required PlannedMeal current,
  required List<PlannedMeal> alternatives,
  required Set<String> suppressedNames,
}) {
  return showModalBottomSheet<PlannedMeal>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      AppColors.syncFromContext(sheetContext);
      return _SwapMealSheet(
        current: current,
        alternatives: alternatives,
        suppressedNames: suppressedNames,
      );
    },
  );
}

class _SwapMealSheet extends StatelessWidget {
  const _SwapMealSheet({
    required this.current,
    required this.alternatives,
    required this.suppressedNames,
  });

  final PlannedMeal current;
  final List<PlannedMeal> alternatives;
  final Set<String> suppressedNames;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final options = alternatives
        .where(
          (m) =>
              m.name.toLowerCase() != current.name.toLowerCase() &&
              !suppressedNames.contains(m.name.toLowerCase()),
        )
        .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.scale(24))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: r.scale(10)),
            Container(
              width: r.scale(40),
              height: r.scale(4),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                r.scale(18),
                r.scale(14),
                r.scale(8),
                r.scale(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.swap_horiz_rounded,
                    color: AppColors.primaryDark,
                    size: r.scale(22),
                  ),
                  SizedBox(width: r.scale(8)),
                  Expanded(
                    child: Text(
                      'Swap this meal',
                      style: TextStyle(
                        fontSize: r.scale(18),
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.scale(18)),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  options.isEmpty
                      ? 'No other options in your plan for this meal yet.'
                      : 'Choose another ${current.mealType.toLowerCase()}. '
                          'We’ll keep your nutrition target in mind.',
                  style: TextStyle(
                    fontSize: r.scale(13),
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            SizedBox(height: r.scale(12)),
            if (options.isEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  r.scale(16),
                  r.scale(8),
                  r.scale(16),
                  r.scale(24),
                ),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(
                    PlannedMeal(
                      id: kMoreOptionsSentinelId,
                      mealType: current.mealType,
                      name: '',
                      timeLabel: current.timeLabel,
                      calories: 0,
                      proteinG: 0,
                      carbsG: 0,
                      fatG: 0,
                      status: current.status,
                      description: '',
                      ingredients: const [],
                      why: '',
                    ),
                  ),
                  child: Text(
                    'Browse more from your week',
                    style: TextStyle(
                      fontSize: r.scale(15),
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              )
            else ...[
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(
                    r.scale(16),
                    0,
                    r.scale(16),
                    r.scale(8),
                  ),
                  itemCount: options.length,
                  separatorBuilder: (_, _) => SizedBox(height: r.scale(10)),
                  itemBuilder: (context, index) {
                    final meal = options[index];
                    return _SwapOptionTile(
                      meal: meal,
                      onSwap: () => Navigator.of(context).pop(meal),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  r.scale(16),
                  r.scale(4),
                  r.scale(16),
                  r.scale(12),
                ),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(
                    PlannedMeal(
                      id: kMoreOptionsSentinelId,
                      mealType: current.mealType,
                      name: '',
                      timeLabel: current.timeLabel,
                      calories: 0,
                      proteinG: 0,
                      carbsG: 0,
                      fatG: 0,
                      status: current.status,
                      description: '',
                      ingredients: const [],
                      why: '',
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Show more options',
                        style: TextStyle(
                          fontSize: r.scale(15),
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      SizedBox(width: r.scale(4)),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primaryDark,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SwapOptionTile extends StatelessWidget {
  const SwapOptionTile({
    super.key,
    required this.meal,
    required this.onSwap,
  });

  final PlannedMeal meal;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) => _SwapOptionTile(meal: meal, onSwap: onSwap);
}

class _SwapOptionTile extends StatelessWidget {
  const _SwapOptionTile({required this.meal, required this.onSwap});

  final PlannedMeal meal;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Container(
      padding: EdgeInsets.all(r.scale(12)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: r.scale(52),
            height: r.scale(52),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
            child: Center(
              child: MealTypeIcon(meal: meal.mealType, size: r.scale(28)),
            ),
          ),
          SizedBox(width: r.scale(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.name,
                  style: TextStyle(
                    fontSize: r.scale(15),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: r.scale(2)),
                Text(
                  '${meal.calories} kcal · ${meal.proteinG}g protein',
                  style: TextStyle(
                    fontSize: r.scale(12),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onSwap,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              padding: EdgeInsets.symmetric(horizontal: r.scale(8)),
            ),
            child: Text(
              'Swap →',
              style: TextStyle(
                fontSize: r.scale(14),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const kMoreOptionsSentinelId = '__more_options__';
