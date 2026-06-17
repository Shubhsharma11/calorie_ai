import 'food_item.dart';

class MealEntry {
  MealEntry({
    String? id,
    DateTime? date,
    required this.food,
    required this.grams,
    required this.meal,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        date = normalizeDate(date ?? DateTime.now());

  final String id;
  final DateTime date;
  final FoodItem food;
  final int grams;
  final String meal;

  static DateTime normalizeDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  int get calories => food.caloriesForGrams(grams);

  double get protein => food.macroForGrams(food.protein, grams);
  double get carbs => food.macroForGrams(food.carbs, grams);
  double get fat => food.macroForGrams(food.fat, grams);

  MealEntry copyWith({
    String? id,
    DateTime? date,
    FoodItem? food,
    int? grams,
    String? meal,
  }) {
    return MealEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      food: food ?? this.food,
      grams: grams ?? this.grams,
      meal: meal ?? this.meal,
    );
  }

  static String dateToKey(DateTime date) {
    final d = normalizeDate(date);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static DateTime dateFromKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': dateToKey(date),
        'food': food.toJson(),
        'grams': grams,
        'meal': meal,
      };

  factory MealEntry.fromJson(Map<String, dynamic> json) => MealEntry(
        id: json['id'] as String?,
        date: dateFromKey(json['date'] as String),
        food: FoodItem.fromJson(json['food'] as Map<String, dynamic>),
        grams: json['grams'] as int,
        meal: json['meal'] as String,
      );
}
