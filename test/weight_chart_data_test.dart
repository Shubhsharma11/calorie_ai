import 'package:calorie_ai/core/weight_chart_data.dart';
import 'package:calorie_ai/models/weight_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 3);

  List<WeightEntry> sampleEntries() {
    return List<WeightEntry>.generate(10, (index) {
      final day = now.subtract(Duration(days: 9 - index));
      return WeightEntry(
        id: 'entry-$index',
        date: day,
        kg: 70 + index * 0.3,
      );
    });
  }

  test('today filter keeps only today entry', () {
    final chart = WeightChartData.build(
      entries: [
        WeightEntry(
          id: 'yesterday',
          date: now.subtract(const Duration(days: 1)),
          kg: 69,
        ),
        WeightEntry(id: 'today', date: now, kg: 70.5),
      ],
      period: WeightChartPeriod.today,
      useMetricUnits: true,
      now: now,
    );

    expect(chart.points, hasLength(1));
    expect(chart.points.single.kg, 70.5);
    expect(chart.xAxisTicks.single.label, 'Today');
  });

  test('two week filter keeps last 14 days of entries', () {
    final entries = List<WeightEntry>.generate(20, (index) {
      return WeightEntry(
        id: 'entry-$index',
        date: now.subtract(Duration(days: 19 - index)),
        kg: 68 + index * 0.1,
      );
    });

    final chart = WeightChartData.build(
      entries: entries,
      period: WeightChartPeriod.twoWeeks,
      useMetricUnits: true,
      now: now,
    );

    expect(chart.points.length, 14);
    expect(chart.points.first.date, now.subtract(const Duration(days: 13)));
    expect(chart.points.last.date, now);
  });

  test('year filter keeps last 365 days of entries', () {
    final entries = List<WeightEntry>.generate(400, (index) {
      return WeightEntry(
        id: 'entry-$index',
        date: now.subtract(Duration(days: 399 - index)),
        kg: 65 + index * 0.01,
      );
    });

    final chart = WeightChartData.build(
      entries: entries,
      period: WeightChartPeriod.year,
      useMetricUnits: true,
      now: now,
    );

    expect(chart.points.length, 365);
    expect(chart.xAxisTicks, isNotEmpty);
  });

  test('custom range filters entries between selected dates', () {
    final chart = WeightChartData.build(
      entries: sampleEntries(),
      period: WeightChartPeriod.custom,
      useMetricUnits: true,
      now: now,
      customRange: WeightChartCustomRange(
        start: now.subtract(const Duration(days: 4)),
        end: now,
      ),
    );

    expect(chart.points.length, 5);
    expect(chart.customRangeLabel, isNotNull);
    expect(chart.points.first.date, now.subtract(const Duration(days: 4)));
    expect(chart.points.last.date, now);
  });

  test('week filter keeps only last 7 days of entries', () {
    final chart = WeightChartData.build(
      entries: sampleEntries(),
      period: WeightChartPeriod.week,
      useMetricUnits: true,
      now: now,
    );

    expect(chart.points.length, 7);
    expect(chart.points.first.date, DateTime(2026, 6, 27));
    expect(chart.points.last.date, now);
    expect(chart.xAxisTicks.length, 7);
    expect(chart.xAxisTicks.last.label, 'Today');
    expect(chart.usesFallbackWindow, isFalse);
  });

  test('month filter keeps last 30 days of entries', () {
    final entries = List<WeightEntry>.generate(35, (index) {
      return WeightEntry(
        id: 'entry-$index',
        date: now.subtract(Duration(days: 34 - index)),
        kg: 68 + index * 0.1,
      );
    });

    final chart = WeightChartData.build(
      entries: entries,
      period: WeightChartPeriod.month,
      useMetricUnits: true,
      now: now,
    );

    expect(chart.points.length, 30);
    expect(chart.xAxisTicks.length, 5);
    expect(chart.xAxisTicks.last.label, 'Today');
    expect(chart.xAxisTicks.first.label, isNotEmpty);
  });

  test('imperial units convert kg to lb for chart values', () {
    final chart = WeightChartData.build(
      entries: [
        WeightEntry(id: '1', date: now, kg: 70),
      ],
      period: WeightChartPeriod.week,
      useMetricUnits: false,
      now: now,
    );

    expect(chart.unitLabel, 'lb');
    expect(chart.points.single.displayWeight, closeTo(154.3, 0.1));
  });

  test('dedupes multiple entries on the same day', () {
    final chart = WeightChartData.build(
      entries: [
        WeightEntry(id: '1', date: now, kg: 70),
        WeightEntry(id: '2', date: now, kg: 71.5),
      ],
      period: WeightChartPeriod.week,
      useMetricUnits: true,
      now: now,
    );

    expect(chart.points.length, 1);
    expect(chart.points.single.kg, 71.5);
  });

  test('falls back to recent logs when none fall in calendar week', () {
    final chart = WeightChartData.build(
      entries: [
        WeightEntry(
          id: 'old-1',
          date: now.subtract(const Duration(days: 20)),
          kg: 72,
        ),
        WeightEntry(
          id: 'old-2',
          date: now.subtract(const Duration(days: 14)),
          kg: 71,
        ),
      ],
      period: WeightChartPeriod.week,
      useMetricUnits: true,
      now: now,
    );

    expect(chart.usesFallbackWindow, isTrue);
    expect(chart.points, hasLength(2));
    expect(chart.points.last.kg, 71);
    expect(chart.isEmpty, isFalse);
  });

  test('today log always appears on week chart', () {
    final chart = WeightChartData.build(
      entries: [
        WeightEntry(
          id: 'old',
          date: now.subtract(const Duration(days: 40)),
          kg: 80,
        ),
        WeightEntry(id: 'today', date: now, kg: 74.5),
      ],
      period: WeightChartPeriod.week,
      useMetricUnits: true,
      now: now,
    );

    expect(chart.points.any((point) => point.date == now), isTrue);
    expect(chart.points.last.kg, 74.5);
  });
}
