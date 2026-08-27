import 'package:flutter/foundation.dart';

import '../core/food_serving.dart';
import '../core/media_url.dart';
import 'food_item.dart';
import 'meal_entry.dart';
import 'meal_type.dart';

/// Maps backend meal payloads to [MealEntry].
abstract final class ApiMealMapper {
  static List<MealEntry> entriesFromResponse(
    Map<String, dynamic> json, {
    DateTime? fallbackDate,
  }) {
    final rawData = json['data'];
    if (rawData is List) {
      return _entriesFromMealMaps(rawData, fallbackDate: fallbackDate);
    }

    final data = _unwrapData(json);
    final responseDate = _readDate(data['date']) ?? fallbackDate;
    final meals = _readMealMaps(data);

    return _entriesFromMealMaps(meals, fallbackDate: responseDate);
  }

  static List<MealEntry> _entriesFromMealMaps(
    Iterable<dynamic> meals, {
    DateTime? fallbackDate,
  }) {
    return meals
        .whereType<Map>()
        .map(
          (meal) => entryFromApiJson(
            Map<String, dynamic>.from(meal),
            fallbackDate: fallbackDate,
          ),
        )
        .whereType<MealEntry>()
        .toList();
  }

  static Map<String, dynamic> toCreateRequestBody(MealEntry entry) {
    final unit = FoodServing.normalizeUnit(entry.food.servingUnit);
    final household = entry.food.usesHouseholdServing;
    final image = entry.food.imageUrl?.trim() ?? '';
    final emoji = entry.food.emoji.trim();
    return {
      'name': entry.food.name,
      'calories': entry.calories,
      'protein': _roundMacro(entry.protein),
      'carbs': _roundMacro(entry.carbs),
      'fat': _roundMacro(entry.fat),
      'mealTime': _mealTimeToApi(entry.meal),
      // API quantity is grams — sending serving count breaks calorie math on GET.
      'quantity': entry.grams,
      'unit': unit.isEmpty ? 'g' : unit,
      'grams': entry.grams,
      if (household) 'servingUnit': entry.food.servingUnit,
      if (household) 'gramsPerServing': entry.food.gramsPerServing,
      if (image.isNotEmpty) 'image': image,
      if (image.isNotEmpty) 'imageUrl': image,
      if (emoji.isNotEmpty) 'emoji': emoji,
      'date': MealEntry.dateToKey(entry.date),
    };
  }

  /// API enum uses `snack` (singular); UI label is [MealType.snacks].
  static String _mealTimeToApi(String meal) {
    final normalized = meal.trim().toLowerCase();
    return switch (normalized) {
      'breakfast' => 'breakfast',
      'lunch' => 'lunch',
      'dinner' => 'dinner',
      'snack' || 'snacks' => 'snack',
      _ => normalized.isEmpty ? 'breakfast' : normalized,
    };
  }

  /// Body for `PATCH /meals/:id` — same fields as create, without forcing id.
  static Map<String, dynamic> toUpdateRequestBody(MealEntry entry) {
    return toCreateRequestBody(entry);
  }

  static MealEntry mergeCreateResponse(
    Map<String, dynamic> json, {
    required MealEntry source,
  }) {
    final data = _unwrapData(json);
    final nested = _firstMap(data, const ['meal', 'entry', 'item', 'foodLog']);
    final candidates = <Map<String, dynamic>>[
      data,
      if (nested != null) nested,
      json,
    ];

    for (final map in candidates) {
      final parsed = entryFromApiJson(map, fallbackDate: source.date);
      if (parsed == null) continue;
      final id = _readId(map);
      final incomingFood =
          parsed.food.name == 'Food' ? source.food : parsed.food;
      return parsed.copyWith(
        id: (id != null && id.isNotEmpty) ? id : parsed.id,
        food: incomingFood.withServingFrom(source.food),
        grams: parsed.grams > 0 ? parsed.grams : source.grams,
        meal: parsed.meal,
        date: source.date,
      );
    }

    for (final map in candidates) {
      final id = _readId(map);
      if (id != null && id.isNotEmpty) {
        return source.copyWith(id: id);
      }
    }

    debugPrint(
      'ApiMealMapper: create response had no meal id; keys=${json.keys.toList()} '
      'dataKeys=${data.keys.toList()}',
    );
    // Keep source only as a temporary draft; caller must refresh from GET.
    return source;
  }

  static MealEntry? entryFromApiJson(
    Map<String, dynamic> json, {
    DateTime? fallbackDate,
  }) {
    final mealType = _normalizeMealType(
      json['meal'] ??
          json['mealType'] ??
          json['meal_type'] ??
          json['mealTime'] ??
          json['meal_time'] ??
          json['type'],
    );
    if (mealType == null) return null;

    final grams = _loggedGrams(json);
    if (grams <= 0) return null;

    final foodMap = _firstMap(json, const ['food', 'foodItem', 'food_item']);
    var food = foodMap != null
        ? _foodFromApiJson(foodMap)
        : _foodFromFlatMealJson(json, grams: grams);
    if (food == null) return null;
    final image = food.imageUrl ??
        MediaUrl.fromJson(foodMap) ??
        MediaUrl.fromJson(json);
    if (image != null && image != food.imageUrl) {
      food = food.copyWith(imageUrl: image);
    }
    food = _applyLoggedMealServing(food, json);
    if (foodMap != null) {
      food = _applyLoggedMealServing(food, foodMap);
    }

    final date = _readDate(json['date']) ??
        _readDate(json['loggedAt']) ??
        _readDate(json['logged_at']) ??
        _readDate(json['createdAt']) ??
        _readDate(json['created_at']) ??
        _readDate(json['updatedAt']) ??
        _readDate(json['updated_at']) ??
        fallbackDate ??
        DateTime.now();

    final parsedId = _readId(json);
    if (parsedId == null || parsedId.isEmpty) {
      // Never invent a local epoch id for API meals — that breaks DELETE.
      debugPrint(
        'ApiMealMapper: skipping meal missing server id; '
        'keys=${json.keys.toList()} name=${json['name'] ?? json['foodName']}',
      );
      return null;
    }

    return MealEntry(
      id: parsedId,
      date: date,
      food: food,
      grams: grams,
      meal: mealType,
    );
  }

  /// Builds a [FoodItem] from flat meal payloads returned by `GET /api/v1/meals`.
  static FoodItem? _foodFromFlatMealJson(
    Map<String, dynamic> json, {
    required int grams,
  }) {
    final name = _readString(json, const [
      'name',
      'foodName',
      'food_name',
      'title',
      'label',
    ]);
    if (name == null) return null;

    final portionCalories =
        _readInt(json, const ['calories', 'totalCalories', 'kcal']);
    var caloriesPer100g = _readInt(json, const [
          'caloriesPer100g',
          'calories_per_100g',
          'caloriesPer100G',
          'kcalPer100g',
        ]) ??
        0;

    if (caloriesPer100g == 0 && portionCalories != null && grams > 0) {
      caloriesPer100g = (portionCalories * 100 / grams).round();
    }

    var protein =
        _readDouble(json, const ['protein', 'proteinG', 'protein_g']) ?? 0;
    var carbs = _readDouble(json, const ['carbs', 'carbsG', 'carbs_g']) ?? 0;
    var fat = _readDouble(json, const ['fat', 'fatG', 'fat_g']) ?? 0;

    // Flat API meals store macros for the logged portion, not per 100g.
    if (grams > 0) {
      protein = protein * 100 / grams;
      carbs = carbs * 100 / grams;
      fat = fat * 100 / grams;
    }

    final servingText = _readString(json, const [
      'serving',
      'servingSize',
      'serving_size',
      'portion',
      'servingDescription',
      'serving_description',
    ]);
    final serving = servingText == null
        ? null
        : FoodServing.parseDescription(servingText);

    return FoodItem(
      name: name,
      caloriesPer100g: caloriesPer100g,
      protein: protein,
      carbs: carbs,
      fat: fat,
      emoji: _readString(json, const ['emoji']) ?? '🍽️',
      imageUrl: MediaUrl.fromJson(json),
      category: FoodServing.categoryFromApi(json),
      servingQuantity: serving?.quantity ?? 100,
      servingUnit: serving?.unit ?? 'g',
      gramsPerServing: serving != null && serving.isHousehold
          ? serving.gramsPerServing
          : 1,
    );
  }

  static FoodItem _foodFromApiJson(Map<String, dynamic> json) {
    return FoodItem.tryFromApiJson(json) ??
        FoodItem(
          name: _readString(json, const ['name', 'foodName', 'food_name']) ??
              'Food',
          caloriesPer100g: _readInt(json, const [
                'caloriesPer100g',
                'calories_per_100g',
                'caloriesPer100G',
                'kcalPer100g',
              ]) ??
              0,
          protein:
              _readDouble(json, const ['protein', 'proteinG', 'protein_g']) ??
                  0,
          carbs: _readDouble(json, const ['carbs', 'carbsG', 'carbs_g']) ?? 0,
          fat: _readDouble(json, const ['fat', 'fatG', 'fat_g']) ?? 0,
          emoji: _readString(json, const ['emoji']) ?? '🍽️',
          imageUrl: MediaUrl.fromJson(json),
        );
  }

  /// Logged meals store grams in [grams], or [quantity] as grams / serving count.
  static int _loggedGrams(Map<String, dynamic> json) {
    final quantity = _readDouble(json, const ['quantity', 'amount']);
    final unitRaw = _readString(json, const [
      'servingUnit',
      'serving_unit',
      'unit',
    ]);
    final unit = FoodServing.normalizeUnit(unitRaw ?? 'g');
    final gramsPerServing = _readInt(json, const [
          'gramsPerServing',
          'grams_per_serving',
        ]) ??
        FoodServing.typicalGramsFor(unit);
    final explicitGrams = _readInt(json, const [
      'grams',
      'servingGrams',
      'serving_grams',
    ]);

    if (explicitGrams != null && explicitGrams > 0) {
      if (FoodServing.isHouseholdUnit(unit) &&
          quantity != null &&
          quantity > 0 &&
          quantity <= 30 &&
          explicitGrams < 30 &&
          quantity * gramsPerServing > explicitGrams) {
        return (quantity * gramsPerServing).round().clamp(1, 5000);
      }
      return explicitGrams;
    }

    if (quantity == null || quantity <= 0) return 0;
    if (!FoodServing.isHouseholdUnit(unit)) {
      return quantity.round().clamp(1, 5000);
    }

    // Legacy posts sent quantity as grams with a household unit.
    if (quantity > 30 || quantity >= gramsPerServing) {
      return quantity.round().clamp(1, 5000);
    }
    return (quantity * gramsPerServing).round().clamp(1, 5000);
  }

  /// Logged meals store [quantity] as grams. [unit] is display-only (bowl/plate).
  static FoodItem _applyLoggedMealServing(
    FoodItem food,
    Map<String, dynamic> json,
  ) {
    if (food.usesHouseholdServing) return food;

    final servingText = _readString(json, const [
      'serving',
      'servingSize',
      'serving_size',
      'portion',
      'servingDescription',
      'serving_description',
    ]);
    final fromText = servingText == null
        ? null
        : FoodServing.parseDescription(servingText);
    if (fromText != null && fromText.isHousehold) {
      return food.copyWith(
        servingQuantity: fromText.quantity,
        servingUnit: fromText.unit,
        gramsPerServing: fromText.gramsPerServing,
        category: food.category ?? FoodServing.categoryFromApi(json),
      );
    }

    final unitRaw = _readString(json, const [
      'servingUnit',
      'serving_unit',
      'unit',
    ]);
    if (unitRaw == null) return food;

    final unit = FoodServing.normalizeUnit(unitRaw);
    if (unit == 'ml') {
      return food.copyWith(
        servingUnit: 'ml',
        gramsPerServing: 1,
        category: food.category ?? FoodServing.categoryFromApi(json),
      );
    }
    if (!FoodServing.isHouseholdUnit(unit)) return food;

    final gramsPerServing = _readInt(json, const [
          'gramsPerServing',
          'grams_per_serving',
        ]) ??
        FoodServing.typicalGramsFor(unit);
    return food.copyWith(
      servingQuantity: 1,
      servingUnit: unit,
      gramsPerServing: gramsPerServing.clamp(1, 5000),
      category: food.category ?? FoodServing.categoryFromApi(json),
    );
  }

  static num _roundMacro(double value) {
    final rounded = value.roundToDouble();
    return rounded == rounded.roundToDouble() ? rounded.round() : rounded;
  }

  static String? _normalizeMealType(dynamic raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
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

  static Map<String, dynamic> _unwrapData(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return json;
  }

  static List<Map<String, dynamic>> _readMealMaps(Map<String, dynamic> data) {
    final meals = data['meals'] ?? data['items'] ?? data['entries'];
    if (meals is List) {
      return meals
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (data.containsKey('food') ||
        data.containsKey('meal') ||
        data.containsKey('mealTime') ||
        data.containsKey('name')) {
      return [data];
    }

    return [];
  }

  static Map<String, dynamic>? _firstMap(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static String? _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static int? _readInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.round();
      if (value is String) return int.tryParse(value);
    }
    return null;
  }

  static double? _readDouble(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
    }
    return null;
  }

  static DateTime? _readDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return MealEntry.normalizeDate(parsed);
    }
    return null;
  }

  static String? _readId(Map<String, dynamic> json) {
    for (final key in const [
      'id',
      '_id',
      'mealId',
      'meal_id',
      'uuid',
      'UID',
      'uid',
    ]) {
      final value = json[key];
      if (value == null) continue;
      if (value is Map) {
        // Mongo extended JSON: { "$oid": "..." }
        final oid = value[r'$oid'] ?? value['oid'] ?? value['id'];
        if (oid != null) {
          final id = oid.toString().trim();
          if (id.isNotEmpty) return id;
        }
        continue;
      }
      final id = value.toString().trim();
      if (id.isNotEmpty && id != 'null') return id;
    }
    return null;
  }
}
