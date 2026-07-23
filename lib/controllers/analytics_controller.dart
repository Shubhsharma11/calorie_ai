import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../models/daily_nutrition.dart';
import '../models/meal_entry.dart';
import '../models/meal_type.dart';
import '../models/nutrition_trend_metric.dart';
import 'dashboard_controller.dart';
import 'food_controller.dart';

enum AnalyticsPeriod { week, month, year, custom }

/// One swipeable page in the Analytics Nutrition summary card.
class AnalyticsInsightSlide {
  const AnalyticsInsightSlide({
    required this.headline,
    required this.support,
    required this.leftValue,
    required this.leftLabel,
    required this.rightValue,
    required this.rightLabel,
    this.emphasizeLeft = true,
    this.emphasizeRight = true,
  });

  final String headline;
  final String support;
  final String leftValue;
  final String leftLabel;
  final String rightValue;
  final String rightLabel;
  final bool emphasizeLeft;
  final bool emphasizeRight;
}

/// Daily-average calorie share for one meal type in the selected period.
class MealBreakdownSlice {
  const MealBreakdownSlice({
    required this.meal,
    required this.calories,
    required this.count,
    required this.share,
  });

  final String meal;
  /// Average kcal per logged day for this meal type.
  final int calories;
  final int count;
  final double share;
}

extension AnalyticsPeriodInfo on AnalyticsPeriod {
  int get dayCount => switch (this) {
    AnalyticsPeriod.week => 7,
    AnalyticsPeriod.month => 30,
    AnalyticsPeriod.year => 365,
    AnalyticsPeriod.custom => 30,
  };

  String get label => switch (this) {
    AnalyticsPeriod.week => 'Week',
    AnalyticsPeriod.month => 'Month',
    AnalyticsPeriod.year => 'Year',
    AnalyticsPeriod.custom => 'Custom',
  };

  String get title => switch (this) {
    AnalyticsPeriod.week => 'This week',
    AnalyticsPeriod.month => 'This month',
    AnalyticsPeriod.year => 'Last 12 months',
    AnalyticsPeriod.custom => 'Custom range',
  };

  String get comparisonLabel => switch (this) {
    AnalyticsPeriod.week => 'previous week',
    AnalyticsPeriod.month => 'previous month',
    AnalyticsPeriod.year => 'previous year',
    AnalyticsPeriod.custom => 'previous period',
  };

  /// Query value for `GET /api/v1/meals?period=…` (null → use custom dates).
  String? get mealsApiPeriod => switch (this) {
    AnalyticsPeriod.week => '1week',
    AnalyticsPeriod.month => '1month',
    AnalyticsPeriod.year => null,
    AnalyticsPeriod.custom => 'custom',
  };
}

class AnalyticsController extends GetxController {
  final Rx<AnalyticsPeriod> period = AnalyticsPeriod.week.obs;
  final Rx<NutritionTrendMetric> trendMetric =
      NutritionTrendMetric.calories.obs;
  final Rx<DateTime> anchorDate = DateTime.now().obs;
  final Rx<DateTime> customStartDate =
      DateTime.now().subtract(const Duration(days: 29)).obs;
  final Rx<DateTime> customEndDate = DateTime.now().obs;

  /// Bumps whenever the visible range changes so macro rings / charts rebuild.
  final RxInt rangeRevision = 0.obs;

  FoodController get _food => Get.find<FoodController>();
  DashboardController get _dash => Get.find<DashboardController>();

  bool _mealsLoadStarted = false;

  /// Prefetch period meals once the Stats tab is visible.
  void ensureMealsLoaded() {
    if (_mealsLoadStarted || isClosed) return;
    _mealsLoadStarted = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      unawaited(_loadMealsForActiveRange());
    });
  }

  Future<void> refreshAll() async {
    await _loadMealsForActiveRange();
  }

  void _markRangeChanged() => rangeRevision.value++;

  Future<void> _loadMealsForActiveRange() async {
    final active = period.value;
    final apiPeriod = active.mealsApiPeriod;
    if (apiPeriod == '1week' || apiPeriod == '1month') {
      await _food.refreshMealsFromApi(period: apiPeriod);
    } else {
      await _food.refreshMealsFromApi(
        period: 'custom',
        fromDate: periodStartDate,
        toDate: periodEndDate,
      );
    }
    _markRangeChanged();
  }

  void setPeriod(AnalyticsPeriod value) {
    period.value = value;
    if (value != AnalyticsPeriod.custom) {
      anchorDate.value = _today;
    }
    _markRangeChanged();
    unawaited(_loadMealsForActiveRange());
  }

  void applyCustomRange(DateTime start, DateTime end) {
    var from = _normalize(start);
    var to = _normalize(end);
    if (to.isBefore(from)) {
      final swap = from;
      from = to;
      to = swap;
    }
    if (to.isAfter(_today)) to = _today;
    customStartDate.value = from;
    customEndDate.value = to;
    period.value = AnalyticsPeriod.custom;
    _markRangeChanged();
    unawaited(_loadMealsForActiveRange());
  }

  void resetCustomRange() {
    customStartDate.value = _today.subtract(const Duration(days: 29));
    customEndDate.value = _today;
  }

  void setTrendMetric(NutritionTrendMetric metric) =>
      trendMetric.value = metric;

  DateTime get _today => _normalize(DateTime.now());

  /// Inclusive end of the visible range.
  DateTime get periodEndDate {
    final today = _today;
    switch (period.value) {
      case AnalyticsPeriod.custom:
        final end = _normalize(customEndDate.value);
        return end.isAfter(today) ? today : end;
      case AnalyticsPeriod.week:
      case AnalyticsPeriod.year:
        final selected = _normalize(anchorDate.value);
        return selected.isAfter(today) ? today : selected;
      case AnalyticsPeriod.month:
        final selected = _normalize(anchorDate.value);
        final monthStart = DateTime(selected.year, selected.month, 1);
        final monthEnd = DateTime(selected.year, selected.month + 1, 0);
        if (monthStart.year == today.year && monthStart.month == today.month) {
          return today;
        }
        return monthEnd.isAfter(today) ? today : monthEnd;
    }
  }

  DateTime get periodStartDate {
    switch (period.value) {
      case AnalyticsPeriod.custom:
        return _normalize(customStartDate.value);
      case AnalyticsPeriod.week:
        return periodEndDate.subtract(const Duration(days: 6));
      case AnalyticsPeriod.month:
        final selected = _normalize(anchorDate.value);
        return DateTime(selected.year, selected.month, 1);
      case AnalyticsPeriod.year:
        return periodEndDate.subtract(const Duration(days: 364));
    }
  }

  bool get showPeriodNavigator => period.value != AnalyticsPeriod.custom;

  bool get canGoNextPeriod {
    switch (period.value) {
      case AnalyticsPeriod.custom:
        return false;
      case AnalyticsPeriod.month:
        final nextMonth = DateTime(
          periodStartDate.year,
          periodStartDate.month + 1,
          1,
        );
        final currentMonth = DateTime(_today.year, _today.month, 1);
        return !nextMonth.isAfter(currentMonth);
      case AnalyticsPeriod.week:
      case AnalyticsPeriod.year:
        return periodEndDate.isBefore(_today);
    }
  }

  void previousPeriod() {
    switch (period.value) {
      case AnalyticsPeriod.custom:
        return;
      case AnalyticsPeriod.week:
        anchorDate.value = periodEndDate.subtract(const Duration(days: 7));
      case AnalyticsPeriod.month:
        final start = periodStartDate;
        anchorDate.value = DateTime(start.year, start.month - 1, 1);
      case AnalyticsPeriod.year:
        anchorDate.value = periodEndDate.subtract(const Duration(days: 365));
    }
    _markRangeChanged();
    unawaited(_loadMealsForActiveRange());
  }

  void nextPeriod() {
    final today = _today;
    switch (period.value) {
      case AnalyticsPeriod.custom:
        return;
      case AnalyticsPeriod.week:
        final next = periodEndDate.add(const Duration(days: 7));
        anchorDate.value = next.isAfter(today) ? today : next;
      case AnalyticsPeriod.month:
        final start = periodStartDate;
        final next = DateTime(start.year, start.month + 1, 1);
        anchorDate.value = next.isAfter(today) ? today : next;
      case AnalyticsPeriod.year:
        final next = periodEndDate.add(const Duration(days: 365));
        anchorDate.value = next.isAfter(today) ? today : next;
    }
    _markRangeChanged();
    unawaited(_loadMealsForActiveRange());
  }

  List<DailyNutrition> get activeDays {
    switch (period.value) {
      case AnalyticsPeriod.week:
        return _food.nutritionForLastDaysEnding(7, endDate: periodEndDate);
      case AnalyticsPeriod.month:
      case AnalyticsPeriod.custom:
        return _daysInRange(periodStartDate, periodEndDate);
      case AnalyticsPeriod.year:
        return _food.nutritionForLastDaysEnding(365, endDate: periodEndDate);
    }
  }

  List<DailyNutrition> get _previousPeriodDays {
    switch (period.value) {
      case AnalyticsPeriod.week:
        return _food.nutritionForLastDaysEnding(
          7,
          endDate: periodStartDate.subtract(const Duration(days: 1)),
        );
      case AnalyticsPeriod.month:
        final start = periodStartDate;
        final prevStart = DateTime(start.year, start.month - 1, 1);
        final prevEnd = DateTime(start.year, start.month, 0);
        return _daysInRange(prevStart, prevEnd);
      case AnalyticsPeriod.year:
        return _food.nutritionForLastDaysEnding(
          365,
          endDate: periodStartDate.subtract(const Duration(days: 1)),
        );
      case AnalyticsPeriod.custom:
        final length =
            periodEndDate.difference(periodStartDate).inDays + 1;
        return _daysInRange(
          periodStartDate.subtract(Duration(days: length)),
          periodStartDate.subtract(const Duration(days: 1)),
        );
    }
  }

  /// Days (or aggregated buckets) for the chart.
  List<DailyNutrition> get chartDays {
    switch (period.value) {
      case AnalyticsPeriod.week:
        return activeDays;
      case AnalyticsPeriod.month:
        return _fourWeekBucketsInMonth(activeDays);
      case AnalyticsPeriod.year:
        return _monthlyBuckets(activeDays);
      case AnalyticsPeriod.custom:
        return _customChartDays(activeDays);
    }
  }

  /// X-axis labels under the chart.
  List<String> get chartBottomLabels {
    switch (period.value) {
      case AnalyticsPeriod.week:
        return chartDays
            .map((day) => DateFormat('E').format(day.date))
            .toList();
      case AnalyticsPeriod.month:
        return _fourWeekLabels(activeDays);
      case AnalyticsPeriod.year:
        return chartDays
            .map((day) => DateFormat('MMM').format(day.date))
            .toList();
      case AnalyticsPeriod.custom:
        return _customChartLabels(chartDays);
    }
  }

  String get chartAggregationLabel => switch (period.value) {
    AnalyticsPeriod.week => 'Daily totals',
    AnalyticsPeriod.month =>
      'Weekly average · ${DateFormat('MMMM yyyy').format(periodStartDate)}',
    AnalyticsPeriod.year => 'Monthly average · last 12 months',
    AnalyticsPeriod.custom => activeDays.length <= 16
        ? 'Daily totals · custom range'
        : 'Weekly average · custom range',
  };

  String get periodTitle {
    if (period.value == AnalyticsPeriod.custom) return 'Custom range';
    if (_isCurrentPeriod) return period.value.title;
    return rangeLabel;
  }

  String get rangeLabel {
    switch (period.value) {
      case AnalyticsPeriod.month:
        return DateFormat('MMMM yyyy').format(periodStartDate);
      case AnalyticsPeriod.custom:
        final start = periodStartDate;
        final end = periodEndDate;
        if (start.year == end.year && start.month == end.month) {
          return '${DateFormat('d').format(start)}–${DateFormat('d MMM').format(end)}';
        }
        return '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM').format(end)}';
      case AnalyticsPeriod.week:
        final start = periodStartDate;
        final end = periodEndDate;
        return '${DateFormat('d').format(start)}–${DateFormat('d MMM').format(end)}';
      case AnalyticsPeriod.year:
        final start = periodStartDate;
        final end = periodEndDate;
        if (start.year == end.year) {
          return '${DateFormat('MMM').format(start)} – ${DateFormat('MMM yyyy').format(end)}';
        }
        return '${DateFormat('MMM yyyy').format(start)} – ${DateFormat('MMM yyyy').format(end)}';
    }
  }

  bool get _isCurrentPeriod {
    switch (period.value) {
      case AnalyticsPeriod.custom:
        return false;
      case AnalyticsPeriod.month:
        return periodStartDate.year == _today.year &&
            periodStartDate.month == _today.month;
      case AnalyticsPeriod.week:
      case AnalyticsPeriod.year:
        return periodEndDate == _today;
    }
  }

  bool get hasAnyData => activeDays.any((d) => d.hasData);

  List<DailyNutrition> get _loggedDaysList =>
      activeDays.where((d) => d.hasData).toList();

  /// Average calories per day across the selected period (empty days = 0).
  /// So Week / Month / Year rings change even when only a few days are logged.
  int get averageCalories {
    final days = activeDays;
    if (days.isEmpty || !days.any((d) => d.hasData)) return 0;
    final total = days.fold(0, (sum, d) => sum + d.calories);
    return total ~/ days.length;
  }

  int get _previousAverageCalories {
    final days = _previousPeriodDays;
    if (days.isEmpty || !days.any((d) => d.hasData)) return 0;
    final total = days.fold(0, (sum, d) => sum + d.calories);
    return total ~/ days.length;
  }

  /// Signed change in avg calories vs the previous period; null without data.
  int? get averageCaloriesDelta {
    final previous = _previousAverageCalories;
    if (previous == 0 || averageCalories == 0) return null;
    return averageCalories - previous;
  }

  double _averageMacro(double Function(DailyNutrition) selector) {
    final days = activeDays;
    if (days.isEmpty || !days.any((d) => d.hasData)) return 0;
    final total = days.fold(0.0, (sum, d) => sum + selector(d));
    return total / days.length;
  }

  double _totalMacro(double Function(DailyNutrition) selector) {
    return activeDays.fold(0.0, (sum, d) => sum + selector(d));
  }

  double get averageProtein => _averageMacro((d) => d.protein);

  double get averageCarbs => _averageMacro((d) => d.carbs);

  double get averageFat => _averageMacro((d) => d.fat);

  double get totalProtein => _totalMacro((d) => d.protein);

  double get totalCarbs => _totalMacro((d) => d.carbs);

  double get totalFat => _totalMacro((d) => d.fat);

  /// Days used for period Need (full week / full month / year / custom length).
  /// For the current month this is still 28–31, not “days so far” (e.g. 20).
  int get periodGoalDays {
    switch (period.value) {
      case AnalyticsPeriod.week:
        return 7;
      case AnalyticsPeriod.month:
        final start = periodStartDate;
        return DateTime(start.year, start.month + 1, 0).day;
      case AnalyticsPeriod.year:
        return 365;
      case AnalyticsPeriod.custom:
        return periodDays;
    }
  }

  /// Period target = daily goal × [periodGoalDays].
  int periodMacroGoal(int dailyGoalG) {
    if (dailyGoalG <= 0 || periodGoalDays <= 0) return 0;
    return dailyGoalG * periodGoalDays;
  }

  String get periodNeedLabel {
    switch (period.value) {
      case AnalyticsPeriod.week:
        return 'Weekly need';
      case AnalyticsPeriod.month:
        return 'Monthly need';
      case AnalyticsPeriod.year:
        return 'Yearly need';
      case AnalyticsPeriod.custom:
        return 'Period need';
    }
  }

  double get selectedMetricAverage {
    final metric = trendMetric.value;
    return _averageMacro((day) => day.valueFor(metric));
  }

  String get selectedMetricAverageLabel {
    final metric = trendMetric.value;
    if (loggedDays == 0) return '—';
    final value = selectedMetricAverage;
    final formatted = metric == NutritionTrendMetric.calories
        ? value.round().toString()
        : value.toStringAsFixed(0);
    return '$formatted ${metric.unit}';
  }

  int get loggedDays => _loggedDaysList.length;

  int get periodDays => activeDays.length;

  int get calorieGoal => _dash.calorieGoal;

  int get daysOnGoal {
    final goal = calorieGoal;
    return activeDays
        .where((d) => d.hasData && (d.calories - goal).abs() <= 150)
        .length;
  }

  /// Percent of logged days that landed within the goal band.
  int get adherencePercent {
    if (loggedDays == 0) return 0;
    return (daysOnGoal / loggedDays * 100).round();
  }

  int get totalMealsLogged => activeDays.fold(0, (sum, d) => sum + d.mealCount);

  bool get isOnTrack => loggedDays > 0 && adherencePercent >= 50;

  /// Short period label for card subtitles (Week / Month / Year / Custom).
  String get periodFocusLabel {
    switch (period.value) {
      case AnalyticsPeriod.week:
        return _isCurrentPeriod ? 'this week' : rangeLabel;
      case AnalyticsPeriod.month:
        return DateFormat('MMMM yyyy').format(periodStartDate);
      case AnalyticsPeriod.year:
        return 'last 12 months';
      case AnalyticsPeriod.custom:
        return rangeLabel;
    }
  }

  String get macroAveragesSubtitle {
    final focus = periodFocusLabel;
    final days = periodGoalDays;
    return '$periodNeedLabel · $focus · $days days';
  }

  /// Daily-average calorie share by meal type for the selected period.
  /// Totals are divided by [loggedDays] so Week / Month / Year / Custom
  /// stay comparable with Average macros.
  List<MealBreakdownSlice> get mealBreakdown {
    final start = periodStartDate;
    final end = periodEndDate;
    final caloriesByMeal = {for (final meal in MealType.all) meal: 0};
    final countByMeal = {for (final meal in MealType.all) meal: 0};
    final days = loggedDays;

    for (final entry in _food.entries) {
      final day = MealEntry.normalizeDate(entry.date);
      if (day.isBefore(start) || day.isAfter(end)) continue;
      final meal = MealType.all.contains(entry.meal)
          ? entry.meal
          : MealType.snacks;
      caloriesByMeal[meal] = caloriesByMeal[meal]! + entry.calories;
      countByMeal[meal] = countByMeal[meal]! + 1;
    }

    final totalCalories =
        caloriesByMeal.values.fold<int>(0, (sum, value) => sum + value);

    return MealType.all.map((meal) {
      final total = caloriesByMeal[meal]!;
      final avg = days > 0 ? (total / days).round() : 0;
      return MealBreakdownSlice(
        meal: meal,
        calories: avg,
        count: countByMeal[meal]!,
        share: totalCalories > 0 ? total / totalCalories : 0,
      );
    }).toList();
  }

  /// Short support line under the insight card headline.
  String get insightSupportText {
    if (loggedDays == 0) {
      return 'Start logging your meals to track your progress.';
    }
    final base =
        'You hit your calorie goal on $daysOnGoal of $loggedDays logged days.';
    final delta = averageCaloriesDelta;
    if (delta == null) return base;
    if (delta.abs() < 50) {
      return '$base Your intake is steady vs the ${period.value.comparisonLabel}.';
    }
    if (delta > 0) {
      return '$base You averaged $delta kcal more than the '
          '${period.value.comparisonLabel}.';
    }
    return '$base You averaged ${delta.abs()} kcal less than the '
        '${period.value.comparisonLabel}.';
  }

  String get _caloriesSupportText {
    if (loggedDays == 0) {
      return 'Average calories will show once you start logging meals.';
    }
    final delta = averageCaloriesDelta;
    if (delta == null) {
      return 'Your average intake for ${periodTitle.toLowerCase()}.';
    }
    if (delta.abs() < 50) {
      return 'Your intake is steady vs the ${period.value.comparisonLabel}.';
    }
    if (delta > 0) {
      return 'You averaged $delta kcal more than the '
          '${period.value.comparisonLabel}.';
    }
    return 'You averaged ${delta.abs()} kcal less than the '
        '${period.value.comparisonLabel}.';
  }

  String get _mealsSupportText {
    if (totalMealsLogged == 0) {
      return 'Log meals to see how consistent your tracking is.';
    }
    return 'You logged $totalMealsLogged meals across $loggedDays of '
        '$periodDays days.';
  }

  /// Swipeable insight pages for the Nutrition summary card.
  List<AnalyticsInsightSlide> get insightSlides {
    final hasLogs = loggedDays > 0;
    final delta = averageCaloriesDelta;
    final deltaLabel = delta == null
        ? '—'
        : delta.abs() < 50
        ? 'Steady'
        : '${delta > 0 ? '+' : '−'}${delta.abs()} kcal';

    return [
      AnalyticsInsightSlide(
        headline: hasLogs ? '$adherencePercent% on goal' : 'No meals logged yet',
        support: insightSupportText,
        leftValue: hasLogs ? '$adherencePercent%' : '—',
        leftLabel: 'Goal adherence',
        rightValue: '$loggedDays/$periodDays',
        rightLabel: 'Days logged',
        emphasizeLeft: hasLogs && adherencePercent > 0,
        emphasizeRight: loggedDays > 0,
      ),
      AnalyticsInsightSlide(
        headline: hasLogs ? '$averageCalories kcal' : 'No average yet',
        support: _caloriesSupportText,
        leftValue: hasLogs ? '$averageCalories' : '—',
        leftLabel: 'Avg calories',
        rightValue: deltaLabel,
        rightLabel: 'Vs ${period.value.comparisonLabel}',
        emphasizeLeft: hasLogs && averageCalories > 0,
        emphasizeRight: delta != null && delta.abs() >= 50,
      ),
      AnalyticsInsightSlide(
        headline: totalMealsLogged > 0
            ? '$totalMealsLogged meals'
            : 'No meals logged',
        support: _mealsSupportText,
        leftValue: '$totalMealsLogged',
        leftLabel: 'Meals logged',
        rightValue: '$loggedDays/$periodDays',
        rightLabel: 'Days logged',
        emphasizeLeft: totalMealsLogged > 0,
        emphasizeRight: loggedDays > 0,
      ),
    ];
  }

  String periodLabelFor(AnalyticsPeriod p) => p.label;

  DailyNutrition _averageBucket(List<DailyNutrition> bucket) {
    final loggedDays = bucket.where((day) => day.hasData).toList();
    final date = bucket.first.date;
    if (loggedDays.isEmpty) return DailyNutrition.empty(date);

    return DailyNutrition(
      date: date,
      calories:
          (loggedDays.fold(0, (sum, day) => sum + day.calories) /
                  loggedDays.length)
              .round(),
      protein:
          loggedDays.fold(0.0, (sum, day) => sum + day.protein) /
          loggedDays.length,
      carbs:
          loggedDays.fold(0.0, (sum, day) => sum + day.carbs) /
          loggedDays.length,
      fat:
          loggedDays.fold(0.0, (sum, day) => sum + day.fat) / loggedDays.length,
      mealCount: loggedDays.fold(0, (sum, day) => sum + day.mealCount),
    );
  }

  List<DailyNutrition> _monthlyBuckets(List<DailyNutrition> days) {
    if (days.isEmpty) {
      final end = periodEndDate;
      return List.generate(12, (index) {
        final month = DateTime(end.year, end.month - 11 + index, 1);
        return DailyNutrition.empty(month);
      });
    }

    final last = days.last.date;
    final startMonth = DateTime(last.year, last.month - 11, 1);
    final buckets = List.generate(12, (_) => <DailyNutrition>[]);

    for (final day in days) {
      final monthIndex =
          (day.date.year - startMonth.year) * 12 +
          (day.date.month - startMonth.month);
      if (monthIndex < 0 || monthIndex > 11) continue;
      buckets[monthIndex].add(day);
    }

    return List.generate(12, (index) {
      final month = DateTime(startMonth.year, startMonth.month + index, 1);
      final bucket = buckets[index];
      if (bucket.isEmpty) return DailyNutrition.empty(month);
      return _averageBucket(bucket);
    });
  }

  /// Always up to 4 weeks: 1–7, 8–14, 15–21, 22–end.
  /// For the current month, future weeks are hidden so labels stay even.
  List<DailyNutrition> _fourWeekBucketsInMonth(List<DailyNutrition> days) {
    final start = periodStartDate;
    return _monthWeekRanges().map((range) {
      final slice = days
          .where(
            (d) => d.date.day >= range.startDay && d.date.day <= range.endDay,
          )
          .toList();
      if (slice.isEmpty) {
        return DailyNutrition.empty(
          DateTime(start.year, start.month, range.startDay),
        );
      }
      return _averageBucket(slice);
    }).toList();
  }

  /// Labels matching [_monthWeekRanges], e.g. 1–7, 8–14, 15–17.
  List<String> _fourWeekLabels(List<DailyNutrition> days) {
    return _monthWeekRanges()
        .map((range) => '${range.startDay}–${range.endDay}')
        .toList();
  }

  /// Calendar week ranges for the full visible month.
  List<({int startDay, int endDay})> _monthWeekRanges() {
    final start = periodStartDate;
    final lastDayOfMonth = DateTime(start.year, start.month + 1, 0).day;

    final ranges = <({int startDay, int endDay})>[];
    for (var weekIndex = 0; weekIndex < 4; weekIndex++) {
      final rangeStart = 1 + weekIndex * 7;
      final idealEnd = weekIndex == 3
          ? lastDayOfMonth
          : (rangeStart + 6).clamp(1, lastDayOfMonth);
      ranges.add((startDay: rangeStart, endDay: idealEnd));
    }
    return ranges;
  }

  /// Custom: daily bars for short ranges, weekly averages when longer.
  List<DailyNutrition> _customChartDays(List<DailyNutrition> days) {
    if (days.length <= 16) return days;
    final buckets = <DailyNutrition>[];
    for (var i = 0; i < days.length; i += 7) {
      final end = (i + 7).clamp(0, days.length);
      buckets.add(_averageBucket(days.sublist(i, end)));
    }
    return buckets;
  }

  List<String> _customChartLabels(List<DailyNutrition> buckets) {
    if (activeDays.length <= 16) {
      return buckets.map((day) {
        if (buckets.length <= 7) {
          return DateFormat('E').format(day.date);
        }
        return DateFormat('d').format(day.date);
      }).toList();
    }
    return buckets.map((day) => DateFormat('d MMM').format(day.date)).toList();
  }

  DateTime _normalize(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  List<DailyNutrition> _daysInRange(DateTime start, DateTime end) {
    final days = <DailyNutrition>[];
    var cursor = _normalize(start);
    final last = _normalize(end);
    while (!cursor.isAfter(last)) {
      days.add(_food.nutritionForDate(cursor));
      cursor = cursor.add(const Duration(days: 1));
    }
    return days;
  }
}
