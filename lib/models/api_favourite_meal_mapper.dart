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

    final image = imageUrl?.trim() ?? '';
    if (image.isNotEmpty) {
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
    final parsed = itemFromApiJson(_unwrapData(json));
    if (parsed == null) return source;
    if (source == null) return parsed;
    return source.copyWith(
      id: parsed.id,
      food: parsed.food,
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
    final unit = (json['unit'] as String?)?.trim().isNotEmpty == true
        ? (json['unit'] as String).trim()
        : 'g';
    final carbs = (json['carbs'] as num?)?.toDouble() ?? 0;
    final protein = (json['protein'] as num?)?.toDouble() ?? 0;
    final fat = (json['fat'] as num?)?.toDouble() ?? 0;
    final calories =
        (json['calories'] as num?)?.round() ??
        (carbs * 4 + protein * 4 + fat * 9).round();
    final meal = mealtimeFromApi(
      (json['mealtime'] ?? json['mealTime'] ?? json['meal'])?.toString(),
    );

    final grams = unit == 'g' ? quantity.round().clamp(1, 5000) : 100;

    return SavedMealItem(
      id: id,
      food: FoodItem(
        name: name,
        caloriesPer100g: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        emoji: '⭐',
        imageUrl: (json['image'] as String?)?.trim().isNotEmpty == true
            ? (json['image'] as String).trim()
            : (json['imageUrl'] as String?)?.trim().isNotEmpty == true
                ? (json['imageUrl'] as String).trim()
                : null,
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

  static Map<String, dynamic> _unwrapData(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return json;
  }

  static num _roundMacro(double value) {
    if (value == value.roundToDouble()) return value.round();
    return double.parse(value.toStringAsFixed(2));
  }
}
