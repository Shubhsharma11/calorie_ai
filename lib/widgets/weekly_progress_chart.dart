import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/daily_nutrition.dart';
import '../models/nutrition_trend_metric.dart';
import '../theme/app_colors.dart';
import 'nutrition_metric_selector.dart';

class WeeklyProgressChart extends StatelessWidget {
  const WeeklyProgressChart({
    super.key,
    required this.days,
    required this.metric,
    this.calorieGoal,
    this.onMetricChanged,
    this.showMetricSelector = true,
    this.chartHeight = 140,
  });

  final List<DailyNutrition> days;
  final NutritionTrendMetric metric;
  final int? calorieGoal;
  final ValueChanged<NutritionTrendMetric>? onMetricChanged;
  final bool showMetricSelector;
  final double chartHeight;

  static const double _valueLabelHeight = 18;
  static const double _dayLabelHeight = 22;

  @override
  Widget build(BuildContext context) {
    final values = days.map((d) => d.valueFor(metric)).toList();
    final maxValue = _maxChartValue(values);
    final total = values.fold<double>(0, (sum, v) => sum + v);
    final avg = values.isEmpty ? 0.0 : total / values.length;
    final barAreaHeight = chartHeight - _dayLabelHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showMetricSelector && onMetricChanged != null) ...[
          NutritionMetricSelector(
            selected: metric,
            onChanged: onMetricChanged!,
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: chartHeight,
          child: Column(
            children: [
              SizedBox(
                height: barAreaHeight,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    if (metric == NutritionTrendMetric.calories &&
                        calorieGoal != null &&
                        calorieGoal! > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: (calorieGoal! / maxValue * barAreaHeight)
                            .clamp(0.0, barAreaHeight - 1),
                        child: Container(
                          height: 1.5,
                          color:
                              AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                      ),
                    Positioned.fill(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(days.length, (index) {
                          final day = days[index];
                          final value = values[index];
                          final hasValue = day.hasData && value > 0;
                          final labelHeight =
                              hasValue ? _valueLabelHeight : 0.0;
                          final availableBarHeight =
                              barAreaHeight - labelHeight;
                          final barHeight = maxValue > 0
                              ? (value / maxValue * availableBarHeight).clamp(
                                  day.hasData ? 4.0 : 2.0,
                                  availableBarHeight,
                                )
                              : 2.0;

                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (hasValue)
                                    SizedBox(
                                      height: _valueLabelHeight,
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Text(
                                          _formatValue(value),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                            height: 1,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  SizedBox(
                                    height: barHeight,
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        width: double.infinity,
                                        height: barHeight,
                                        decoration: BoxDecoration(
                                          color: day.hasData
                                              ? _metricColor(metric)
                                              : AppColors.border,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: _dayLabelHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(days.length, (index) {
                    final day = days[index];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Text(
                          DateFormat('E').format(day.date),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.1,
                            fontWeight: _isToday(day.date)
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _isToday(day.date)
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Avg: ${_formatValue(avg)} ${metric.unit}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (metric == NutritionTrendMetric.calories && calorieGoal != null)
              Flexible(
                child: Text(
                  'Goal: $calorieGoal ${metric.unit}',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  double _maxChartValue(List<double> values) {
    var max = values.fold<double>(0, (a, b) => a > b ? a : b);
    if (metric == NutritionTrendMetric.calories &&
        calorieGoal != null &&
        calorieGoal! > max) {
      max = calorieGoal!.toDouble();
    }
    return max > 0 ? max : 1;
  }

  Color _metricColor(NutritionTrendMetric metric) => switch (metric) {
        NutritionTrendMetric.calories => AppColors.primary,
        NutritionTrendMetric.protein => Colors.blue,
        NutritionTrendMetric.carbs => Colors.orange,
        NutritionTrendMetric.fat => Colors.purple,
      };

  String _formatValue(double value) {
    if (metric == NutritionTrendMetric.calories) {
      return value.round().toString();
    }
    return value.toStringAsFixed(0);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
