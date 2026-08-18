import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../models/meal_type.dart';
import '../theme/app_colors.dart';
import 'app_bottom_sheet.dart';
import 'filter_chip_pill.dart';
import 'meal_type_icon.dart';

/// Breakfast / Lunch / Dinner / Snacks picker in the Gym-style sheet.
Future<String?> showMealTypeSheet({
  required BuildContext context,
  required String selectedMeal,
  String title = 'Add to meal',
}) {
  final current = MealType.all.contains(selectedMeal)
      ? selectedMeal
      : MealType.breakfast;

  return showAppBottomSheet<String>(
    context: context,
    builder: (sheetContext) {
      final r = sheetContext.responsive;

      return AppSheetScaffold(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: r.scale(18),
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: r.scale(16)),
            for (var i = 0; i < MealType.all.length; i++) ...[
              if (i > 0) SizedBox(height: r.scale(8)),
              _MealTypeOptionCard(
                meal: MealType.all[i],
                selected: MealType.all[i] == current,
                onTap: () => Navigator.pop(sheetContext, MealType.all[i]),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _MealTypeOptionCard extends StatelessWidget {
  const _MealTypeOptionCard({
    required this.meal,
    required this.selected,
    required this.onTap,
  });

  final String meal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final radius = BorderRadius.circular(r.scale(10));
    final isDark = AppColors.isDark(context);

    return Material(
      color: isDark ? AppColors.surface : const Color(0xFFF7FBF8),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: r.scale(3),
                  color: AppColors.primary,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      r.scale(12),
                      r.scale(12),
                      r.scale(12),
                      r.scale(12),
                    ),
                    child: Row(
                      children: [
                        MealTypeIcon(meal: meal, size: r.scale(36)),
                        SizedBox(width: r.scale(12)),
                        Expanded(
                          child: Text(
                            meal,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: r.scale(16),
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (selected)
                          Icon(
                            Icons.check_rounded,
                            color: AppColors.primary,
                            size: r.scale(22),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Equal-width Breakfast / Lunch / Dinner / Snacks chips in a single row.
class MealTypeChipRow extends StatelessWidget {
  const MealTypeChipRow({
    super.key,
    required this.selectedMeal,
    required this.onSelected,
  });

  final String selectedMeal;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final gap = r.scale(6);

    return Row(
      children: [
        for (var i = 0; i < MealType.all.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(
            child: FilterChipPill(
              label: MealType.all[i],
              selected: selectedMeal == MealType.all[i],
              onTap: () => onSelected(MealType.all[i]),
              fontSize: r.scale(12),
              expanded: true,
              showCheck: false,
            ),
          ),
        ],
      ],
    );
  }
}
