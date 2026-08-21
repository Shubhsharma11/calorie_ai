import 'dart:convert';
import 'dart:typed_data';

import '../core/media_url.dart';
import 'food_item.dart';
import 'saved_meal_item.dart';

enum MealShareVisibility {
  onlyMe,
  public;

  String get label => switch (this) {
        MealShareVisibility.onlyMe => 'Only me',
        MealShareVisibility.public => 'Public',
      };

  String get badgeLabel => switch (this) {
        MealShareVisibility.onlyMe => 'Private',
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
    this.visibility = MealShareVisibility.public,
    this.imageBytes,
    this.imageUrl,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final String meal;
  final List<SavedMealItem> items;
  final MealShareVisibility visibility;
  final Uint8List? imageBytes;
  final String? imageUrl;

  int get totalCalories =>
      items.fold(0, (sum, item) => sum + item.calories);

  double get totalCarbs => items.fold(
        0.0,
        (sum, item) => sum + item.carbs,
      );

  double get totalProtein => items.fold(
        0.0,
        (sum, item) => sum + item.protein,
      );

  double get totalFat => items.fold(
        0.0,
        (sum, item) => sum + item.fat,
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

  bool containsFoodNamed(String name) {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return false;
    if (this.name.trim().toLowerCase() == key) return true;
    return items.any((item) => item.food.name.trim().toLowerCase() == key);
  }

  /// One Quick Items row for this template — uses the meal name, not foods.
  SavedMealItem toQuickItem() {
    final first = items.isEmpty ? null : items.first;
    return SavedMealItem(
      food: FoodItem(
        name: name,
        caloriesPer100g: totalCalories,
        protein: totalProtein,
        carbs: totalCarbs,
        fat: totalFat,
        emoji: first?.food.displayEmoji ?? '🍽️',
        imageUrl: imageUrl ?? first?.food.imageUrl,
      ),
      grams: 100,
      meal: meal,
      servingQuantity: items.isEmpty ? 1 : items.length.toDouble(),
      servingUnit: 'food',
    );
  }

  CustomMealPreset copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    String? meal,
    List<SavedMealItem>? items,
    MealShareVisibility? visibility,
    Uint8List? imageBytes,
    String? imageUrl,
  }) {
    return CustomMealPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      meal: meal ?? this.meal,
      items: items ?? this.items,
      visibility: visibility ?? this.visibility,
      imageBytes: imageBytes ?? this.imageBytes,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'meal': meal,
        'items': items.map((item) => item.toJson()).toList(),
        'visibility': visibility.toJson(),
        if (imageBytes != null) 'imageBase64': base64Encode(imageBytes!),
        if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      };

  factory CustomMealPreset.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>;
    Uint8List? imageBytes;
    final encodedImage = json['imageBase64'];
    if (encodedImage is String && encodedImage.isNotEmpty) {
      try {
        imageBytes = base64Decode(encodedImage);
      } on FormatException {
        imageBytes = null;
      }
    }
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
      imageBytes: imageBytes,
      imageUrl: MediaUrl.resolve(
        (json['imageUrl'] as String?)?.trim().isNotEmpty == true
            ? (json['imageUrl'] as String).trim()
            : (json['image'] as String?)?.trim().isNotEmpty == true
                ? (json['image'] as String).trim()
                : null,
      ),
    );
  }
}
