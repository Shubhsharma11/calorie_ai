import '../core/media_url.dart';
import 'custom_meal_preset.dart';
import 'food_item.dart';
import 'meal_type.dart';
import 'saved_meal_item.dart';

/// Maps custom meal templates to/from `/api/v1/my-meals`.
abstract final class ApiCustomMealMapper {
  static Map<String, dynamic> toCreateRequestBody(CustomMealPreset preset) {
    final body = <String, dynamic>{
      'name': preset.name,
      'mealTime': _mealTimeToApi(preset.meal),
      'visibility': _visibilityToApi(preset.visibility),
      // Persist totals + per-item macros so GET after re-login is not 0 kcal.
      'calories': preset.totalCalories,
      'protein': _roundMacro(preset.totalProtein),
      'carbs': _roundMacro(preset.totalCarbs),
      'fat': _roundMacro(preset.totalFat),
      'items': preset.items.map(_itemToApiJson).toList(),
    };
    final image = MediaUrl.apiImageKey(preset.imageUrl);
    if (image != null) body['image'] = image;
    return body;
  }

  /// Body for `PATCH /api/v1/my-meals/:myMealId`.
  /// Includes [items] so removed/added foods persist (otherwise the server
  /// keeps the old ingredient list and it reappears after update / log).
  static Map<String, dynamic> toPatchRequestBody({
    required CustomMealPreset preset,
    String? imageUrl,
  }) {
    final body = <String, dynamic>{
      'name': preset.name.trim(),
      'mealTime': _mealTimeToApi(preset.meal),
      'visibility': _visibilityToApi(preset.visibility),
      'calories': preset.totalCalories,
      'protein': _roundMacro(preset.totalProtein),
      'carbs': _roundMacro(preset.totalCarbs),
      'fat': _roundMacro(preset.totalFat),
      'items': preset.items.map(_itemToApiJson).toList(),
    };

    final image =
        MediaUrl.apiImageKey(imageUrl) ?? MediaUrl.apiImageKey(preset.imageUrl);
    if (image != null) {
      body['image'] = image;
    }

    return body;
  }

  static CustomMealPreset presetFromResponse(
    Map<String, dynamic> json, {
    required CustomMealPreset source,
  }) {
    final parsed = presetFromApiJson(_unwrapData(json));
    if (parsed == null) return source;

    // Prefer the items we just sent on create/update. Some PATCH responses
    // still return the previous ingredient list, which resurrected removed foods.
    final items = source.items.isNotEmpty
        ? source.items
        : (parsed.items.isNotEmpty
            ? _preserveServingMetadata(parsed.items, source.items)
            : source.items);

    return source.copyWith(
      id: parsed.id,
      name: parsed.name,
      meal: parsed.meal,
      items: items,
      visibility: parsed.visibility,
      createdAt: parsed.createdAt,
      imageUrl: parsed.imageUrl ?? source.imageUrl,
      imageBytes: source.imageBytes,
    );
  }

  static List<SavedMealItem> _preserveServingMetadata(
    List<SavedMealItem> parsed,
    List<SavedMealItem> source,
  ) {
    return parsed.map((item) {
      SavedMealItem? matchingSource;
      for (final candidate in source) {
        if (candidate.food.name.trim().toLowerCase() ==
            item.food.name.trim().toLowerCase()) {
          matchingSource = candidate;
          break;
        }
      }
      if (matchingSource == null) return item;
      final imageUrl = MediaUrl.preferLoadable([
        item.food.imageUrl,
        matchingSource.food.imageUrl,
      ]);
      final parsedEmoji = item.food.emoji.trim();
      final keepParsedEmoji = parsedEmoji.isNotEmpty &&
          parsedEmoji != '🍽️' &&
          !MediaUrl.looksLikeImageRef(parsedEmoji);
      return item.copyWith(
        food: item.food.copyWith(
          imageUrl: imageUrl,
          emoji: keepParsedEmoji ? parsedEmoji : matchingSource.food.emoji,
        ),
        servingQuantity: matchingSource.servingQuantity,
        servingUnit: matchingSource.servingUnit,
        nutritionBasisQuantity: matchingSource.nutritionBasisQuantity,
        basisCarbs: matchingSource.basisCarbs,
        basisProtein: matchingSource.basisProtein,
        basisFat: matchingSource.basisFat,
      );
    }).toList();
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
      final nested = _nestedMealList(Map<String, dynamic>.from(data));
      if (nested != null) {
        return _presetsFromMaps(nested);
      }

      final single = presetFromApiJson(Map<String, dynamic>.from(data));
      return single == null ? [] : [single];
    }

    final topLevel = _nestedMealList(map);
    if (topLevel != null) {
      return _presetsFromMaps(topLevel);
    }

    final single = presetFromApiJson(map);
    return single == null ? [] : [single];
  }

  static CustomMealPreset? presetFromApiJson(Map<String, dynamic> json) {
    final mealJson = _unwrapData(json);
    final name = _readString(mealJson, const ['name', 'title', 'mealName']);
    if (name == null || name.isEmpty) return null;

    final id = _readId(mealJson);
    if (id == null || id.isEmpty) return null;

    final meal = _mealTimeFromApi(
          mealJson['mealTime'] ?? mealJson['mealtime'] ?? mealJson['meal'],
        ) ??
        MealType.breakfast;
    final items = _hydrateItemsNutritionFromMeal(
      mealJson,
      _itemsFromApi(
        mealJson['items'] ?? mealJson['foods'] ?? mealJson['mealItems'],
        fallbackMeal: meal,
      ),
    );

    return CustomMealPreset(
      id: id,
      name: name.trim(),
      createdAt: _readDate(mealJson['createdAt'] ?? mealJson['created_at']) ??
          DateTime.now(),
      meal: meal,
      items: items,
      visibility: _visibilityFromApi(
        _readString(mealJson, const ['visibility']),
      ),
      imageUrl: MediaUrl.fromJson(mealJson),
    );
  }

  /// When item rows lack macros but the meal has totals (common for older
  /// templates), spread meal nutrition onto items so UI is not 0 kcal.
  static List<SavedMealItem> _hydrateItemsNutritionFromMeal(
    Map<String, dynamic> mealJson,
    List<SavedMealItem> items,
  ) {
    if (items.isEmpty) return items;
    final itemCalories = items.fold<int>(0, (sum, item) => sum + item.calories);
    if (itemCalories > 0) return items;

    final nutrients = mealJson['totalNutrients'];
    final nutrientMap =
        nutrients is Map ? Map<String, dynamic>.from(nutrients) : null;

    final mealCalories = _readInt(
          mealJson,
          const ['calories', 'totalCalories', 'kcal'],
        ) ??
        (nutrientMap == null
            ? null
            : _readInt(nutrientMap, const ['calories', 'kcal'])) ??
        0;
    if (mealCalories <= 0) return items;

    final mealProtein = _readDouble(mealJson, const ['protein']) ??
        (nutrientMap == null
            ? null
            : _readDouble(nutrientMap, const ['protein'])) ??
        0;
    final mealCarbs = _readDouble(mealJson, const ['carbs']) ??
        (nutrientMap == null
            ? null
            : _readDouble(nutrientMap, const ['carbs'])) ??
        0;
    final mealFat = _readDouble(mealJson, const ['fat']) ??
        (nutrientMap == null
            ? null
            : _readDouble(nutrientMap, const ['fat'])) ??
        0;

    final weights = items
        .map((item) => item.grams > 0 ? item.grams : 1)
        .toList(growable: false);
    final totalWeight = weights.fold<int>(0, (sum, w) => sum + w);
    if (totalWeight <= 0) return items;

    var assignedCalories = 0;
    var assignedProtein = 0.0;
    var assignedCarbs = 0.0;
    var assignedFat = 0.0;
    final hydrated = <SavedMealItem>[];

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isLast = i == items.length - 1;
      final share = weights[i] / totalWeight;
      final portionCalories = isLast
          ? mealCalories - assignedCalories
          : (mealCalories * share).round();
      final portionProtein = isLast
          ? mealProtein - assignedProtein
          : mealProtein * share;
      final portionCarbs =
          isLast ? mealCarbs - assignedCarbs : mealCarbs * share;
      final portionFat = isLast ? mealFat - assignedFat : mealFat * share;

      assignedCalories += portionCalories;
      assignedProtein += portionProtein;
      assignedCarbs += portionCarbs;
      assignedFat += portionFat;

      final quantity = item.grams > 0 ? item.grams : 1;
      final per100 = 100 / quantity;
      hydrated.add(
        item.copyWith(
          food: item.food.copyWith(
            caloriesPer100g: portionCalories > 0
                ? (portionCalories * per100).round()
                : 0,
            protein: portionProtein * per100,
            carbs: portionCarbs * per100,
            fat: portionFat * per100,
          ),
        ),
      );
    }

    return hydrated;
  }

  static List<dynamic>? _nestedMealList(Map<String, dynamic> map) {
    for (final key in [
      'myMeals',
      'meals',
      'customMeals',
      'templates',
      'results',
      'docs',
    ]) {
      final value = map[key];
      if (value is List) return value;
    }
    // `items` is a food list on a meal object — only treat it as meals when
    // this map is not itself a meal.
    if (!_looksLikeMeal(map)) {
      final items = map['items'];
      if (items is List) return items;
    }
    return null;
  }

  static bool _looksLikeMeal(Map<String, dynamic> map) {
    if (map['mealTime'] != null || map['mealtime'] != null) return true;
    if (map['name'] != null && map['items'] is List) return true;
    if (map['myMeal'] is Map || map['meal'] is Map) return true;
    return false;
  }

  static List<CustomMealPreset> _presetsFromMaps(Iterable<dynamic> raw) {
    final presets = <CustomMealPreset>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        final parsed = presetFromApiJson(Map<String, dynamic>.from(item));
        if (parsed != null) presets.add(parsed);
      } catch (_) {
        // Skip a malformed template instead of dropping the whole list.
      }
    }
    return presets;
  }

  static Map<String, dynamic> _itemToApiJson(SavedMealItem item) {
    final quantity = item.hasServingNutrition
        ? item.displayedServingQuantity
        : item.grams;
    final unit = item.hasServingNutrition
        ? (item.servingUnit.trim().isEmpty ? 'g' : item.servingUnit.trim())
        : 'g';

    final body = <String, dynamic>{
      'name': item.food.name,
      'quantity': quantity is int ? quantity : _roundMacro(quantity.toDouble()),
      'unit': unit == 'gm' ? 'g' : unit,
      'calories': item.calories,
      'protein': _roundMacro(item.protein),
      'carbs': _roundMacro(item.carbs),
      'fat': _roundMacro(item.fat),
    };
    final image = _itemImageForApi(item.food.imageUrl);
    if (image != null) body['image'] = image;
    return body;
  }

  static String? _itemImageForApi(String? imageUrl) {
    final key = MediaUrl.apiImageKey(imageUrl);
    if (key != null) return key;
    final resolved = MediaUrl.resolve(imageUrl);
    if (resolved == null || resolved.isEmpty) return null;
    final lower = resolved.toLowerCase();
    if (lower.contains('x-amz-signature=') || lower.contains('signature=')) {
      return null;
    }
    return resolved;
  }

  static List<SavedMealItem> savedItemsFromApi(
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

  static List<SavedMealItem> _itemsFromApi(
    dynamic rawItems, {
    required String fallbackMeal,
  }) =>
      savedItemsFromApi(rawItems, fallbackMeal: fallbackMeal);

  static SavedMealItem? _itemFromApiJson(
    Map<String, dynamic> json, {
    required String fallbackMeal,
  }) {
    final nestedFood = json['food'];
    final foodMap = nestedFood is Map
        ? Map<String, dynamic>.from(nestedFood)
        : const <String, dynamic>{};
    final name = _readString(json, const ['name', 'foodName', 'title']) ??
        _readString(foodMap, const ['name', 'foodName', 'title']);
    if (name == null || name.isEmpty) return null;

    final quantity = _readInt(json, const ['quantity', 'grams', 'servingGrams']) ??
        _readInt(foodMap, const ['quantity', 'grams', 'servingGrams']);
    if (quantity == null || quantity <= 0) return null;

    final protein = _readDouble(json, const ['protein']) ??
        _readDouble(foodMap, const ['protein']) ??
        0;
    final carbs = _readDouble(json, const ['carbs']) ??
        _readDouble(foodMap, const ['carbs']) ??
        0;
    final fat = _readDouble(json, const ['fat']) ??
        _readDouble(foodMap, const ['fat']) ??
        0;
    var calories = _readInt(json, const ['calories', 'kcal']) ??
        _readInt(foodMap, const ['calories', 'kcal']) ??
        0;
    if (calories <= 0 && (protein > 0 || carbs > 0 || fat > 0)) {
      calories = (carbs * 4 + protein * 4 + fat * 9).round();
    }

    final per100Factor = 100 / quantity;
    final imageUrl = MediaUrl.preferLoadable([
      MediaUrl.fromJson(json),
      if (foodMap.isNotEmpty) MediaUrl.fromJson(foodMap),
    ]);
    final food = FoodItem(
      name: name.trim(),
      caloriesPer100g: calories > 0
          ? (calories * per100Factor).round()
          : 0,
      protein: protein * per100Factor,
      carbs: carbs * per100Factor,
      fat: fat * per100Factor,
      emoji: _emojiFromItem(json, foodMap),
      imageUrl: imageUrl,
    );

    return SavedMealItem(
      food: food,
      grams: quantity,
      meal: fallbackMeal,
    );
  }

  static String _mealTimeToApi(String meal) {
    final normalized = meal.trim().toLowerCase();
    return switch (normalized) {
      'breakfast' => 'breakfast',
      'lunch' => 'lunch',
      'dinner' => 'dinner',
      'snack' || 'snacks' => 'snack',
      _ => normalized.isEmpty ? 'lunch' : normalized,
    };
  }

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
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final nested = map['meal'] ?? map['myMeal'] ?? map['template'];
      if (nested is Map) {
        return Map<String, dynamic>.from(nested);
      }
      return map;
    }
    final topNested = json['meal'] ?? json['myMeal'] ?? json['template'];
    if (topNested is Map) {
      return Map<String, dynamic>.from(topNested);
    }
    return json;
  }

  static String? _readId(Map<String, dynamic> json) {
    for (final key in ['id', '_id', 'myMealId', 'mealId']) {
      final raw = json[key];
      if (raw == null) continue;
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      if (raw is num) return raw.toString();
      if (raw is Map) {
        final oid = raw[r'$oid'] ?? raw['oid'] ?? raw['id'];
        if (oid != null) {
          final value = oid.toString().trim();
          if (value.isNotEmpty) return value;
        }
      }
    }
    return null;
  }

  static DateTime? _readDate(dynamic raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  static String _emojiFromItem(
    Map<String, dynamic> json,
    Map<String, dynamic> foodMap,
  ) {
    for (final map in [json, foodMap]) {
      for (final key in const ['emoji', 'icon']) {
        final value = map[key];
        if (value is! String) continue;
        final trimmed = value.trim();
        if (trimmed.isEmpty || MediaUrl.looksLikeImageRef(trimmed)) continue;
        return trimmed;
      }
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

  static int? _readInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.round();
      if (value is String) {
        final parsed = num.tryParse(value.trim());
        if (parsed != null) return parsed.round();
      }
    }
    return null;
  }

  static double? _readDouble(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = num.tryParse(value.trim());
        if (parsed != null) return parsed.toDouble();
      }
    }
    return null;
  }

  static num _roundMacro(double value) {
    final rounded = value.roundToDouble();
    return rounded == rounded.roundToDouble() ? rounded.round() : rounded;
  }
}
