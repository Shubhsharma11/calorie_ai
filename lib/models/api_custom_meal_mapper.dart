import 'custom_meal_preset.dart';
import 'food_item.dart';
import 'meal_type.dart';
import 'saved_meal_item.dart';

/// Maps custom meal templates to/from `POST /api/v1/meals/custom`.
abstract final class ApiCustomMealMapper {
  static Map<String, dynamic> toCreateRequestBody(CustomMealPreset preset) {
    return {
      'name': preset.name,
      'mealTime': _mealTimeToApi(preset.meal),
      'visibility': _visibilityToApi(preset.visibility),
      'items': preset.items.map(_itemToApiJson).toList(),
    };
  }

  static CustomMealPreset presetFromResponse(
    Map<String, dynamic> json, {
    required CustomMealPreset source,
  }) {
    final parsed = presetFromApiJson(_unwrapData(json));
    if (parsed == null) return source;

    return source.copyWith(
      id: parsed.id,
      name: parsed.name,
      meal: parsed.meal,
      items: parsed.items.isNotEmpty ? parsed.items : source.items,
      visibility: parsed.visibility,
      createdAt: parsed.createdAt,
    );
  }

  static List<CustomMealPreset> presetsFromResponse(dynamic decoded) {
    if (decoded is List) {
      return _presetsFromMaps(decoded);
    }

    if (decoded is! Map) return [];

    final map = Map<String, dynamic>.from(decoded);
    final data = map['data'];

    if (data is List) {
      return _presetsFromMaps(data);
    }

    if (data is Map) {
      final nested = data['meals'] ??
          data['customMeals'] ??
          data['templates'] ??
          data['items'];
      if (nested is List) {
        return _presetsFromMaps(nested);
      }

      final single = presetFromApiJson(Map<String, dynamic>.from(data));
      return single == null ? [] : [single];
    }

    final topLevel = map['meals'] ?? map['customMeals'] ?? map['items'];
    if (topLevel is List) {
      return _presetsFromMaps(topLevel);
    }

    final single = presetFromApiJson(map);
    return single == null ? [] : [single];
  }

  static CustomMealPreset? presetFromApiJson(Map<String, dynamic> json) {
    final name = json['name'] as String?;
    if (name == null || name.trim().isEmpty) return null;

    final id = json['id']?.toString() ?? json['_id']?.toString();
    if (id == null || id.isEmpty) return null;

    final meal = _mealTimeFromApi(
          json['mealTime'] ?? json['mealtime'] ?? json['meal'],
        ) ??
        MealType.breakfast;
    final items = _itemsFromApi(json['items'], fallbackMeal: meal);

    return CustomMealPreset(
      id: id,
      name: name.trim(),
      createdAt:
          _readDate(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
      meal: meal,
      items: items,
      visibility: _visibilityFromApi(json['visibility'] as String?),
    );
  }

  static List<CustomMealPreset> _presetsFromMaps(Iterable<dynamic> raw) {
    return raw
        .whereType<Map>()
        .map((item) => presetFromApiJson(Map<String, dynamic>.from(item)))
        .whereType<CustomMealPreset>()
        .toList();
  }

  static Map<String, dynamic> _itemToApiJson(SavedMealItem item) {
    final protein = item.food.macroForGrams(item.food.protein, item.grams);
    final fat = item.food.macroForGrams(item.food.fat, item.grams);
    final carbs = item.food.macroForGrams(item.food.carbs, item.grams);

    return {
      'name': item.food.name,
      'quantity': item.grams,
      'unit': 'gm',
      'calories': item.calories,
      'protein': _roundMacro(protein),
      'fat': _roundMacro(fat),
      'carbs': _roundMacro(carbs),
    };
  }

  static List<SavedMealItem> _itemsFromApi(
    dynamic rawItems, {
    required String fallbackMeal,
  }) {
    if (rawItems is! List) return [];

    return rawItems
        .whereType<Map>()
        .map((item) => _itemFromApiJson(
              Map<String, dynamic>.from(item),
              fallbackMeal: fallbackMeal,
            ))
        .whereType<SavedMealItem>()
        .toList();
  }

  static SavedMealItem? _itemFromApiJson(
    Map<String, dynamic> json, {
    required String fallbackMeal,
  }) {
    final name = json['name'] as String?;
    if (name == null || name.trim().isEmpty) return null;

    final quantity = _readInt(json, const ['quantity', 'grams', 'servingGrams']);
    if (quantity == null || quantity <= 0) return null;

    final calories = _readInt(json, const ['calories']) ?? 0;
    final protein = _readDouble(json, const ['protein']) ?? 0;
    final carbs = _readDouble(json, const ['carbs']) ?? 0;
    final fat = _readDouble(json, const ['fat']) ?? 0;

    final per100Factor = 100 / quantity;
    final food = FoodItem(
      name: name.trim(),
      caloriesPer100g: calories > 0
          ? (calories * per100Factor).round()
          : 0,
      protein: protein * per100Factor,
      carbs: carbs * per100Factor,
      fat: fat * per100Factor,
    );

    return SavedMealItem(
      food: food,
      grams: quantity,
      meal: fallbackMeal,
    );
  }

  static String _mealTimeToApi(String meal) => meal.toLowerCase();

  static String? _mealTimeFromApi(dynamic raw) {
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

  static String _visibilityToApi(MealShareVisibility visibility) {
    return switch (visibility) {
      MealShareVisibility.public => 'public',
      MealShareVisibility.onlyMe => 'private',
    };
  }

  static MealShareVisibility _visibilityFromApi(String? value) {
    return switch (value?.toLowerCase()) {
      'public' => MealShareVisibility.public,
      'only_me' || 'onlyme' || 'only me' => MealShareVisibility.onlyMe,
      'private' => MealShareVisibility.onlyMe,
      _ => MealShareVisibility.onlyMe,
    };
  }

  static Map<String, dynamic> _unwrapData(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return json;
  }

  static DateTime? _readDate(dynamic raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  static int? _readInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.round();
    }
    return null;
  }

  static double? _readDouble(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value.toDouble();
    }
    return null;
  }

  static num _roundMacro(double value) {
    final rounded = value.roundToDouble();
    return rounded == rounded.roundToDouble() ? rounded.round() : rounded;
  }
}
