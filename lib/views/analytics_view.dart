import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../controllers/analytics_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/food_controller.dart';
import '../controllers/user_controller.dart';
import '../core/responsive.dart';
import '../models/daily_nutrition.dart';
import '../models/nutrition_trend_metric.dart';
import '../models/meal_type.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/analytics_custom_date_range_sheet.dart';
import '../widgets/meal_type_icon.dart';
import '../widgets/period_selector.dart';
import '../widgets/responsive_page.dart';

class AnalyticsView extends GetView<AnalyticsController> {
  const AnalyticsView({super.key});

  Future<void> _onPeriodChanged(
    BuildContext context,
    AnalyticsPeriod value,
  ) async {
    if (value == AnalyticsPeriod.custom) {
      await showAnalyticsCustomDateRangeSheet(context);
      return;
    }
    controller.setPeriod(value);
  }

  @override
  Widget build(BuildContext context) {
    controller.ensureMealsLoaded();
    final dash = Get.find<DashboardController>();
    final food = Get.find<FoodController>();
    final r = context.responsive;

    // Keep Obx scopes narrow. A single page-wide Obx that also listens to
    // food.entriesRevision can rebuild Analytics mid-route-push (Weight/Water)
    // and trigger InheritedElement `_dependents.isEmpty` / Duplicate GlobalKeys.
    return RefreshIndicator(
      onRefresh: controller.refreshAll,
      color: AppColors.primary,
      child: ResponsivePage(
        scrollable: true,
        child: Column(
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
            Obx(() {
              final period = controller.period.value;
              return PeriodSelector(
                values: AnalyticsPeriod.values,
                selected: period,
                labelFor: controller.periodLabelFor,
                fontSize: 12,
                onChanged: (value) => _onPeriodChanged(context, value),
              );
            }),
            const SizedBox(height: 20),
            Obx(() {
              food.entriesRevision.value;
              controller.period.value;
              controller.customStartDate.value;
              controller.customEndDate.value;
              return _InsightCard(
                periodTitle: controller.periodTitle,
                isOnTrack: controller.isOnTrack,
                hasData: controller.loggedDays > 0,
                slides: controller.insightSlides,
              );
            }),
            const SizedBox(height: 24),
            Obx(() {
              food.entriesRevision.value;
              final period = controller.period.value;
              final metric = controller.trendMetric.value;
              controller.customStartDate.value;
              controller.customEndDate.value;
              return _NutritionTrendCard(
                metric: metric,
                onMetricChanged: controller.setTrendMetric,
                subtitle: controller.chartAggregationLabel,
                averageLabel: controller.selectedMetricAverageLabel,
                hasData: controller.hasAnyData,
                emptyTitle: controller.periodTitle,
                chartDays: controller.chartDays,
                bottomLabels: controller.chartBottomLabels,
                calorieGoal: dash.calorieGoal,
                proteinGoal: _userGoal((u) => u.proteinGoalG),
                carbsGoal: _userGoal((u) => u.carbsGoalG),
                fatGoal: _userGoal((u) => u.fatGoalG),
                period: period,
                rangeLabel: controller.rangeLabel,
              );
            }),
            const SizedBox(height: 24),
            Obx(() {
              food.entriesRevision.value;
              controller.period.value;
              controller.customStartDate.value;
              controller.customEndDate.value;
              return _MealBreakdownCard(
                periodFocusLabel: controller.periodFocusLabel,
                slices: controller.mealBreakdown,
              );
            }),
            const SizedBox(height: 24),
            Obx(() {
              food.entriesRevision.value;
              controller.period.value;
              controller.anchorDate.value;
              controller.customStartDate.value;
              controller.customEndDate.value;
              controller.rangeRevision.value;
              final rangeKey =
                  '${controller.period.value.name}_'
                  '${controller.periodStartDate.toIso8601String()}_'
                  '${controller.periodEndDate.toIso8601String()}_'
                  '${controller.rangeRevision.value}';
              final proteinDaily = _userGoal((u) => u.proteinGoalG);
              final carbsDaily = _userGoal((u) => u.carbsGoalG);
              final fatDaily = _userGoal((u) => u.fatGoalG);
              return _MacroAveragesCard(
                key: ValueKey(rangeKey),
                periodFocusLabel: controller.macroAveragesSubtitle,
                protein: controller.totalProtein,
                carbs: controller.totalCarbs,
                fat: controller.totalFat,
                proteinGoal: controller.periodMacroGoal(proteinDaily),
                carbsGoal: controller.periodMacroGoal(carbsDaily),
                fatGoal: controller.periodMacroGoal(fatDaily),
              );
            }),
            const SizedBox(height: 24),
            const Text(
              'Trackers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TrackerCard(
                    svgAsset: 'assets/image/water_drop.svg',
                    label: 'Water',
                    onTap: () => _openTracker(AppRoutes.waterTracker),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TrackerCard(
                    svgAsset: 'assets/image/gym.svg',
                    label: 'Weight',
                    onTap: () => _openTracker(AppRoutes.weightTracker),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
          ],
        ),
      ),
    );
  }

  /// Defer navigation until after the current frame so an in-flight Obx rebuild
  /// cannot race the route push.
  static void _openTracker(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.toNamed(route);
    });
  }

  static int _userGoal(int Function(dynamic user) selector) {
    if (!Get.isRegistered<UserController>()) return 0;
    return selector(Get.find<UserController>().user);
  }
}

class _NutritionTrendCard extends StatelessWidget {
  const _NutritionTrendCard({
    required this.metric,
    required this.onMetricChanged,
    required this.subtitle,
    required this.averageLabel,
    required this.hasData,
    required this.emptyTitle,
    required this.chartDays,
    required this.bottomLabels,
    required this.calorieGoal,
    required this.proteinGoal,
    required this.carbsGoal,
    required this.fatGoal,
    required this.period,
    required this.rangeLabel,
  });

  final NutritionTrendMetric metric;
  final ValueChanged<NutritionTrendMetric> onMetricChanged;
  final String subtitle;
  final String averageLabel;
  final bool hasData;
  final String emptyTitle;
  final List<DailyNutrition> chartDays;
  final List<String> bottomLabels;
  final int calorieGoal;
  final int proteinGoal;
  final int carbsGoal;
  final int fatGoal;
  final AnalyticsPeriod period;
  final String rangeLabel;

  int get _metricGoal => switch (metric) {
    NutritionTrendMetric.calories => calorieGoal,
    NutritionTrendMetric.protein => proteinGoal,
    NutritionTrendMetric.carbs => carbsGoal,
    NutritionTrendMetric.fat => fatGoal,
  };

  @override
  Widget build(BuildContext context) {
    final points = _buildPoints(chartDays, metric);
    final metricGoal = _metricGoal;
    final showGoal = metricGoal > 0;
    final barColor = _analyticsBarColor(metric);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Chart',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                _AnalyticsMetricPills(
                  selected: metric,
                  onChanged: onMetricChanged,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 180,
                  child: !hasData || points.isEmpty
                      ? _EmptyChartPlaceholder(periodTitle: emptyTitle)
                      : CustomPaint(
                          key: ValueKey(
                            '${period.name}_${metric.name}_$rangeLabel'
                            '${points.map((p) => '${p.slot}:${p.value}').join('|')}',
                          ),
                          painter: _NutritionBarChartPainter(
                            points: points,
                            slotCount: chartDays.length,
                            goalValue: showGoal ? metricGoal.toDouble() : null,
                            barColor: barColor,
                          ),
                          size: Size.infinite,
                        ),
                ),
                if (hasData && bottomLabels.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _DayAxisLabels(
                    labels: bottomLabels,
                    days: chartDays,
                    accent: barColor,
                  ),
                ],
                if (hasData) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Avg: $averageLabel',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (showGoal)
                        Text(
                          'Goal: $metricGoal ${metric.unit}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<_NutritionBarPoint> _buildPoints(
    List<DailyNutrition> days,
    NutritionTrendMetric metric,
  ) {
    if (days.isEmpty) return const [];
    // Keep every day slot (like Weekly Progress) so empty days still get a stub
    // and labels stay aligned — Month won't look like a sparse Week.
    return List.generate(days.length, (i) {
      final day = days[i];
      return _NutritionBarPoint(
        value: day.hasData ? day.valueFor(metric) : 0,
        slot: i,
        hasData: day.hasData,
      );
    });
  }
}

class _DayAxisLabels extends StatelessWidget {
  const _DayAxisLabels({
    required this.labels,
    required this.days,
    required this.accent,
  });

  final List<String> labels;
  final List<DailyNutrition> days;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final count = labels.length;
    if (count == 0) return const SizedBox.shrink();

    // Equal slots (like Weekly Progress) when every bar has a label.
    final allLabeled = labels.every((label) => label.isNotEmpty);
    if (allLabeled && count <= 12) {
      return SizedBox(
        height: 22,
        child: Row(
          children: List.generate(count, (index) {
            final day = index < days.length ? days[index].date : null;
            final isToday =
                day != null &&
                day.year == today.year &&
                day.month == today.month &&
                day.day == today.day;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: count > 8 ? 10 : 11,
                    height: 1.1,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    color: isToday ? accent : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }),
        ),
      );
    }

    return SizedBox(
      height: 22,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final labelWidth = count > 12 ? 44.0 : (count > 8 ? 40.0 : 36.0);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var index = 0; index < count; index++)
                if (labels[index].isNotEmpty)
                  Builder(
                    builder: (context) {
                      final day =
                          index < days.length ? days[index].date : null;
                      final isToday =
                          day != null &&
                          day.year == today.year &&
                          day.month == today.month &&
                          day.day == today.day;
                      final centerX = width * ((index + 0.5) / count);
                      return Positioned(
                        left: (centerX - labelWidth / 2).clamp(
                          0.0,
                          (width - labelWidth).clamp(0.0, width),
                        ),
                        width: labelWidth,
                        child: Text(
                          labels[index],
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: count > 12
                                ? 9
                                : count > 8
                                ? 10
                                : 11,
                            height: 1.1,
                            fontWeight:
                                isToday ? FontWeight.w800 : FontWeight.w600,
                            color: isToday
                                ? accent
                                : AppColors.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _AnalyticsMetricPills extends StatelessWidget {
  const _AnalyticsMetricPills({
    required this.selected,
    required this.onChanged,
  });

  final NutritionTrendMetric selected;
  final ValueChanged<NutritionTrendMetric> onChanged;

  @override
  Widget build(BuildContext context) {
    // Same green button style always — only bars change color (like Home).
    return Row(
      children: NutritionTrendMetric.values.map((metric) {
        final isSelected = metric == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onChanged(metric),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.selectionFill
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.selectionBorder
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    metric.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Same bar colors as Home Weekly Progress chart.
Color _analyticsBarColor(NutritionTrendMetric metric) => switch (metric) {
  NutritionTrendMetric.calories => AppColors.primary,
  NutritionTrendMetric.protein => Colors.blue,
  NutritionTrendMetric.carbs => Colors.orange,
  NutritionTrendMetric.fat => Colors.purple,
};

class _NutritionBarPoint {
  const _NutritionBarPoint({
    required this.value,
    required this.slot,
    required this.hasData,
  });

  final double value;
  final int slot;
  final bool hasData;
}

class _NutritionBarChartPainter extends CustomPainter {
  const _NutritionBarChartPainter({
    required this.points,
    required this.slotCount,
    required this.barColor,
    this.goalValue,
  });

  final List<_NutritionBarPoint> points;
  final int slotCount;
  final Color barColor;
  final double? goalValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || slotCount == 0) return;

    // Full width so each bar sits under its day label (like Weekly Progress).
    const horizontalPadding = 0.0;
    const verticalPadding = 14.0;
    final chartWidth = size.width - horizontalPadding * 2;
    final chartHeight = size.height - verticalPadding * 2;
    final chartRect = Rect.fromLTWH(
      horizontalPadding,
      verticalPadding,
      chartWidth,
      chartHeight,
    );

    final dataValues = points
        .where((p) => p.hasData)
        .map((p) => p.value)
        .toList();
    final dataMax = dataValues.isEmpty
        ? 1.0
        : dataValues.reduce((a, b) => a > b ? a : b);

    // Scale to logged data so bars stay readable. Only pull the scale up to
    // the goal when it's close enough that bars won't shrink into stubs.
    var maxValue = dataMax;
    if (goalValue != null &&
        goalValue! > 0 &&
        goalValue! <= dataMax * 1.5) {
      maxValue = goalValue!;
    }
    if (maxValue <= 0) maxValue = 1;
    maxValue *= 1.18;

    canvas.save();
    canvas.clipRect(chartRect);

    const barTopInset = 28.0;
    const barBottomInset = 8.0;
    final barAreaHeight = chartHeight - barTopInset - barBottomInset;
    final baselineY = chartRect.bottom - barBottomInset;
    final slotWidth = chartWidth / slotCount;
    // Week (~7): comfortable bars. Month (~4) would stretch too wide without a cap.
    final gap = slotCount <= 7 ? 10.0 : (slotCount <= 12 ? 8.0 : 2.5);
    final rawWidth = (slotWidth - gap).clamp(3.0, slotWidth);
    final barWidth = rawWidth.clamp(3.0, 40.0);
    final labelFontSize = slotCount > 14 ? 8.0 : (slotCount > 8 ? 10.0 : 11.0);

    final baselinePaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.9)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(chartRect.left, baselineY),
      Offset(chartRect.right, baselineY),
      baselinePaint,
    );

    if (goalValue != null && goalValue! > 0) {
      // Pin goal to the top of the plot when it's far above current intake.
      final goalFraction = (goalValue! / maxValue).clamp(0.08, 1.0);
      final goalY = baselineY - goalFraction * barAreaHeight;
      final goalPaint = Paint()
        ..color = barColor.withValues(alpha: 0.4)
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke;
      const dash = 5.0;
      var startX = chartRect.left;
      while (startX < chartRect.right) {
        final endX = (startX + dash).clamp(chartRect.left, chartRect.right);
        canvas.drawLine(Offset(startX, goalY), Offset(endX, goalY), goalPaint);
        startX += dash * 2;
      }
    }

    for (final point in points) {
      final centerX =
          chartRect.left + slotWidth * point.slot + slotWidth / 2;
      final barHeight = point.hasData
          ? ((point.value / maxValue) * barAreaHeight).clamp(6.0, barAreaHeight)
          : 5.0;
      final barTop = baselineY - barHeight;

      final barRect = Rect.fromLTWH(
        centerX - barWidth / 2,
        barTop,
        barWidth,
        barHeight,
      );
      final barRRect = RRect.fromRectAndCorners(
        barRect,
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );

      if (!point.hasData) {
        canvas.drawRRect(
          barRRect,
          Paint()..color = AppColors.border.withValues(alpha: 0.7),
        );
        continue;
      }

      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            barColor,
            Color.lerp(barColor, Colors.white, 0.12)!.withValues(alpha: 0.88),
          ],
        ).createShader(barRect);
      canvas.drawRRect(barRRect, barPaint);

      if (point.value <= 0) continue;

      final labelPainter = TextPainter(
        text: TextSpan(
          text: _formatBarValue(point.value),
          style: TextStyle(
            color: barColor.withValues(alpha: 0.92),
            fontSize: labelFontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(
          centerX - labelPainter.width / 2,
          (barTop - labelPainter.height - 4).clamp(
            chartRect.top,
            baselineY - labelPainter.height,
          ),
        ),
      );
    }

    canvas.restore();
  }

  String _formatBarValue(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    if (value >= 100) return value.round().toString();
    if (value >= 10) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  @override
  bool shouldRepaint(covariant _NutritionBarChartPainter oldDelegate) {
    if (oldDelegate.goalValue != goalValue ||
        oldDelegate.slotCount != slotCount ||
        oldDelegate.barColor != barColor) {
      return true;
    }
    if (oldDelegate.points.length != points.length) return true;
    for (var i = 0; i < points.length; i++) {
      if (oldDelegate.points[i].value != points[i].value ||
          oldDelegate.points[i].slot != points[i].slot ||
          oldDelegate.points[i].hasData != points[i].hasData) {
        return true;
      }
    }
    return false;
  }
}

class _InsightCard extends StatefulWidget {
  const _InsightCard({
    required this.periodTitle,
    required this.isOnTrack,
    required this.hasData,
    required this.slides,
  });

  final String periodTitle;
  final bool isOnTrack;
  final bool hasData;
  final List<AnalyticsInsightSlide> slides;

  @override
  State<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<_InsightCard> {
  final PageController _pageController = PageController();
  int _pageIndex = 0;
  Timer? _autoMoveTimer;

  static const _autoMoveInterval = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _startAutoMove();
  }

  @override
  void dispose() {
    _autoMoveTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoMove() {
    _autoMoveTimer?.cancel();
    if (widget.slides.length < 2) return;
    _autoMoveTimer = Timer.periodic(_autoMoveInterval, (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_pageIndex + 1) % widget.slides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() => _pageIndex = index);
    _startAutoMove();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final status = !widget.hasData
        ? 'No logs yet'
        : widget.isOnTrack
        ? 'On track'
        : 'Needs attention';
    final slides = widget.slides;
    final slide = slides[_pageIndex.clamp(0, slides.length - 1)];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.scale(18, tablet: 20, desktop: 22)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.selectionBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nutrition summary',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      widget.periodTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r.scale(10),
                  vertical: r.scale(6),
                ),
                decoration: BoxDecoration(
                  color: AppColors.selectionFill,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: r.scale(7),
                      height: r.scale(7),
                      decoration: BoxDecoration(
                        color: !widget.hasData
                            ? AppColors.textSecondary
                            : widget.isOnTrack
                            ? const Color(0xFF6EE790)
                            : AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: r.scale(5)),
                    Text(
                      status,
                      style: TextStyle(
                        color: AppColors.iconAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: r.scale(14)),
          SizedBox(
            height: r.scale(88, tablet: 92),
            child: PageView.builder(
              controller: _pageController,
              itemCount: slides.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final page = slides[index];
                final softHeadline = !widget.hasData ||
                    (index == 0 && page.headline.startsWith('0%'));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      page.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r.scale(20, tablet: 22),
                        fontWeight:
                            softHeadline ? FontWeight.w500 : FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: r.scale(4)),
                    Expanded(
                      child: Text(
                        page.support,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: r.scale(10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slides.length, (index) {
              final selected = _pageIndex == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: selected ? 8 : 6,
                height: selected ? 8 : 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary.withValues(alpha: 0.28),
                ),
              );
            }),
          ),
          SizedBox(height: r.scale(14)),
          Divider(height: 1, color: AppColors.border),
          SizedBox(height: r.scale(12)),
          Row(
            children: [
              Expanded(
                child: _InsightMetric(
                  value: slide.leftValue,
                  label: slide.leftLabel,
                  emphasize: slide.emphasizeLeft,
                ),
              ),
              Container(
                width: 1,
                height: r.scale(36),
                color: AppColors.border,
              ),
              Expanded(
                child: _InsightMetric(
                  value: slide.rightValue,
                  label: slide.rightLabel,
                  emphasize: slide.emphasizeRight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightMetric extends StatelessWidget {
  const _InsightMetric({
    required this.value,
    required this.label,
    this.emphasize = true,
  });

  final String value;
  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.iconAccent,
            fontSize: r.scale(20, tablet: 22, desktop: 24),
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            height: 1,
          ),
        ),
        SizedBox(height: r.scale(6)),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _EmptyChartPlaceholder extends StatelessWidget {
  const _EmptyChartPlaceholder({required this.periodTitle});

  final String periodTitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart_rounded,
              size: 36,
              color: AppColors.textSecondary.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 10),
            Text(
              'No meals logged',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Log meals for ${periodTitle.toLowerCase()} to see your trend.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroAveragesCard extends StatelessWidget {
  const _MacroAveragesCard({
    super.key,
    required this.periodFocusLabel,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.proteinGoal,
    required this.carbsGoal,
    required this.fatGoal,
  });

  final String periodFocusLabel;
  final double protein;
  final double carbs;
  final double fat;
  final int proteinGoal;
  final int carbsGoal;
  final int fatGoal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Macros',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            periodFocusLabel,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MacroRing(
                  label: 'Protein',
                  color: Colors.blue,
                  value: protein,
                  goal: proteinGoal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroRing(
                  label: 'Carbs',
                  color: Colors.orange,
                  value: carbs,
                  goal: carbsGoal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroRing(
                  label: 'Fat',
                  color: Colors.purple,
                  value: fat,
                  goal: fatGoal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroRing extends StatelessWidget {
  const _MacroRing({
    required this.label,
    required this.color,
    required this.value,
    required this.goal,
  });

  final String label;
  final Color color;
  final double value;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final progress = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    final percent = goal > 0 ? (value / goal * 100).round() : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final ringSize = constraints.maxWidth.clamp(62.0, 78.0);

        return Column(
          children: [
            SizedBox(
              width: ringSize,
              height: ringSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      backgroundColor: color.withValues(alpha: 0.12),
                      color: color,
                    ),
                  ),
                  Text(
                    percent == null ? '—' : '$percent%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Eaten ${value.round()}g',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              goal > 0 ? 'Need ${goal}g' : 'No goal set',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.95),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MealBreakdownCard extends StatelessWidget {
  const _MealBreakdownCard({
    required this.periodFocusLabel,
    required this.slices,
  });

  final String periodFocusLabel;
  final List<MealBreakdownSlice> slices;

  static Color _colorFor(String meal) => switch (meal) {
    MealType.breakfast => const Color(0xFFFF9500),
    MealType.lunch => const Color(0xFF007AFF),
    MealType.dinner => const Color(0xFFAF52DE),
    MealType.snacks => const Color(0xFF34C759),
    _ => AppColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    final hasData = slices.any((slice) => slice.calories > 0);
    // Keep Breakfast / Lunch / Dinner / Snacks order for the 2×2 grid.
    final ordered = [
      for (final meal in MealType.all)
        slices.firstWhere(
          (slice) => slice.meal == meal,
          orElse: () => MealBreakdownSlice(
            meal: meal,
            calories: 0,
            count: 0,
            share: 0,
          ),
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meal breakdown',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Daily average · $periodFocusLabel',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          if (!hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Log breakfast, lunch, dinner, or snacks to see your split.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MealBreakdownTile(
                        slice: ordered[0],
                        color: _colorFor(ordered[0].meal),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MealBreakdownTile(
                        slice: ordered[1],
                        color: _colorFor(ordered[1].meal),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MealBreakdownTile(
                        slice: ordered[2],
                        color: _colorFor(ordered[2].meal),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MealBreakdownTile(
                        slice: ordered[3],
                        color: _colorFor(ordered[3].meal),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MealBreakdownTile extends StatelessWidget {
  const _MealBreakdownTile({
    required this.slice,
    required this.color,
  });

  final MealBreakdownSlice slice;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = (slice.share * 100).round();
    final mealLabel = slice.count == 1
        ? '1 meal'
        : '${slice.count} meals';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MealTypeIcon(meal: slice.meal, size: 28),
              const Spacer(),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            slice.meal,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${slice.calories} kcal/day',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            mealLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackerCard extends StatelessWidget {
  const _TrackerCard({
    this.icon,
    this.svgAsset,
    required this.label,
    required this.onTap,
  }) : assert(icon != null || svgAsset != null);

  final IconData? icon;
  final String? svgAsset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            children: [
              if (svgAsset != null)
                SizedBox(
                  width: 42,
                  height: 42,
                  child: SvgPicture.asset(
                    svgAsset!,
                    fit: BoxFit.contain,
                  ),
                )
              else
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.selectionFill,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 22),
                ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
