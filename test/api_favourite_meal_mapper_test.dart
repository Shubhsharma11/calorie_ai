import 'package:calorie_ai/models/api_favourite_meal_mapper.dart';
import 'package:calorie_ai/models/food_item.dart';
import 'package:calorie_ai/models/meal_type.dart';
import 'package:calorie_ai/models/saved_meal_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiFavouriteMealMapper', () {
    const item = SavedMealItem(
      food: FoodItem(
        name: 'Oats',
        caloriesPer100g: 155,
        protein: 5,
        carbs: 27,
        fat: 3,
      ),
      grams: 40,
      meal: MealType.breakfast,
      servingQuantity: 40,
      servingUnit: 'g',
    );

    test('builds POST /api/v1/favourite-meals body', () {
      final body = ApiFavouriteMealMapper.toCreateRequestBody(
        item: item,
        imageUrl: 'https://example.com/oats.jpg',
      );

      expect(body, {
        'name': 'Oats',
        'calories': 62,
        'quantity': 40,
        'unit': 'g',
        'carbs': 10.8,
        'protein': 2,
        'fat': 1.2,
        'mealtime': 'breakfast',
        'image': 'https://example.com/oats.jpg',
      });
    });

    test('builds POST /api/v1/favourite-meals/:id/log body', () {
      final body = ApiFavouriteMealMapper.toLogRequestBody(
        date: DateTime(2026, 7, 21),
        mealtime: MealType.lunch,
        item: item,
      );

      expect(body, {
        'date': '2026-07-21',
        'mealtime': 'lunch',
        'quantity': 40,
        'unit': 'g',
      });
    });

    test('maps snacks mealtime to snack', () {
      expect(ApiFavouriteMealMapper.mealtimeForApi(MealType.snacks), 'snack');
      expect(ApiFavouriteMealMapper.mealtimeFromApi('snack'), MealType.snacks);
    });

    test('parses list response from data array', () {
      final items = ApiFavouriteMealMapper.itemsFromResponse({
        'data': [
          {
            'id': 'fav-1',
            'name': 'Oats',
            'quantity': 40,
            'unit': 'g',
            'carbs': 27,
            'protein': 5,
            'fat': 3,
            'calories': 155,
            'mealtime': 'breakfast',
          },
        ],
      });

      expect(items, hasLength(1));
      expect(items.first.id, 'fav-1');
      expect(items.first.food.name, 'Oats');
      expect(items.first.meal, MealType.breakfast);
      expect(items.first.hasServerId, isTrue);
    });
  });
}
