import 'meal_entry.dart';

class DailyWaterIntake {
  const DailyWaterIntake({
    required this.date,
    required this.glasses,
  });

  final DateTime date;
  final int glasses;

  factory DailyWaterIntake.empty(DateTime date) => DailyWaterIntake(
        date: MealEntry.normalizeDate(date),
        glasses: 0,
      );

  bool goalMet(int goal) => glasses >= goal;

  bool get hasData => glasses > 0;

  double progressFor(int goal) =>
      goal > 0 ? (glasses / goal).clamp(0.0, 1.0) : 0;
}
