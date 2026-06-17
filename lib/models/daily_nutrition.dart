import 'meal_entry.dart';
import 'nutrition_trend_metric.dart';

class DailyNutrition {
  const DailyNutrition({
    required this.date,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.mealCount,
  });

  final DateTime date;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final int mealCount;

  factory DailyNutrition.empty(DateTime date) => DailyNutrition(
        date: MealEntry.normalizeDate(date),
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
        mealCount: 0,
      );

  factory DailyNutrition.fromEntries(
    DateTime date,
    Iterable<MealEntry> entries,
  ) {
    final list = entries.toList();
    return DailyNutrition(
      date: MealEntry.normalizeDate(date),
      calories: list.fold(0, (sum, e) => sum + e.calories),
      protein: list.fold(0.0, (sum, e) => sum + e.protein),
      carbs: list.fold(0.0, (sum, e) => sum + e.carbs),
      fat: list.fold(0.0, (sum, e) => sum + e.fat),
      mealCount: list.length, 
    );
  }

  double valueFor(NutritionTrendMetric metric) => switch (metric) {
        NutritionTrendMetric.calories => calories.toDouble(),
        NutritionTrendMetric.protein => protein,
        NutritionTrendMetric.carbs => carbs,
        NutritionTrendMetric.fat => fat,
      };

  bool get hasData => mealCount > 0;
}
