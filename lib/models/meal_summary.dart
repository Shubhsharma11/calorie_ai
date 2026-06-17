class MealSummary {
  const MealSummary({
    required this.meal,
    required this.calories,
    required this.itemCount,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final String meal;
  final int calories;
  final int itemCount;
  final double protein;
  final double carbs;
  final double fat;

  static const empty = MealSummary(
    meal: '',
    calories: 0,
    itemCount: 0,
    protein: 0,
    carbs: 0,
    fat: 0,
  );
}
