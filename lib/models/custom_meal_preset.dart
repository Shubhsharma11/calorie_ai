import 'saved_meal_item.dart';

enum MealShareVisibility {
  onlyMe,
  public;

  String get label => switch (this) {
        MealShareVisibility.onlyMe => 'Only me',
        MealShareVisibility.public => 'Public',
      };

  static MealShareVisibility fromJson(String? value) {
    return switch (value) {
      'public' => MealShareVisibility.public,
      _ => MealShareVisibility.onlyMe,
    };
  }

  String toJson() => name;
}

/// A named meal template with one or more foods saved for quick logging.
class CustomMealPreset {
  const CustomMealPreset({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.meal,
    required this.items,
    this.visibility = MealShareVisibility.onlyMe,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final String meal;
  final List<SavedMealItem> items;
  final MealShareVisibility visibility;

  int get totalCalories =>
      items.fold(0, (sum, item) => sum + item.calories);

  double get totalCarbs => items.fold(
        0.0,
        (sum, item) => sum + item.food.macroForGrams(item.food.carbs, item.grams),
      );

  double get totalProtein => items.fold(
        0.0,
        (sum, item) =>
            sum + item.food.macroForGrams(item.food.protein, item.grams),
      );

  double get totalFat => items.fold(
        0.0,
        (sum, item) => sum + item.food.macroForGrams(item.food.fat, item.grams),
      );

  /// Macro calorie split used for ring progress (carbs/protein = 4, fat = 9).
  double get carbsCalorieShare {
    final total = _macroCalories;
    if (total <= 0) return 0;
    return (totalCarbs * 4) / total;
  }

  double get proteinCalorieShare {
    final total = _macroCalories;
    if (total <= 0) return 0;
    return (totalProtein * 4) / total;
  }

  double get fatCalorieShare {
    final total = _macroCalories;
    if (total <= 0) return 0;
    return (totalFat * 9) / total;
  }

  double get _macroCalories =>
      totalCarbs * 4 + totalProtein * 4 + totalFat * 9;

  String get itemSummary {
    if (items.isEmpty) return 'No foods';
    if (items.length == 1) return items.first.food.name;
    return '${items.first.food.name} + ${items.length - 1} more';
  }

  CustomMealPreset copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    String? meal,
    List<SavedMealItem>? items,
    MealShareVisibility? visibility,
  }) {
    return CustomMealPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      meal: meal ?? this.meal,
      items: items ?? this.items,
      visibility: visibility ?? this.visibility,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'meal': meal,
        'items': items.map((item) => item.toJson()).toList(),
        'visibility': visibility.toJson(),
      };

  factory CustomMealPreset.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>;
    return CustomMealPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      meal: json['meal'] as String,
      items: rawItems
          .map(
            (item) => SavedMealItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      visibility: MealShareVisibility.fromJson(json['visibility'] as String?),
    );
  }
}
