import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../models/meal_type.dart';
import 'filter_chip_pill.dart';

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
