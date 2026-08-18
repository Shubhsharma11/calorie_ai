import 'package:calorie_ai/models/api_my_food_mapper.dart';
import 'package:calorie_ai/models/custom_food_preset.dart';
import 'package:calorie_ai/models/food_item.dart';
import 'package:calorie_ai/models/meal_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiMyFoodMapper', () {
    final preset = CustomFoodPreset(
      id: 'local-1',
      food: const FoodItem(
        name: 'Rice',
        caloriesPer100g: 130,
        protein: 2.7,
        carbs: 28,
        fat: 0.3,
      ),
      defaultGrams: 100,
      createdAt: DateTime(2026, 7, 17),
      servingQuantity: 100,
      servingUnit: 'g',
    );

    test('builds POST /api/v1/my-foods body', () {
      final body = ApiMyFoodMapper.toCreateRequestBody(
        preset: preset,
        mealtime: MealType.dinner,
        imageUrl: 'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg',
      );

      expect(body, {
        'name': 'Rice',
        'image': 'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg',
        'quantity': 100,
        'unit': 'g',
        'calories': 130,
        'carbs': 28,
        'protein': 2.7,
        'fat': 0.3,
        'mealtime': 'dinner',
      });
    });

    test('builds PATCH /api/v1/my-foods/:id body', () {
      final edited = CustomFoodPreset(
        id: 'food-1',
        food: const FoodItem(
          name: 'Rice',
          caloriesPer100g: 188,
          protein: 4,
          carbs: 42,
          fat: 0.5,
        ),
        defaultGrams: 150,
        createdAt: DateTime(2026, 7, 17),
        servingQuantity: 150,
        servingUnit: 'g',
      );

      final body = ApiMyFoodMapper.toPatchRequestBody(
        preset: edited,
        mealtime: MealType.dinner,
      );

      expect(body, {
        'name': 'Rice',
        'quantity': 150,
        'unit': 'g',
        'calories': 188,
        'carbs': 42,
        'protein': 4,
        'fat': 0.5,
        'mealtime': 'dinner',
      });
      expect(body.containsKey('image'), isFalse);
    });

    test('sends uploads object key, not the signed S3 URL', () {
      const signed =
          'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
          'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg?X-Amz-Signature=abc';
      final body = ApiMyFoodMapper.toCreateRequestBody(
        preset: preset,
        mealtime: MealType.dinner,
        imageUrl: signed,
      );
      expect(body['image'], 'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg');
    });

    test('PATCH includes image key when present', () {
      final edited = CustomFoodPreset(
        id: 'food-1',
        food: const FoodItem(
          name: 'Rice',
          caloriesPer100g: 188,
          protein: 4,
          carbs: 42,
          fat: 0.5,
          imageUrl:
              'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
              'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg',
        ),
        defaultGrams: 150,
        createdAt: DateTime(2026, 7, 17),
        servingQuantity: 150,
        servingUnit: 'g',
      );

      final body = ApiMyFoodMapper.toPatchRequestBody(
        preset: edited,
        mealtime: MealType.dinner,
      );

      expect(body['image'], 'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg');
    });

    test('keeps source nutrition when PATCH response omits macros', () {
      final source = CustomFoodPreset(
        id: 'food-1',
        food: const FoodItem(
          name: 'Rice',
          caloriesPer100g: 200,
          protein: 5,
          carbs: 40,
          fat: 1,
        ),
        defaultGrams: 150,
        createdAt: DateTime(2026, 7, 17),
        servingQuantity: 150,
        servingUnit: 'g',
        nutritionBasisQuantity: 100,
      );

      final merged = ApiMyFoodMapper.presetFromResponse(
        {
          'data': {
            'id': 'food-1',
            'name': 'Rice',
          },
        },
        source: source,
      );

      expect(merged, isNotNull);
      expect(merged!.food.caloriesPer100g, 200);
      expect(merged.food.carbs, 40);
      expect(merged.food.protein, 5);
      expect(merged.food.fat, 1);
      expect(merged.servingQuantity, 150);
    });

    test('builds POST /api/v1/my-foods/:id/log body', () {
      final body = ApiMyFoodMapper.toLogRequestBody(
        date: DateTime(2026, 7, 17),
        mealtime: MealType.breakfast,
        preset: preset,
      );

      expect(body, {
        'date': '2026-07-17',
        'mealtime': 'breakfast',
        'quantity': 100,
        'unit': 'g',
      });
    });

    test('maps snacks mealtime to snack', () {
      expect(ApiMyFoodMapper.mealtimeForApi(MealType.snacks), 'snack');
      expect(ApiMyFoodMapper.mealtimeForApi('Snacks'), 'snack');
      expect(ApiMyFoodMapper.mealtimeFromApi('snack'), MealType.snacks);
    });

    test('parses list response from data array', () {
      final presets = ApiMyFoodMapper.presetsFromResponse({
        'data': [
          {
            'id': 'food-1',
            'name': 'Oats',
            'quantity': 40,
            'unit': 'g',
            'carbs': 27,
            'protein': 5,
            'fat': 3,
            'calories': 155,
          },
        ],
      });

      expect(presets, hasLength(1));
      expect(presets.first.id, 'food-1');
      expect(presets.first.food.name, 'Oats');
      expect(presets.first.servingQuantity, 40);
      expect(presets.first.food.protein, 5);
    });

    test('parses single food from response data', () {
      final parsed = ApiMyFoodMapper.presetFromResponse({
        'data': {
          '_id': 'abc123',
          'name': 'Yogurt',
          'quantity': 1,
          'unit': 'serving',
          'carbs': 12,
          'protein': 10,
          'fat': 4,
        },
      });

      expect(parsed, isNotNull);
      expect(parsed!.id, 'abc123');
      expect(parsed.food.name, 'Yogurt');
      expect(parsed.servingUnit, 'serving');
    });

    test('resolves uploads key from image field', () {
      final parsed = ApiMyFoodMapper.presetFromResponse({
        'data': {
          'id': 'food-1',
          'name': 'Yogurt',
          'quantity': 1,
          'unit': 'bowl',
          'image': 'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg',
        },
      });

      expect(parsed, isNotNull);
      expect(
        parsed!.food.imageUrl,
        'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
        'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg',
      );
    });

    test('keeps signed S3 image from GET my-foods', () {
      const signed =
          'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
          'uploads/f3c0b8fbb88db1c4e7645af0289ee6ed.png'
          '?X-Amz-Signature=abc';
      final parsed = ApiMyFoodMapper.presetFromResponse({
        'data': {
          'id': 'food-1',
          'name': 'Yogurt',
          'quantity': 1,
          'unit': 'bowl',
          'image': signed,
        },
      });

      expect(parsed, isNotNull);
      expect(parsed!.food.imageUrl, signed);
    });

    test('uses the parent image when nested food omits it', () {
      const signed =
          'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
          'uploads/dal.png?X-Amz-Signature=abc';
      final parsed = ApiMyFoodMapper.presetFromResponse({
        'data': {
          'id': 'food-1',
          'name': 'Dal Tadka',
          'image': signed,
          'food': {
            'name': 'Dal Tadka',
            'calories': 140,
            'protein': 8,
            'carbs': 18,
            'fat': 4,
          },
        },
      });

      expect(parsed, isNotNull);
      expect(parsed!.food.imageUrl, signed);
    });

    test('uses catalog icon URL as the food photo', () {
      final parsed = ApiMyFoodMapper.presetFromResponse({
        'data': {
          'id': 'food-1',
          'name': 'Aam Panna',
          'icon': '/uploads/aam-panna.png',
        },
      });

      expect(parsed, isNotNull);
      expect(
        parsed!.food.imageUrl,
        'https://fitbuddyai.srhsoftwares.com/uploads/aam-panna.png',
      );
    });
  });
}
