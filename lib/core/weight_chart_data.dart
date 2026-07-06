import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../models/meal_entry.dart';
import '../models/weight_entry.dart';

enum WeightChartPeriod {
  today,
  week,
  twoWeeks,
  month,
  year,
  custom;

  String get label => switch (this) {
        WeightChartPeriod.today => 'Today',
        WeightChartPeriod.week => '1 Week',
        WeightChartPeriod.twoWeeks => '2 Week',
        WeightChartPeriod.month => '1 Month',
        WeightChartPeriod.year => '1 Year',
        WeightChartPeriod.custom => 'Custom',
      };

  String get title => switch (this) {
        WeightChartPeriod.today => 'Today',
        WeightChartPeriod.week => 'Last 7 Days',
        WeightChartPeriod.twoWeeks => 'Last 14 Days',
        WeightChartPeriod.month => 'Last 30 Days',
        WeightChartPeriod.year => 'Last 12 Months',
        WeightChartPeriod.custom => 'Custom Range',
      };

  int? get dayCount => switch (this) {
        WeightChartPeriod.today => 1,
        WeightChartPeriod.week => 7,
        WeightChartPeriod.twoWeeks => 14,
        WeightChartPeriod.month => 30,
        WeightChartPeriod.year => 365,
        WeightChartPeriod.custom => null,
      };

  WeightChartPeriod? get widerAlternative => switch (this) {
        WeightChartPeriod.today => WeightChartPeriod.week,
        WeightChartPeriod.week => WeightChartPeriod.twoWeeks,
        WeightChartPeriod.twoWeeks => WeightChartPeriod.month,
        WeightChartPeriod.month => WeightChartPeriod.year,
        WeightChartPeriod.year => null,
        WeightChartPeriod.custom => null,
      };
}

class WeightChartCustomRange {
  const WeightChartCustomRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;

  int get dayCount => end.difference(start).inDays + 1;

  String formatLabel() {
    final sameYear = start.year == end.year;
    if (start == end) {
      return DateFormat('MMM d, yyyy').format(start);
    }
    if (sameYear) {
      return '${DateFormat('MMM d').format(start)} – '
          '${DateFormat('MMM d, yyyy').format(end)}';
    }
    return '${DateFormat('MMM d, yyyy').format(start)} – '
        '${DateFormat('MMM d, yyyy').format(end)}';
  }
}

class WeightChartAxisTick {
  const WeightChartAxisTick({
    required this.xFraction,
    required this.label,
  });

  final double xFraction;
  final String label;
}

class WeightChartPoint {
  const WeightChartPoint({
    required this.date,
    required this.kg,
    required this.displayWeight,
    required this.xFraction,
    required this.xLabel,
    required this.highlightXLabel,
  });

  final DateTime date;
  final double kg;
  final double displayWeight;
  final double xFraction;
  final String xLabel;
  final bool highlightXLabel;
}

class WeightChartData {
  const WeightChartData({
    required this.period,
    required this.points,
    required this.yAxisTicks,
    required this.xAxisTicks,
    required this.unitLabel,
    required this.useMetricUnits,
    required this.windowStart,
    required this.windowEnd,
    this.usesFallbackWindow = false,
    this.entriesOutsidePeriod = 0,
    this.customRangeLabel,
  });

  final WeightChartPeriod period;
  final List<WeightChartPoint> points;
  final List<double> yAxisTicks;
  final List<WeightChartAxisTick> xAxisTicks;
  final String unitLabel;
  final bool useMetricUnits;
  final DateTime windowStart;
  final DateTime windowEnd;
  final bool usesFallbackWindow;
  final int entriesOutsidePeriod;
  final String? customRangeLabel;

  bool get isEmpty => points.isEmpty;

  bool get hasHiddenEntries => entriesOutsidePeriod > 0;

  WeightChartPeriod? get suggestedPeriod =>
      hasHiddenEntries ? period.widerAlternative : null;

  String? get subtitle {
    if (period == WeightChartPeriod.custom && customRangeLabel != null) {
      return customRangeLabel;
    }
    if (usesFallbackWindow && points.isNotEmpty) {
      return 'Showing your ${points.length} most recent logs';
    }
    if (hasHiddenEntries) {
      final noun = entriesOutsidePeriod == 1 ? 'entry' : 'entries';
      return '$entriesOutsidePeriod $noun outside this range — try ${period.widerAlternative?.label ?? 'View All'}';
    }
    return null;
  }

  List<double> get historyKg => points.map((point) => point.kg).toList();

  double get minY =>
      yAxisTicks.isEmpty ? 0 : yAxisTicks.reduce((a, b) => a < b ? a : b);

  double get maxY =>
      yAxisTicks.isEmpty ? 1 : yAxisTicks.reduce((a, b) => a > b ? a : b);

  static const double _kgToLb = 2.2046226218;

  static double toDisplayWeight(double kg, bool useMetricUnits) {
    return useMetricUnits ? kg : kg * _kgToLb;
  }

  static String weightUnitLabel(bool useMetricUnits) =>
      useMetricUnits ? 'kg' : 'lb';

  static String formatWeight(double kg, bool useMetricUnits) {
    final value = toDisplayWeight(kg, useMetricUnits);
    return '${value.toStringAsFixed(1)} ${weightUnitLabel(useMetricUnits)}';
  }

  static WeightChartData build({
    required List<WeightEntry> entries,
    required WeightChartPeriod period,
    required bool useMetricUnits,
    WeightChartCustomRange? customRange,
    DateTime? now,
  }) {
    final today = MealEntry.normalizeDate(now ?? DateTime.now());
    final window = _resolveWindow(
      period: period,
      today: today,
      customRange: customRange,
    );
    final calendarStart = window.start;
    final calendarEnd = window.end;
    final windowDayCount = calendarEnd.difference(calendarStart).inDays + 1;

    final allValid = _dedupeByDayLatest(
      entries
          .map(
            (entry) => WeightEntry(
              id: entry.id,
              date: MealEntry.normalizeDate(entry.date),
              kg: entry.kg,
            ),
          )
          .where((entry) => !entry.date.isAfter(today))
          .toList(),
    );

    final inCalendarWindow = allValid
        .where(
          (entry) =>
              !entry.date.isBefore(calendarStart) &&
              !entry.date.isAfter(calendarEnd),
        )
        .toList();

    var usesFallbackWindow = false;
    List<WeightEntry> visibleEntries = inCalendarWindow;
    var entriesOutsidePeriod = allValid.length - inCalendarWindow.length;

    if (visibleEntries.isEmpty && allValid.isNotEmpty) {
      usesFallbackWindow = true;
      entriesOutsidePeriod = 0;
      final take = math.min(windowDayCount, allValid.length);
      visibleEntries = allValid.sublist(allValid.length - take);
    }

    final windowStart = usesFallbackWindow
        ? visibleEntries.first.date
        : calendarStart;
    final windowEnd = usesFallbackWindow ? visibleEntries.last.date : calendarEnd;

    final points = _buildPoints(
      entries: visibleEntries,
      windowStart: windowStart,
      windowEnd: windowEnd,
      today: today,
      useMetricUnits: useMetricUnits,
    );

    final displayValues = points.map((point) => point.displayWeight).toList();
    final yAxisTicks = _buildYAxisTicks(displayValues);
    final xAxisTicks = _buildXAxisTicks(
      windowStart: windowStart,
      windowEnd: windowEnd,
      today: today,
      usesFallbackWindow: usesFallbackWindow,
    );

    return WeightChartData(
      period: period,
      points: points,
      yAxisTicks: yAxisTicks,
      xAxisTicks: xAxisTicks,
      unitLabel: weightUnitLabel(useMetricUnits),
      useMetricUnits: useMetricUnits,
      windowStart: windowStart,
      windowEnd: windowEnd,
      usesFallbackWindow: usesFallbackWindow,
      entriesOutsidePeriod: entriesOutsidePeriod,
      customRangeLabel: period == WeightChartPeriod.custom &&
              customRange != null &&
              !usesFallbackWindow
          ? customRange.formatLabel()
          : null,
    );
  }

  static ({DateTime start, DateTime end}) _resolveWindow({
    required WeightChartPeriod period,
    required DateTime today,
    WeightChartCustomRange? customRange,
  }) {
    if (period == WeightChartPeriod.custom) {
      final range = customRange ??
          WeightChartCustomRange(
            start: today.subtract(const Duration(days: 29)),
            end: today,
          );
      var start = MealEntry.normalizeDate(range.start);
      var end = MealEntry.normalizeDate(range.end);
      if (end.isAfter(today)) end = today;
      if (start.isAfter(end)) start = end;
      return (start: start, end: end);
    }

    if (period == WeightChartPeriod.today) {
      return (start: today, end: today);
    }

    final dayCount = period.dayCount ?? 7;
    return (
      start: today.subtract(Duration(days: dayCount - 1)),
      end: today,
    );
  }

  static List<WeightEntry> _dedupeByDayLatest(List<WeightEntry> entries) {
    final byDay = <DateTime, WeightEntry>{};
    for (final entry in entries) {
      byDay[entry.date] = entry;
    }

    return byDay.values.toList()
      ..sort((left, right) => left.date.compareTo(right.date));
  }

  static List<WeightChartPoint> _buildPoints({
    required List<WeightEntry> entries,
    required DateTime windowStart,
    required DateTime windowEnd,
    required DateTime today,
    required bool useMetricUnits,
  }) {
    if (entries.isEmpty) return const [];

    final span = math.max(1, windowEnd.difference(windowStart).inDays);

    return entries.map((entry) {
      final day = entry.date;
      final offset = day.difference(windowStart).inDays.clamp(0, span);
      final xFraction = offset / span;
      final isToday = day == today;

      return WeightChartPoint(
        date: day,
        kg: entry.kg,
        displayWeight: toDisplayWeight(entry.kg, useMetricUnits),
        xFraction: xFraction,
        xLabel: isToday ? 'Today' : DateFormat('EEE').format(day),
        highlightXLabel: isToday,
      );
    }).toList();
  }

  static List<WeightChartAxisTick> _buildXAxisTicks({
    required DateTime windowStart,
    required DateTime windowEnd,
    required DateTime today,
    required bool usesFallbackWindow,
  }) {
    if (windowStart == windowEnd) {
      final isToday = windowStart == today;
      return [
        WeightChartAxisTick(
          xFraction: 1,
          label: isToday ? 'Today' : DateFormat('MMM d').format(windowStart),
        ),
      ];
    }

    final span = windowEnd.difference(windowStart).inDays;
    if (span <= 0) {
      return [
        WeightChartAxisTick(
          xFraction: 1,
          label: windowEnd == today ? 'Today' : DateFormat('MMM d').format(windowEnd),
        ),
      ];
    }

    if (usesFallbackWindow && span <= 14) {
      const tickCount = 3;
      return List<WeightChartAxisTick>.generate(tickCount, (index) {
        final fraction = index / (tickCount - 1);
        final offset = (fraction * span).round();
        final day = windowStart.add(Duration(days: offset));
        final isToday = day == today;
        return WeightChartAxisTick(
          xFraction: fraction,
          label: isToday ? 'Today' : DateFormat('MMM d').format(day),
        );
      });
    }

    if (span <= 7) {
      return List<WeightChartAxisTick>.generate(span + 1, (index) {
        final day = windowStart.add(Duration(days: index));
        final isToday = day == today;
        return WeightChartAxisTick(
          xFraction: span == 0 ? 1 : index / span,
          label: isToday ? 'Today' : DateFormat('EEE').format(day),
        );
      });
    }

    if (span <= 31) {
      const tickCount = 5;
      return List<WeightChartAxisTick>.generate(tickCount, (index) {
        final fraction = index / (tickCount - 1);
        final offset = (fraction * span).round();
        final day = windowStart.add(Duration(days: offset));
        final isToday = day == today;
        return WeightChartAxisTick(
          xFraction: span == 0 ? 1 : offset / span,
          label: isToday ? 'Today' : DateFormat('MMM d').format(day),
        );
      });
    }

    final tickCount = span <= 120 ? 6 : 5;
    return List<WeightChartAxisTick>.generate(tickCount, (index) {
      final fraction = index / (tickCount - 1);
      final offset = (fraction * span).round();
      final day = windowStart.add(Duration(days: offset));
      final isToday = day == today;
      final label = span > 180
          ? DateFormat('MMM').format(day)
          : DateFormat('MMM d').format(day);
      return WeightChartAxisTick(
        xFraction: span == 0 ? 1 : offset / span,
        label: isToday ? 'Today' : label,
      );
    });
  }

  static List<double> _buildYAxisTicks(List<double> values) {
    if (values.isEmpty) {
      return const [50, 75, 100, 125, 150];
    }

    var minValue = values.reduce((a, b) => a < b ? a : b);
    var maxValue = values.reduce((a, b) => a > b ? a : b);

    if ((maxValue - minValue).abs() < 0.1) {
      minValue -= 1;
      maxValue += 1;
    } else {
      final padding = (maxValue - minValue) * 0.12;
      minValue -= padding;
      maxValue += padding;
    }

    final step = _niceStep(maxValue - minValue);
    final start = (minValue / step).floor() * step;
    final ticks = <double>[];
    var tick = start;
    while (tick <= maxValue + step * 0.01) {
      if (tick >= minValue - step * 0.01) {
        ticks.add(double.parse(tick.toStringAsFixed(1)));
      }
      tick += step;
      if (ticks.length >= 5) break;
    }

    if (ticks.length < 2) {
      return [minValue, maxValue];
    }

    return ticks;
  }

  static double _niceStep(double rawRange) {
    if (rawRange <= 0) return 1;
    final exponent = (math.log(rawRange / 5) / math.ln10).floor();
    final magnitude = math.pow(10, exponent).toDouble();
    final normalized = rawRange / 5 / magnitude;

    final niceNormalized = normalized <= 1
        ? 1
        : normalized <= 2
            ? 2
            : normalized <= 5
                ? 5
                : 10;

    return niceNormalized * magnitude;
  }
}
