import '../core/food_serving.dart';
import '../core/media_url.dart';
import 'api_custom_meal_mapper.dart';
import 'meal_type.dart';
import 'saved_meal_item.dart';

class FoodItem {
  const FoodItem({
    required this.name,
    required this.caloriesPer100g,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.emoji = '🍽️',
    this.imageUrl,
    this.category,
    this.servingQuantity = 100,
    this.servingUnit = 'g',
    this.gramsPerServing = 1,
    this.ingredients = const [],
    this.catalogId,
  });

  final String name;
  final int caloriesPer100g;
  final double protein;
  final double carbs;
  final double fat;
  final String emoji;
  final String? imageUrl;
  final String? category;
  final double servingQuantity;
  final String servingUnit;
  final int gramsPerServing;
  final List<SavedMealItem> ingredients;
  final String? catalogId;

  /// Last-resort glyph when the server did not send a photo.
  String get displayEmoji =>
      emoji.trim().isEmpty || MediaUrl.looksLikeImageRef(emoji) ? '🍽️' : emoji;

  /// One favourite per food: catalog id when both have it, otherwise name.
  bool isSameFavoriteFood(FoodItem other) {
    final id = catalogId?.trim();
    final otherId = other.catalogId?.trim();
    if (id != null &&
        id.isNotEmpty &&
        otherId != null &&
        otherId.isNotEmpty) {
      return id == otherId;
    }
    return name.trim().toLowerCase() == other.name.trim().toLowerCase();
  }

  bool get isCompositeMeal => ingredients.isNotEmpty;

  bool get usesHouseholdServing =>
      FoodServing.isHouseholdUnit(servingUnit) && gramsPerServing > 1;

  /// Bowl, glass, ml, etc. — the unit search results show instead of plain grams.
  bool get hasDisplayServing {
    final unit = FoodServing.normalizeUnit(servingUnit);
    return unit.isNotEmpty && unit != 'g';
  }

  int get defaultGrams {
    if (usesHouseholdServing) {
      return (servingQuantity * gramsPerServing).round().clamp(1, 5000);
    }
    return servingQuantity.round().clamp(1, 5000);
  }

  int gramsForServings(double servings) {
    if (usesHouseholdServing) {
      return (servings * gramsPerServing).round().clamp(1, 5000);
    }
    return servings.round().clamp(1, 5000);
  }

  double servingCountForGrams(int grams) {
    if (usesHouseholdServing && gramsPerServing > 0) {
      return grams / gramsPerServing;
    }
    return grams.toDouble();
  }

  String get servingDescription => FoodServing.formatVisible(
        quantity: servingQuantity,
        unit: servingUnit,
        grams: usesHouseholdServing ? defaultGrams : null,
      );

  String servingLabelForGrams(int grams) => FoodServing.formatVisible(
        quantity: servingCountForGrams(grams),
        unit: servingUnit,
        grams: usesHouseholdServing ? grams : null,
      );

  String get searchSubtitle {
    final cat = category?.trim();
    if (cat != null && cat.isNotEmpty) {
      return '$cat · $servingDescription';
    }
    return servingDescription;
  }

  int caloriesForGrams(int grams) =>
      (caloriesPer100g * grams / 100).round();

  double macroForGrams(double per100g, int grams) =>
      per100g * grams / 100;

  int get caloriesForDefaultServing => caloriesForGrams(defaultGrams);

  /// True when [grams] is a whole or half catalog serving (1 glass, 2 bowls).
  bool servingFitsLoggedGrams(int grams) {
    final unit = FoodServing.normalizeUnit(servingUnit);
    if (unit == 'ml') return true;
    if (!usesHouseholdServing) return false;
    final gps = gramsPerServing;
    if (gps <= 1 || grams <= 0) return false;
    final snapped = ((grams / gps) * 2).round() / 2.0;
    if (snapped < 0.5) return false;
    final expected = snapped * gps;
    final slop = gps <= 40 ? 8 : (gps * 0.08).round().clamp(8, 24);
    return (grams - expected).abs() <= slop;
  }

  FoodItem copyWith({
    String? name,
    int? caloriesPer100g,
    double? protein,
    double? carbs,
    double? fat,
    String? emoji,
    String? imageUrl,
    String? category,
    double? servingQuantity,
    String? servingUnit,
    int? gramsPerServing,
    List<SavedMealItem>? ingredients,
    String? catalogId,
  }) {
    return FoodItem(
      name: name ?? this.name,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      emoji: emoji ?? this.emoji,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      servingQuantity: servingQuantity ?? this.servingQuantity,
      servingUnit: servingUnit ?? this.servingUnit,
      gramsPerServing: gramsPerServing ?? this.gramsPerServing,
      ingredients: ingredients ?? this.ingredients,
      catalogId: catalogId ?? this.catalogId,
    );
  }

  /// Scales each ingredient when logging multiple meal portions.
  SavedMealItem scaleIngredient(SavedMealItem item, double factor) {
    if (factor == 1) return item;
    if (item.hasServingNutrition) {
      return item.copyWith(
        servingQuantity: item.displayedServingQuantity * factor,
      );
    }
    return item.copyWith(grams: (item.grams * factor).round().clamp(1, 5000));
  }

  List<SavedMealItem> ingredientsForPortions(double portions) {
    if (!isCompositeMeal) return const [];
    final basePortions = servingQuantity <= 0 ? 1.0 : servingQuantity;
    final factor = portions / basePortions;
    return [
      for (final item in ingredients) scaleIngredient(item, factor),
    ];
  }

  int totalCaloriesForPortions(double portions) {
    if (isCompositeMeal) {
      return ingredientsForPortions(portions)
          .fold(0, (sum, item) => sum + item.calories);
    }
    return caloriesForGrams(gramsForServings(portions));
  }

  double totalProteinForPortions(double portions) {
    if (isCompositeMeal) {
      return ingredientsForPortions(portions)
          .fold(0.0, (sum, item) => sum + item.protein);
    }
    return macroForGrams(protein, gramsForServings(portions));
  }

  double totalCarbsForPortions(double portions) {
    if (isCompositeMeal) {
      return ingredientsForPortions(portions)
          .fold(0.0, (sum, item) => sum + item.carbs);
    }
    return macroForGrams(carbs, gramsForServings(portions));
  }

  double totalFatForPortions(double portions) {
    if (isCompositeMeal) {
      return ingredientsForPortions(portions)
          .fold(0.0, (sum, item) => sum + item.fat);
    }
    return macroForGrams(fat, gramsForServings(portions));
  }

  /// Keeps bowl/plate/ml servings and image when the API meal payload omits them.
  FoodItem withServingFrom(FoodItem source, {int? loggedGrams}) {
    final missingEmoji = emoji.trim().isEmpty || emoji == '🍽️';
    final image = MediaUrl.preferLoadable([imageUrl, source.imageUrl]);
    final icon = missingEmoji &&
            source.emoji.trim().isNotEmpty &&
            !MediaUrl.looksLikeImageRef(source.emoji)
        ? source.emoji
        : emoji;
    var takeServing = !hasDisplayServing && source.hasDisplayServing;
    if (takeServing && loggedGrams != null) {
      takeServing = source.servingFitsLoggedGrams(loggedGrams);
    }

    if (!takeServing) {
      if (image == imageUrl &&
          icon == emoji &&
          (category != null || source.category == null) &&
          (catalogId != null || source.catalogId == null)) {
        return this;
      }
      return copyWith(
        imageUrl: image,
        emoji: icon,
        category: category ?? source.category,
        catalogId: catalogId ?? source.catalogId,
      );
    }

    return copyWith(
      category: category ?? source.category,
      servingQuantity: source.servingQuantity,
      servingUnit: source.servingUnit,
      gramsPerServing: source.gramsPerServing,
      imageUrl: image,
      emoji: icon,
      catalogId: catalogId ?? source.catalogId,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'caloriesPer100g': caloriesPer100g,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'emoji': emoji,
        if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
        if (category != null && category!.trim().isNotEmpty) 'category': category,
        'servingQuantity': servingQuantity,
        'servingUnit': servingUnit,
        'gramsPerServing': gramsPerServing,
        if (catalogId != null && catalogId!.isNotEmpty) 'catalogId': catalogId,
        if (ingredients.isNotEmpty)
          'ingredients':
              ingredients.map((item) => item.toJson()).toList(),
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final unit = FoodServing.normalizeUnit(
      json['servingUnit'] as String? ?? 'g',
    );
    final household = FoodServing.isHouseholdUnit(unit);
    return FoodItem(
      name: json['name'] as String,
      caloriesPer100g: json['caloriesPer100g'] as int,
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      emoji: json['emoji'] as String? ?? '🍽️',
      imageUrl: MediaUrl.resolve(
        (json['imageUrl'] as String?)?.trim().isNotEmpty == true
            ? (json['imageUrl'] as String).trim()
            : (json['image'] as String?)?.trim().isNotEmpty == true
                ? (json['image'] as String).trim()
                : null,
      ),
      category: (json['category'] as String?)?.trim().isNotEmpty == true
          ? (json['category'] as String).trim()
          : null,
      servingQuantity: (json['servingQuantity'] as num?)?.toDouble() ??
          (household ? 1 : 100),
      servingUnit: unit,
      gramsPerServing: (json['gramsPerServing'] as num?)?.round() ??
          (household ? 100 : 1),
      catalogId: (json['catalogId'] as String?)?.trim().isNotEmpty == true
          ? (json['catalogId'] as String).trim()
          : null,
      ingredients: _ingredientsFromJson(json['ingredients']),
    );
  }

  static List<SavedMealItem> _ingredientsFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (item) => SavedMealItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  /// Parses catalog / search payloads, including `1 bowl (220 g)` servings.
  static FoodItem? tryFromApiJson(Map<String, dynamic> json) {
    final nestedFood = json['food'];
    final source = nestedFood is Map
        ? Map<String, dynamic>.from(nestedFood)
        : json;

    final name = _readString(source, const [
      'name',
      'foodName',
      'food_name',
      'title',
      'productName',
      'product_name',
    ]);
    if (name == null || name.isEmpty) return null;

    final serving = FoodServing.parseFromApi(source);
    final servingGrams = serving.defaultGrams;
    final convertFromServing = serving.isHousehold &&
        !_hasExplicitPer100gCalories(source);

    final explicitCalories = _readNum(source, const [
      'caloriesPer100g',
      'calories_per_100g',
      'caloriesPer100G',
      'kcalPer100g',
    ]);
    final portionCalories = _readNum(source, const [
      'calories',
      'kcal',
      'energyKcal',
      'energy_kcal',
    ]);

    var caloriesPer100g = explicitCalories?.round() ?? 0;
    if (caloriesPer100g == 0 && portionCalories != null) {
      if (convertFromServing && servingGrams > 0) {
        caloriesPer100g = (portionCalories * 100 / servingGrams).round();
      } else {
        caloriesPer100g = portionCalories.round();
      }
    }

    var protein = _readNum(source, const [
          'protein',
          'proteins',
          'proteinG',
          'protein_g',
        ])?.toDouble() ??
        0;
    var carbs = _readNum(source, const [
          'carbs',
          'carbohydrates',
          'carb',
          'carbsG',
          'carbs_g',
        ])?.toDouble() ??
        0;
    var fat = _readNum(source, const [
          'fat',
          'fats',
          'fatG',
          'fat_g',
        ])?.toDouble() ??
        0;

    if (convertFromServing && servingGrams > 0 && explicitCalories == null) {
      protein = protein * 100 / servingGrams;
      carbs = carbs * 100 / servingGrams;
      fat = fat * 100 / servingGrams;
    }

    final fallbackMeal = _mealSlotFromApi(
          _readString(source, const ['mealTime', 'mealtime', 'meal']) ??
              _readString(json, const ['mealTime', 'mealtime', 'meal']),
        ) ??
        MealType.breakfast;
    final ingredients = ApiCustomMealMapper.savedItemsFromApi(
      source['items'] ?? source['foods'] ?? source['mealItems'],
      fallbackMeal: fallbackMeal,
    );

    return FoodItem(
      name: name,
      caloriesPer100g: caloriesPer100g < 0 ? 0 : caloriesPer100g,
      protein: protein.clamp(0, 200),
      carbs: carbs.clamp(0, 200),
      fat: fat.clamp(0, 200),
      emoji: _emojiFromApi(source),
      imageUrl: MediaUrl.fromJson(source) ??
          (nestedFood is Map ? MediaUrl.fromJson(json) : null),
      category: FoodServing.categoryFromApi(source),
      servingQuantity: serving.quantity,
      servingUnit: serving.unit,
      gramsPerServing: serving.isHousehold ? serving.gramsPerServing : 1,
      ingredients: ingredients,
      catalogId: _readString(source, const ['id', '_id', 'myMealId', 'foodId']),
    );
  }

  static String? _mealSlotFromApi(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();
    for (final meal in MealType.all) {
      if (meal.toLowerCase() == value.toLowerCase()) return meal;
    }
    return switch (value.toLowerCase()) {
      'breakfast' => MealType.breakfast,
      'lunch' => MealType.lunch,
      'dinner' => MealType.dinner,
      'snack' || 'snacks' => MealType.snacks,
      _ => null,
    };
  }

  static bool _hasExplicitPer100gCalories(Map<String, dynamic> json) {
    const keys = [
      'caloriesPer100g',
      'calories_per_100g',
      'caloriesPer100G',
      'kcalPer100g',
    ];
    return keys.any(json.containsKey);
  }

  static String _emojiFromApi(Map<String, dynamic> source) {
    for (final key in const ['emoji', 'icon']) {
      final value = source[key];
      if (value is! String) continue;
      final trimmed = value.trim();
      if (trimmed.isEmpty || MediaUrl.looksLikeImageRef(trimmed)) continue;
      return trimmed;
    }
    return '🍽️';
  }

  static String? _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static num? _readNum(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value;
      if (value is String) {
        final parsed = num.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}
