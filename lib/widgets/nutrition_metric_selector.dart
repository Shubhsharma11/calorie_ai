import 'package:flutter/material.dart';

import '../models/nutrition_trend_metric.dart';
import '../theme/app_colors.dart';

/// Compact text tabs for weekly nutrition metrics.
class NutritionMetricSelector extends StatelessWidget {
  const NutritionMetricSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final NutritionTrendMetric selected;
  final ValueChanged<NutritionTrendMetric> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final metric in NutritionTrendMetric.values)
          Expanded(
            child: _MetricTab(
              label: metric.shortLabel,
              selected: metric == selected,
              onTap: () => onChanged(metric),
            ),
          ),
      ],
    );
  }
}

class _MetricTab extends StatelessWidget {
  const _MetricTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2.5,
              width: selected ? 28 : 0,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
