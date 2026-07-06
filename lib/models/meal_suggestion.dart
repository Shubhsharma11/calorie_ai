import 'saved_meal_item.dart';

/// A smart log suggestion shown on the Daily Log (e.g. usual breakfast).
class MealSuggestion {
  const MealSuggestion({
    required this.meal,
    required this.title,
    required this.calories,
    required this.items,
    required this.subtitle,
  });

  final String meal;
  final String title;
  final int calories;
  final List<SavedMealItem> items;
  final String subtitle;
}
