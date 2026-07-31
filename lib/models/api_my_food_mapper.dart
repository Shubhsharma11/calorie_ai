import 'custom_food_preset.dart';
import 'food_item.dart';
import 'meal_type.dart';

/// Maps local custom foods to/from `/api/v1/my-foods`.
abstract final class ApiMyFoodMapper {
  static Map<String, dynamic> toCreateRequestBody({
    required CustomFoodPreset preset,
    required String mealtime,
    String? imageUrl,
  }) {
    final image = imageUrl?.trim() ?? '';
    return {
      'name': preset.food.name,
      'image': image,
      'quantity': preset.displayedServingQuantity,
      'unit': preset.servingUnit,
      'calories': preset.food.caloriesPer100g,
      'carbs': _roundMacro(preset.food.carbs),
      'protein': _roundMacro(preset.food.protein),
      'fat': _roundMacro(preset.food.fat),
      'mealtime': mealtimeForApi(mealtime),
    };
  }

  /// Body for `PATCH /api/v1/my-foods/:myFoodId`.
  static Map<String, dynamic> toPatchRequestBody({
    required CustomFoodPreset preset,
    required String mealtime,
  }) {
    final quantity = preset.displayedServingQuantity;
    final quantityValue = quantity == quantity.roundToDouble()
        ? quantity.round()
        : _roundMacro(quantity);

    return {
      'name': preset.food.name.trim(),
      'quantity': quantityValue,
      'unit': preset.servingUnit.trim().isEmpty ? 'g' : preset.servingUnit.trim(),
      'calories': preset.food.caloriesPer100g,
      'carbs': _roundMacro(preset.food.carbs),
      'protein': _roundMacro(preset.food.protein),
      'fat': _roundMacro(preset.food.fat),
      'mealtime': mealtimeForApi(mealtime),
    };
  }

  /// Body for `POST /api/v1/my-foods/:id/log`.
  static Map<String, dynamic> toLogRequestBody({
    required DateTime date,
    required String mealtime,
    required CustomFoodPreset preset,
  }) {
    final day = DateTime(date.year, date.month, date.day);
    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    return {
      'date': key,
      'mealtime': mealtimeForApi(mealtime),
      'quantity': preset.displayedServingQuantity,
      'unit': preset.servingUnit,
    };
  }

  static String mealtimeForApi(String meal) {
    final normalized = meal.trim().toLowerCase();
    return switch (normalized) {
      'breakfast' => 'breakfast',
      'lunch' => 'lunch',
      'dinner' => 'dinner',
      'snack' || 'snacks' => 'snack',
      _ when meal == MealType.breakfast => 'breakfast',
      _ when meal == MealType.lunch => 'lunch',
      _ when meal == MealType.dinner => 'dinner',
      _ when meal == MealType.snacks => 'snack',
      _ => normalized.isEmpty ? 'snack' : normalized,
    };
  }

  static String mealtimeFromApi(String? raw) {
    final normalized = raw?.trim().toLowerCase() ?? '';
    return switch (normalized) {
      'breakfast' => MealType.breakfast,
      'lunch' => MealType.lunch,
      'dinner' => MealType.dinner,
      'snack' || 'snacks' => MealType.snacks,
      _ => MealType.breakfast,
    };
  }

  static List<CustomFoodPreset> presetsFromResponse(dynamic decoded) {
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
      final nested = data['foods'] ??
          data['myFoods'] ??
          data['items'] ??
          data['results'];
      if (nested is List) {
        return _presetsFromMaps(nested);
      }
      final single = presetFromApiJson(Map<String, dynamic>.from(data));
      return single == null ? [] : [single];
    }

    final topLevel = map['foods'] ?? map['myFoods'] ?? map['items'];
    if (topLevel is List) {
      return _presetsFromMaps(topLevel);
    }

    final single = presetFromApiJson(map);
    return single == null ? [] : [single];
  }

  static CustomFoodPreset? presetFromResponse(
    Map<String, dynamic> json, {
    CustomFoodPreset? source,
  }) {
    final data = _unwrapData(json);
    final parsed = presetFromApiJson(data);
    if (parsed == null) return source;
    if (source == null) return parsed;

    // Keep local nutrition when the API omits fields (common on PATCH).
    // Otherwise missing keys become 0 and wipe the values the user just saved.
    final hasCalories = data.containsKey('calories');
    final hasCarbs = data.containsKey('carbs');
    final hasProtein = data.containsKey('protein');
    final hasFat = data.containsKey('fat');
    final hasQuantity =
        data.containsKey('quantity') || data.containsKey('servingQuantity');
    final hasUnit = data.containsKey('unit');

    final mergedFood = FoodItem(
      name: parsed.food.name,
      caloriesPer100g:
          hasCalories ? parsed.food.caloriesPer100g : source.food.caloriesPer100g,
      protein: hasProtein ? parsed.food.protein : source.food.protein,
      carbs: hasCarbs ? parsed.food.carbs : source.food.carbs,
      fat: hasFat ? parsed.food.fat : source.food.fat,
      emoji: source.food.emoji,
      imageUrl: parsed.food.imageUrl ?? source.food.imageUrl,
    );

    return source.copyWith(
      id: parsed.id,
      food: mergedFood,
      defaultGrams: hasQuantity ? parsed.defaultGrams : source.defaultGrams,
      createdAt: parsed.createdAt,
      servingQuantity:
          hasQuantity ? parsed.servingQuantity : source.servingQuantity,
      servingUnit: hasUnit ? parsed.servingUnit : source.servingUnit,
      nutritionBasisQuantity: hasUnit || hasQuantity
          ? parsed.nutritionBasisQuantity
          : source.nutritionBasisQuantity,
      imageBytes: source.imageBytes,
    );
  }

  static CustomFoodPreset? presetFromApiJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;

    final id = json['id']?.toString() ??
        json['_id']?.toString() ??
        json['myFoodId']?.toString() ??
        json['foodId']?.toString();
    if (id == null || id.isEmpty) return null;

    final quantity =
        (json['quantity'] as num?)?.toDouble() ??
        (json['servingQuantity'] as num?)?.toDouble() ??
        100;
    final unit = (json['unit'] as String?)?.trim().isNotEmpty == true
        ? (json['unit'] as String).trim()
        : 'g';
    final carbs = (json['carbs'] as num?)?.toDouble() ?? 0;
    final protein = (json['protein'] as num?)?.toDouble() ?? 0;
    final fat = (json['fat'] as num?)?.toDouble() ?? 0;
    final calories =
        (json['calories'] as num?)?.round() ??
        (carbs * 4 + protein * 4 + fat * 9).round();

    final defaultGrams = unit == 'g' ? quantity.round().clamp(1, 5000) : 100;

    return CustomFoodPreset(
      id: id,
      food: FoodItem(
        name: name,
        caloriesPer100g: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        emoji: '🥣',
        imageUrl: (json['image'] as String?)?.trim().isNotEmpty == true
            ? (json['image'] as String).trim()
            : (json['imageUrl'] as String?)?.trim().isNotEmpty == true
                ? (json['imageUrl'] as String).trim()
                : null,
      ),
      defaultGrams: defaultGrams,
      createdAt:
          _readDate(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
      servingQuantity: quantity,
      servingUnit: unit,
      nutritionBasisQuantity: unit == 'g' || unit == 'ml' ? 100 : 1,
    );
  }

  static List<CustomFoodPreset> _presetsFromMaps(List<dynamic> items) {
    final presets = <CustomFoodPreset>[];
    for (final item in items) {
      if (item is! Map) continue;
      final preset = presetFromApiJson(Map<String, dynamic>.from(item));
      if (preset != null) presets.add(preset);
    }
    return presets;
  }

  static Map<String, dynamic> _unwrapData(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return json;
  }

  /// Public unwrap used by update parsing (id-only).
  static Map<String, dynamic> unwrapDataForId(Map<String, dynamic> json) =>
      _unwrapData(json);

  static DateTime? _readDate(dynamic raw) {
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  static num _roundMacro(double value) {
    if (value == value.roundToDouble()) return value.round();
    return double.parse(value.toStringAsFixed(2));
  }
}
