import '../core/food_serving.dart';
import 'food_item.dart';
import 'meal_entry.dart';

/// A reusable meal preset with food, portion, and meal slot.
class SavedMealItem {
  const SavedMealItem({
    required this.food,
    required this.grams,
    required this.meal,
    this.id,
    this.servingQuantity,
    this.servingUnit = 'g',
    this.nutritionBasisQuantity,
    this.basisCarbs,
    this.basisProtein,
    this.basisFat,
  });

  /// Server id from `/api/v1/favourite-meals` when synced.
  final String? id;
  final FoodItem food;
  final int grams;
  final String meal;
  final double? servingQuantity;
  final String servingUnit;
  final double? nutritionBasisQuantity;
  final double? basisCarbs;
  final double? basisProtein;
  final double? basisFat;

  bool get hasServerId => id != null && id!.trim().isNotEmpty;

  bool get hasServingNutrition =>
      servingQuantity != null &&
      nutritionBasisQuantity != null &&
      nutritionBasisQuantity! > 0 &&
      basisCarbs != null &&
      basisProtein != null &&
      basisFat != null;

  double get carbs => hasServingNutrition
      ? basisCarbs! * displayedServingQuantity / nutritionBasisQuantity!
      : food.macroForGrams(food.carbs, grams);

  double get protein => hasServingNutrition
      ? basisProtein! * displayedServingQuantity / nutritionBasisQuantity!
      : food.macroForGrams(food.protein, grams);

  double get fat => hasServingNutrition
      ? basisFat! * displayedServingQuantity / nutritionBasisQuantity!
      : food.macroForGrams(food.fat, grams);

  int get calories {
    if (hasServingNutrition) {
      final basis = nutritionBasisQuantity!;
      // Prefer explicit food calories (user-entered) over macro formula.
      if (basis > 0 && food.caloriesPer100g > 0) {
        return (food.caloriesPer100g * displayedServingQuantity / basis)
            .round();
      }
      return (carbs * 4 + protein * 4 + fat * 9).round();
    }
    return food.caloriesForGrams(grams);
  }

  double get displayedServingQuantity => servingQuantity ?? grams.toDouble();

  String get servingDescription {
    final quantity = displayedServingQuantity;
    final household = FoodServing.isHouseholdUnit(servingUnit);
    return FoodServing.formatVisible(
      quantity: quantity,
      unit: servingUnit,
      grams: household ? grams : null,
    );
  }

  String get storageKey => hasServerId
      ? 'favourite|${id!.trim()}'
      : '${food.name.toLowerCase()}|$meal|$grams';

  bool matchesFoodAndMeal(FoodItem otherFood, String otherMeal) {
    return food.name.toLowerCase() == otherFood.name.toLowerCase() &&
        meal == otherMeal;
  }

  bool matchesFavorite(SavedMealItem other) {
    if (hasServerId && other.hasServerId) {
      return id!.trim() == other.id!.trim();
    }
    return storageKey == other.storageKey ||
        (food.name.toLowerCase() == other.food.name.toLowerCase() &&
            meal == other.meal &&
            grams == other.grams);
  }

  String get resolvedServingUnit {
    final itemUnit = servingUnit.trim();
    if (itemUnit.isNotEmpty) return FoodServing.normalizeUnit(itemUnit);
    return FoodServing.normalizeUnit(food.servingUnit);
  }

  /// Food with the logged unit attached so steppers and diary labels match.
  FoodItem get foodWithServing {
    final unit = resolvedServingUnit;
    final quantity = displayedServingQuantity;
    final household = FoodServing.isHouseholdUnit(unit);
    return food.copyWith(
      servingQuantity: household ? 1 : quantity,
      servingUnit: unit,
      gramsPerServing: food.usesHouseholdServing
          ? food.gramsPerServing
          : (household ? 100 : 1),
    );
  }

  MealEntry toMealEntry({DateTime? date}) {
    if (hasServingNutrition) {
      final unit = resolvedServingUnit;
      final quantity = displayedServingQuantity;
      if (FoodServing.isMetricUnit(unit)) {
        final logged = quantity.round().clamp(1, 5000);
        final scale = logged > 0 ? 100 / logged : 1.0;
        return MealEntry(
          food: FoodItem(
            name: food.name,
            caloriesPer100g: _per100gForPortion(calories, logged),
            protein: protein * scale,
            carbs: carbs * scale,
            fat: fat * scale,
            emoji: food.displayEmoji,
            imageUrl: food.imageUrl,
            category: food.category,
            servingQuantity: quantity,
            servingUnit: unit,
            gramsPerServing: 1,
            catalogId: food.catalogId,
          ),
          grams: logged,
          meal: meal,
          date: date,
        );
      }

      // Custom household foods store calories per serving, not per 100 g.
      final gramsPerServing = quantity > 0
          ? (100 / quantity).round().clamp(1, 5000)
          : 100;
      return MealEntry(
        food: FoodItem(
          name: food.name,
          caloriesPer100g: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          emoji: food.displayEmoji,
          imageUrl: food.imageUrl,
          category: food.category,
          servingQuantity: 1,
          servingUnit: unit,
          gramsPerServing: gramsPerServing,
          catalogId: food.catalogId,
        ),
        grams: 100,
        meal: meal,
        date: date,
      );
    }

    return MealEntry(
      food: foodWithServing,
      grams: grams.clamp(1, 5000),
      meal: meal,
      date: date,
    );
  }

  factory SavedMealItem.fromMealEntry(MealEntry entry) {
    return SavedMealItem(
      food: entry.food,
      grams: entry.grams,
      meal: entry.meal,
      servingQuantity: entry.food.servingCountForGrams(entry.grams),
      servingUnit: entry.food.servingUnit,
    );
  }

  static List<SavedMealItem> historyFromEntries(
    Iterable<MealEntry> entries, {
    int limit = 15,
    String? meal,
    Set<String>? excludeFoodNames,
  }) {
    final seen = <String>{};
    final history = <SavedMealItem>[];
    final hidden = excludeFoodNames == null
        ? const <String>{}
        : {
            for (final name in excludeFoodNames) name.trim().toLowerCase(),
          };
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
      if (hidden.contains(item.food.name.trim().toLowerCase())) continue;
      if (seen.add(item.storageKey)) {
        history.add(item);
        if (history.length >= limit) break;
      }
    }

    return history;
  }

  SavedMealItem copyWith({
    String? id,
    FoodItem? food,
    int? grams,
    String? meal,
    double? servingQuantity,
    String? servingUnit,
    double? nutritionBasisQuantity,
    double? basisCarbs,
    double? basisProtein,
    double? basisFat,
    bool clearId = false,
  }) {
    return SavedMealItem(
      id: clearId ? null : (id ?? this.id),
      food: food ?? this.food,
      grams: grams ?? this.grams,
      meal: meal ?? this.meal,
      servingQuantity: servingQuantity ?? this.servingQuantity,
      servingUnit: servingUnit ?? this.servingUnit,
      nutritionBasisQuantity:
          nutritionBasisQuantity ?? this.nutritionBasisQuantity,
      basisCarbs: basisCarbs ?? this.basisCarbs,
      basisProtein: basisProtein ?? this.basisProtein,
      basisFat: basisFat ?? this.basisFat,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'food': food.toJson(),
        'grams': grams,
        'meal': meal,
        if (servingQuantity != null) 'servingQuantity': servingQuantity,
        'servingUnit': servingUnit,
        if (nutritionBasisQuantity != null)
          'nutritionBasisQuantity': nutritionBasisQuantity,
        if (basisCarbs != null) 'basisCarbs': basisCarbs,
        if (basisProtein != null) 'basisProtein': basisProtein,
        if (basisFat != null) 'basisFat': basisFat,
      };

  factory SavedMealItem.fromJson(Map<String, dynamic> json) {
    return SavedMealItem(
      id: json['id'] as String?,
      food: FoodItem.fromJson(json['food'] as Map<String, dynamic>),
      grams: json['grams'] as int,
      meal: json['meal'] as String,
      servingQuantity: (json['servingQuantity'] as num?)?.toDouble(),
      servingUnit: json['servingUnit'] as String? ?? 'g',
      nutritionBasisQuantity:
          (json['nutritionBasisQuantity'] as num?)?.toDouble(),
      basisCarbs: (json['basisCarbs'] as num?)?.toDouble(),
      basisProtein: (json['basisProtein'] as num?)?.toDouble(),
      basisFat: (json['basisFat'] as num?)?.toDouble(),
    );
  }
}

int _per100gForPortion(int portionCalories, int grams) {
  if (grams <= 0) return portionCalories < 0 ? 0 : portionCalories;
  var per100 = (portionCalories * 100 / grams).round();
  final got = (per100 * grams / 100).round();
  if (got < portionCalories) per100++;
  if (got > portionCalories) per100--;
  return per100 < 0 ? 0 : per100;
}
