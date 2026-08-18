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
    this.proteinGoal,
    this.carbsGoal,
    this.fatGoal,
    this.onMetricChanged,
    this.showMetricSelector = true,
    this.chartHeight = 140,
    this.bottomLabels,
  });

  final List<DailyNutrition> days;
  final NutritionTrendMetric metric;
  final int? calorieGoal;
  final int? proteinGoal;
  final int? carbsGoal;
  final int? fatGoal;
  final ValueChanged<NutritionTrendMetric>? onMetricChanged;
  final bool showMetricSelector;
  final double chartHeight;

  /// Optional x-axis labels. When null, weekday abbreviations are used.
  final List<String>? bottomLabels;

  static const double _valueLabelHeight = 18;
  static const double _dayLabelHeight = 22;
  // Match Stats weekly bars: slot minus 10px gap, capped at 40px.
  static const double _maxBarWidth = 40;
  static const double _barGap = 10;
  static const double _barRadius = 6;

  int? get _activeGoal {
    final goal = switch (metric) {
      NutritionTrendMetric.calories => calorieGoal,
      NutritionTrendMetric.protein => proteinGoal,
      NutritionTrendMetric.carbs => carbsGoal,
      NutritionTrendMetric.fat => fatGoal,
    };
    if (goal == null || goal <= 0) return null;
    return goal;
  }

  @override
  Widget build(BuildContext context) {
    final values = days.map((d) => d.valueFor(metric)).toList();
    final goal = _activeGoal;
    final maxValue = _maxChartValue(values);
    final total = values.fold<double>(0, (sum, v) => sum + v);
    final avg = values.isEmpty ? 0.0 : total / values.length;
    final barAreaHeight = chartHeight - _dayLabelHeight;
    final showGoalLine =
        goal != null && values.any((v) => v > goal);

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
                    if (showGoalLine)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: (goal / maxValue * barAreaHeight).clamp(
                          0.0,
                          barAreaHeight - 1,
                        ),
                        child: Container(
                          height: 1.5,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                      ),
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final slotCount = days.isEmpty ? 1 : days.length;
                          final slotWidth = constraints.maxWidth / slotCount;
                          final barWidth = (slotWidth - _barGap).clamp(
                            3.0,
                            _maxBarWidth,
                          );

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(days.length, (index) {
                              final day = days[index];
                              final value = values[index];
                              final hasValue = day.hasData && value > 0;
                              final labelHeight = hasValue
                                  ? _valueLabelHeight
                                  : 0.0;
                              final availableBarHeight =
                                  barAreaHeight - labelHeight;
                              final barHeight = maxValue > 0
                                  ? (value / maxValue * availableBarHeight)
                                        .clamp(
                                          day.hasData ? 4.0 : 2.0,
                                          availableBarHeight,
                                        )
                                  : 2.0;

                              return Expanded(
                                key: ValueKey('w-bar-$index-$value'),
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
                                        child: Container(
                                          width: barWidth,
                                          height: barHeight,
                                          decoration: BoxDecoration(
                                            color: day.hasData
                                                ? _metricColor(metric)
                                                : AppColors.border,
                                            borderRadius: BorderRadius.circular(
                                              _barRadius,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          );
                        },
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
                    final customLabel =
                        bottomLabels != null && index < bottomLabels!.length
                        ? bottomLabels![index]
                        : null;
                    final label =
                        customLabel ?? DateFormat('E').format(day.date);
                    final highlightToday =
                        customLabel == null && _isToday(day.date);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: customLabel != null && days.length > 7
                                ? 9
                                : 11,
                            height: 1.1,
                            fontWeight: highlightToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: highlightToday
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Avg  ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: '${_formatValue(avg)} ${metric.unit}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (goal != null)
              Text(
                'Goal  $goal ${metric.unit}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
          ],
        ),
      ],
    );
  }

  double _maxChartValue(List<double> values) {
    // Scale to logged values so bars stay readable when intake is below goal.
    final max = values.fold<double>(0, (a, b) => a > b ? a : b);
    if (max <= 0) return 1;
    return max * 1.08;
  }

  Color _metricColor(NutritionTrendMetric metric) => switch (metric) {
    NutritionTrendMetric.calories => AppColors.primary,
    NutritionTrendMetric.protein => const Color(0xFF2196F3),
    NutritionTrendMetric.carbs => const Color(0xFFFF9500),
    NutritionTrendMetric.fat => const Color(0xFF9C27B0),
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
