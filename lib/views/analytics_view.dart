import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/analytics_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/food_controller.dart';
import '../models/nutrition_trend_metric.dart';
import '../routes/app_routes.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';
import '../widgets/nutrition_metric_selector.dart';
import '../widgets/period_selector.dart';
import '../widgets/responsive_page.dart';
import '../widgets/weekly_progress_chart.dart';

class AnalyticsView extends GetView<AnalyticsController> {
  const AnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final dash = Get.find<DashboardController>();
    final food = Get.find<FoodController>();

    final r = context.responsive;

    return ResponsivePage(
      scrollable: true,
      child: Obx(() {
        final period = controller.period.value;
        final metric = controller.trendMetric.value;
        final _ = food.entriesRevision.value;
        final values = controller.activeValues;
        final maxVal = values
            .fold<double>(0, (a, b) => a > b ? a : b)
            .clamp(1.0, double.infinity)
            .toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics',
              style: TextStyle(
                fontSize: r.scale(24, tablet: 26, desktop: 28),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            PeriodSelector(
              values: AnalyticsPeriod.values,
              selected: period,
              labelFor: controller.periodLabelFor,
              onChanged: controller.setPeriod,
            ),
            const SizedBox(height: 16),
            NutritionMetricSelector(
              selected: metric,
              onChanged: controller.setTrendMetric,
            ),
            const SizedBox(height: 16),
            if (period == AnalyticsPeriod.week)
              WeeklyProgressChart(
                days: controller.activeDays,
                metric: metric,
                calorieGoal: dash.calorieGoal,
                showMetricSelector: false,
                chartHeight: r.scale(180, tablet: 200, desktop: 220),
              )
            else
              _AnalyticsBarChart(
                values: values,
                metric: metric,
                maxValue: maxVal,
                chartHeight: r.scale(180, tablet: 200, desktop: 220),
              ),
            const SizedBox(height: 24),
            _SummaryRow(
              label: 'Avg Calories',
              value: '${controller.averageCalories} kcal',
            ),
            _SummaryRow(
              label: 'Goal Achievement',
              value: '${controller.daysOnGoal}/7 days',
            ),
            _SummaryRow(
              label: 'Meals Logged',
              value: '${controller.totalMealsLogged}',
            ),
            const SizedBox(height: 8),
            Text(
              'Daily goal: ${controller.calorieGoal} kcal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Trackers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ResponsiveLayout(
              mobile: Row(
                children: [
                  Expanded(
                    child: _TrackerCard(
                      icon: Icons.water_drop,
                      label: 'Water',
                      onTap: () => Get.toNamed(AppRoutes.waterTracker),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TrackerCard(
                      icon: Icons.monitor_weight_outlined,
                      label: 'Weight',
                      onTap: () => Get.toNamed(AppRoutes.weightTracker),
                    ),
                  ),
                ],
              ),
              tablet: Row(
                children: [
                  Expanded(
                    child: _TrackerCard(
                      icon: Icons.water_drop,
                      label: 'Water',
                      onTap: () => Get.toNamed(AppRoutes.waterTracker),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _TrackerCard(
                      icon: Icons.monitor_weight_outlined,
                      label: 'Weight',
                      onTap: () => Get.toNamed(AppRoutes.weightTracker),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _AnalyticsBarChart extends StatelessWidget {
  const _AnalyticsBarChart({
    required this.values,
    required this.metric,
    required this.maxValue,
    required this.chartHeight,
  });

  final List<double> values;
  final NutritionTrendMetric metric;
  final double maxValue;
  final double chartHeight;

  static const double _valueLabelHeight = 18;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: chartHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barAreaHeight = constraints.maxHeight - _valueLabelHeight;
          final hasSingleBar = values.length == 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: values.map((value) {
              final barHeight = (value / maxValue * barAreaHeight).clamp(
                4.0,
                barAreaHeight,
              );

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: hasSingleBar ? 0 : 2,
                  ),
                  child: LayoutBuilder(
                    builder: (context, slotConstraints) {
                      final width = hasSingleBar
                          ? 44.0
                          : slotConstraints.maxWidth.clamp(6.0, 18.0);

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: _valueLabelHeight,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Text(
                                value > 0 ? _formatValue(value) : '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: SizedBox(
                              width: width,
                              height: barAreaHeight,
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeOutCubic,
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: _metricColor(metric),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
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
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TrackerCard extends StatelessWidget {
  const _TrackerCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
