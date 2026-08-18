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

    test('sends food image on POST when imageUrl arg is omitted', () {
      final withPhoto = SavedMealItem(
        food: item.food.copyWith(imageUrl: 'https://cdn.example.com/oats.png'),
        grams: item.grams,
        meal: item.meal,
        servingQuantity: item.servingQuantity,
        servingUnit: item.servingUnit,
      );

      final body = ApiFavouriteMealMapper.toCreateRequestBody(item: withPhoto);

      expect(body['image'], 'https://cdn.example.com/oats.png');
    });

    test('sends uploads key instead of signed S3 URL', () {
      const signed =
          'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
          'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg'
          '?X-Amz-Signature=abc';
      final withPhoto = SavedMealItem(
        food: item.food.copyWith(imageUrl: signed),
        grams: item.grams,
        meal: item.meal,
        servingQuantity: item.servingQuantity,
        servingUnit: item.servingUnit,
      );

      final body = ApiFavouriteMealMapper.toCreateRequestBody(item: withPhoto);

      expect(body['image'], 'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg');
    });

    test('reads nested and signed favourite images', () {
      const signed =
          'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
          'uploads/f3c0b8fbb88db1c4e7645af0289ee6ed.png'
          '?X-Amz-Signature=abc';

      final nested = ApiFavouriteMealMapper.itemsFromResponse({
        'data': [
          {
            'id': 'fav-2',
            'name': 'Paratha',
            'quantity': 1,
            'unit': 'piece',
            'calories': 260,
            'mealtime': 'breakfast',
            'food': {
              'image': {'url': 'https://cdn.example.com/paratha.png'},
            },
          },
        ],
      });
      expect(nested.single.food.imageUrl, 'https://cdn.example.com/paratha.png');

      final uploads = ApiFavouriteMealMapper.itemFromApiJson({
        'id': 'fav-3',
        'name': 'Yogurt',
        'quantity': 1,
        'unit': 'bowl',
        'calories': 120,
        'mealtime': 'snack',
        'image': 'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg',
      });
      expect(
        uploads!.food.imageUrl,
        'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
        'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg',
      );

      final signedItem = ApiFavouriteMealMapper.itemFromApiJson({
        'id': 'fav-4',
        'name': 'Yogurt',
        'quantity': 1,
        'unit': 'bowl',
        'image': 'uploads/f3c0b8fbb88db1c4e7645af0289ee6ed.png',
        'imageUrl': signed,
      });
      expect(signedItem!.food.imageUrl, signed);
    });

    test('keeps source image when save response omits it', () {
      const source = SavedMealItem(
        food: FoodItem(
          name: 'Oats',
          caloriesPer100g: 155,
          protein: 5,
          carbs: 27,
          fat: 3,
          emoji: '🥣',
          imageUrl: 'https://cdn.example.com/oats.png',
        ),
        grams: 40,
        meal: MealType.breakfast,
        servingQuantity: 40,
        servingUnit: 'g',
      );

      final merged = ApiFavouriteMealMapper.itemFromResponse(
        {
          'data': {
            'id': 'fav-5',
            'name': 'Oats',
            'quantity': 40,
            'unit': 'g',
            'calories': 155,
            'mealtime': 'breakfast',
          },
        },
        source: source,
      );

      expect(merged!.id, 'fav-5');
      expect(merged.food.imageUrl, 'https://cdn.example.com/oats.png');
      expect(merged.food.emoji, '🥣');
    });
  });
}
