import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../models/custom_meal_preset.dart';
import '../theme/app_colors.dart';

/// Compact Public / Private badge for meal lists and sheets.
class MealVisibilityChip extends StatelessWidget {
  const MealVisibilityChip({
    super.key,
    required this.visibility,
  });

  final MealShareVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final isPublic = visibility == MealShareVisibility.public;
    final color = isPublic ? AppColors.primary : AppColors.textSecondary;

    return Container(
      padding: EdgeInsets.fromLTRB(
        r.scale(7),
        r.scale(3),
        r.scale(8),
        r.scale(3),
      ),
      decoration: BoxDecoration(
        color: isPublic
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
            size: r.scale(12),
            color: color,
          ),
          SizedBox(width: r.scale(4)),
          Text(
            visibility.badgeLabel,
            style: TextStyle(
              fontSize: r.scale(11),
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
