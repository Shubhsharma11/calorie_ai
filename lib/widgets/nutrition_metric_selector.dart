import 'package:flutter/material.dart';

import '../models/nutrition_trend_metric.dart';
import 'filter_chip_pill.dart';

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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: NutritionTrendMetric.values.map((metric) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChipPill(
              label: metric.label,
              selected: metric == selected,
              onTap: () => onChanged(metric),
            ),
          );
        }).toList(),
      ),  
    );
  }
}
