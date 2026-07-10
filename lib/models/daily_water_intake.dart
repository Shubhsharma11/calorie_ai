import 'meal_entry.dart';

class DailyWaterIntake {
  const DailyWaterIntake({
    required this.date,
    required this.totalMl,
  });

  /// Standard glass size used for glass-equivalent display.
  static const int mlPerGlass = 250;

  final DateTime date;
  final int totalMl;

  factory DailyWaterIntake.empty(DateTime date) => DailyWaterIntake(
        date: MealEntry.normalizeDate(date),
        totalMl: 0,
      );

  int get glasses => (totalMl / mlPerGlass).round();

  bool goalMet(int goalMl) => totalMl >= goalMl;

  bool get hasData => totalMl > 0;

  double progressFor(int goalMl) =>
      goalMl > 0 ? (totalMl / goalMl).clamp(0.0, 1.0) : 0;
}

/// Formats a millilitre amount for display (e.g. 750 ml, 1.5 L).
String formatWaterMl(int ml) {
  if (ml >= 1000) {
    final liters = ml / 1000;
    final text = liters == liters.roundToDouble()
        ? liters.round().toString()
        : liters.toStringAsFixed(1);
    return '$text L';
  }
  return '$ml ml';
}
