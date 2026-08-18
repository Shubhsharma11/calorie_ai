import '../core/food_serving.dart';
import '../core/media_url.dart';
import 'food_item.dart';
import 'meal_type.dart';
import 'saved_meal_item.dart';

/// Maps local favourites to/from `/api/v1/favourite-meals`.
abstract final class ApiFavouriteMealMapper {
  static Map<String, dynamic> toCreateRequestBody({
    required SavedMealItem item,
    String? imageUrl,
  }) {
    final quantity = item.displayedServingQuantity;
    final quantityValue = quantity == quantity.roundToDouble()
        ? quantity.round()
        : _roundMacro(quantity);

    final body = <String, dynamic>{
      'name': item.food.name.trim(),
      'calories': item.calories,
      'quantity': quantityValue,
      'unit': item.servingUnit.trim().isEmpty ? 'g' : item.servingUnit.trim(),
      'carbs': _roundMacro(item.carbs),
      'protein': _roundMacro(item.protein),
      'fat': _roundMacro(item.fat),
      'mealtime': mealtimeForApi(item.meal),
    };

    final image = _itemImageForApi(imageUrl) ?? _itemImageForApi(item.food.imageUrl);
    if (image != null) {
      body['image'] = image;
    }

    return body;
  }

  /// Body for `POST /api/v1/favourite-meals/:id/log`.
  static Map<String, dynamic> toLogRequestBody({
    required DateTime date,
    required String mealtime,
    required SavedMealItem item,
  }) {
    final day = DateTime(date.year, date.month, date.day);
    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    final quantity = item.displayedServingQuantity;
    final quantityValue = quantity == quantity.roundToDouble()
        ? quantity.round()
        : _roundMacro(quantity);
    return {
      'date': key,
      'mealtime': mealtimeForApi(mealtime),
      'quantity': quantityValue,
      'unit': item.servingUnit.trim().isEmpty ? 'g' : item.servingUnit.trim(),
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

  static List<SavedMealItem> itemsFromResponse(dynamic decoded) {
    if (decoded is List) {
      return _itemsFromMaps(decoded);
    }
    if (decoded is! Map) return [];

    final map = Map<String, dynamic>.from(decoded);
    final data = map['data'];

    if (data is List) {
      return _itemsFromMaps(data);
    }

    if (data is Map) {
      final nested = data['favouriteMeals'] ??
          data['favoriteMeals'] ??
          data['favourites'] ??
          data['favorites'] ??
          data['items'] ??
          data['results'];
      if (nested is List) {
        return _itemsFromMaps(nested);
      }
      final single = itemFromApiJson(Map<String, dynamic>.from(data));
      return single == null ? [] : [single];
    }

    final topLevel = map['favouriteMeals'] ??
        map['favoriteMeals'] ??
        map['favourites'] ??
        map['favorites'] ??
        map['items'];
    if (topLevel is List) {
      return _itemsFromMaps(topLevel);
    }

    final single = itemFromApiJson(map);
    return single == null ? [] : [single];
  }

  static SavedMealItem? itemFromResponse(
    Map<String, dynamic> json, {
    SavedMealItem? source,
  }) {
    final parsed = itemFromApiJson(_normalizeApiJson(json));
    if (parsed == null) return source;
    if (source == null) return parsed;

    final parsedEmoji = parsed.food.emoji.trim();
    final keepParsedEmoji = parsedEmoji.isNotEmpty &&
        parsedEmoji != '🍽️' &&
        parsedEmoji != '⭐' &&
        !MediaUrl.looksLikeImageRef(parsedEmoji);

    return source.copyWith(
      id: parsed.id,
      food: parsed.food.copyWith(
        imageUrl: MediaUrl.preferLoadable([
          parsed.food.imageUrl,
          source.food.imageUrl,
        ]),
        emoji: keepParsedEmoji ? parsedEmoji : source.food.emoji,
      ),
      grams: parsed.grams,
      meal: parsed.meal,
      servingQuantity: parsed.servingQuantity,
      servingUnit: parsed.servingUnit,
      nutritionBasisQuantity: parsed.nutritionBasisQuantity,
      basisCarbs: parsed.basisCarbs,
      basisProtein: parsed.basisProtein,
      basisFat: parsed.basisFat,
    );
  }

  static SavedMealItem? itemFromApiJson(Map<String, dynamic> json) {
    json = _normalizeApiJson(json);
    final name = (json['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;

    final id = json['id']?.toString() ??
        json['_id']?.toString() ??
        json['favouriteMealId']?.toString() ??
        json['favoriteMealId']?.toString();
    if (id == null || id.isEmpty) return null;

    final quantity =
        (json['quantity'] as num?)?.toDouble() ??
        (json['servingQuantity'] as num?)?.toDouble() ??
        100;
    final unit = FoodServing.normalizeUnit(
      (json['unit'] as String?)?.trim().isNotEmpty == true
          ? (json['unit'] as String).trim()
          : 'g',
    );
    final carbs = (json['carbs'] as num?)?.toDouble() ?? 0;
    final protein = (json['protein'] as num?)?.toDouble() ?? 0;
    final fat = (json['fat'] as num?)?.toDouble() ?? 0;
    final calories =
        (json['calories'] as num?)?.round() ??
        (carbs * 4 + protein * 4 + fat * 9).round();
    final meal = mealtimeFromApi(
      (json['mealtime'] ?? json['mealTime'] ?? json['meal'])?.toString(),
    );

    final household = FoodServing.isHouseholdUnit(unit);
    final grams = unit == 'g' || unit == 'ml'
        ? quantity.round().clamp(1, 5000)
        : 100;

    return SavedMealItem(
      id: id,
      food: FoodItem(
        name: name,
        caloriesPer100g: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        emoji: _emojiFromApi(json),
        imageUrl: MediaUrl.fromJson(json),
        servingQuantity: household ? 1 : quantity,
        servingUnit: unit,
        gramsPerServing: 1,
      ),
      grams: grams,
      meal: meal,
      servingQuantity: quantity,
      servingUnit: unit,
      nutritionBasisQuantity: unit == 'g' || unit == 'ml' ? 100 : 1,
      basisCarbs: carbs,
      basisProtein: protein,
      basisFat: fat,
    );
  }

  static List<SavedMealItem> _itemsFromMaps(List<dynamic> items) {
    final result = <SavedMealItem>[];
    for (final item in items) {
      if (item is! Map) continue;
      final parsed = itemFromApiJson(Map<String, dynamic>.from(item));
      if (parsed != null) result.add(parsed);
    }
    return result;
  }

  static Map<String, dynamic> _normalizeApiJson(Map<String, dynamic> json) {
    var map = Map<String, dynamic>.from(json);
    final data = map['data'];
    if (data is Map) {
      map = Map<String, dynamic>.from(data);
    }

    final nested =
        map['food'] ??
        map['favouriteMeal'] ??
        map['favoriteMeal'] ??
        map['item'];
    if (nested is Map) {
      final nestedMap = Map<String, dynamic>.from(nested);
      map['name'] ??= nestedMap['name'];
      map['id'] ??= nestedMap['id'] ?? nestedMap['_id'];
      for (final key in const [
        'image',
        'imageUrl',
        'image_url',
        'photo',
        'thumbnail',
        'icon',
        'signedUrl',
        'quantity',
        'unit',
        'calories',
        'carbs',
        'protein',
        'fat',
        'mealtime',
        'mealTime',
        'meal',
        'emoji',
      ]) {
        if (!_hasValue(map[key]) && _hasValue(nestedMap[key])) {
          map[key] = nestedMap[key];
        }
      }
    }
    return map;
  }

  static bool _hasValue(Object? value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    if (value is List) return value.isNotEmpty;
    return true;
  }

  static String _emojiFromApi(Map<String, dynamic> json) {
    for (final key in const ['emoji', 'icon']) {
      final value = json[key];
      if (value is! String) continue;
      final trimmed = value.trim();
      if (trimmed.isEmpty || MediaUrl.looksLikeImageRef(trimmed)) continue;
      if (trimmed == '⭐') continue;
      return trimmed;
    }
    return '🍽️';
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

  static num _roundMacro(double value) {
    if (value == value.roundToDouble()) return value.round();
    return double.parse(value.toStringAsFixed(2));
  }
}
