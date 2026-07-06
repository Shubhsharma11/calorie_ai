import 'food_item.dart';
import 'meal_entry.dart';

/// A reusable meal preset with food, portion, and meal slot.
class SavedMealItem {
  const SavedMealItem({
    required this.food,
    required this.grams,
    required this.meal,
  });

  final FoodItem food;
  final int grams;
  final String meal;

  int get calories => food.caloriesForGrams(grams);

  String get storageKey => '${food.name.toLowerCase()}|$meal|$grams';

  bool matchesFoodAndMeal(FoodItem otherFood, String otherMeal) {
    return food.name.toLowerCase() == otherFood.name.toLowerCase() &&
        meal == otherMeal;
  }

  MealEntry toMealEntry({DateTime? date}) {
    return MealEntry(
      food: food,
      grams: grams,
      meal: meal,
      date: date,
    );
  }

  factory SavedMealItem.fromMealEntry(MealEntry entry) {
    return SavedMealItem(
      food: entry.food,
      grams: entry.grams,
      meal: entry.meal,
    );
  }

  static List<SavedMealItem> historyFromEntries(
    Iterable<MealEntry> entries, {
    int limit = 15,
    String? meal,
  }) {
    final seen = <String>{};
    final history = <SavedMealItem>[];
    final sorted = entries.toList()
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        if (byDate != 0) return byDate;
        final aId = int.tryParse(a.id) ?? 0;
        final bId = int.tryParse(b.id) ?? 0;
        if (aId != bId) return bId.compareTo(aId);
        return b.id.compareTo(a.id);
      });

    for (final entry in sorted) {
      final item = SavedMealItem.fromMealEntry(entry);
      if (meal != null && item.meal != meal) continue;
      if (seen.add(item.storageKey)) {
        history.add(item);
        if (history.length >= limit) break;
      }
    }

    return history;
  }

  SavedMealItem copyWith({
    FoodItem? food,
    int? grams,
    String? meal,
  }) {
    return SavedMealItem(
      food: food ?? this.food,
      grams: grams ?? this.grams,
      meal: meal ?? this.meal,
    );
  }

  Map<String, dynamic> toJson() => {
        'food': food.toJson(),
        'grams': grams,
        'meal': meal,
      };

  factory SavedMealItem.fromJson(Map<String, dynamic> json) {
    return SavedMealItem(
      food: FoodItem.fromJson(json['food'] as Map<String, dynamic>),
      grams: json['grams'] as int,
      meal: json['meal'] as String,
    );
  }
}
