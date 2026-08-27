import 'package:calorie_ai/models/api_custom_meal_mapper.dart';
import 'package:calorie_ai/models/custom_meal_preset.dart';
import 'package:calorie_ai/models/food_item.dart';
import 'package:calorie_ai/models/meal_type.dart';
import 'package:calorie_ai/models/saved_meal_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiCustomMealMapper builds POST /api/v1/my-meals body', () {
    const chicken = FoodItem(
      name: 'chicken breast',
      caloriesPer100g: 165,
      protein: 31,
      carbs: 0,
      fat: 3.6,
    );
    const rice = FoodItem(
      name: 'rice',
      caloriesPer100g: 130,
      protein: 2.7,
      carbs: 28,
      fat: 0.3,
    );

    final preset = CustomMealPreset(
      id: 'local-1',
      name: 'Protein Bowl',
      createdAt: DateTime(2026, 7, 17),
      meal: MealType.lunch,
      visibility: MealShareVisibility.onlyMe,
      items: [
        SavedMealItem(food: chicken, grams: 150, meal: MealType.lunch),
        SavedMealItem(food: rice, grams: 100, meal: MealType.lunch),
      ],
    );

    final body = ApiCustomMealMapper.toCreateRequestBody(preset);

    expect(body['name'], 'Protein Bowl');
    expect(body['mealTime'], 'lunch');
    expect(body['visibility'], 'private');
    expect(body['calories'], preset.totalCalories);
    expect(body['protein'], isA<num>());
    expect(body['carbs'], isA<num>());
    expect(body['fat'], isA<num>());
    expect(body['items'], hasLength(2));
    expect(body['items'][0]['name'], 'chicken breast');
    expect(body['items'][0]['quantity'], 150);
    expect(body['items'][0]['unit'], 'g');
    expect(body['items'][0]['calories'], preset.items[0].calories);
    expect(body['items'][0]['protein'], isA<num>());
    expect(body['items'][1]['name'], 'rice');
    expect(body['items'][1]['calories'], preset.items[1].calories);
  });

  test('ApiCustomMealMapper builds PATCH /api/v1/my-meals/:id body', () {
    const chicken = FoodItem(
      name: 'chicken breast',
      caloriesPer100g: 165,
      protein: 31,
      carbs: 0,
      fat: 3.6,
    );
    const rice = FoodItem(
      name: 'rice',
      caloriesPer100g: 130,
      protein: 2.7,
      carbs: 28,
      fat: 0.3,
    );

    final preset = CustomMealPreset(
      id: 'meal-1',
      name: 'Updated Bowl',
      createdAt: DateTime(2026, 7, 17),
      meal: MealType.lunch,
      visibility: MealShareVisibility.onlyMe,
      items: [
        SavedMealItem(food: chicken, grams: 150, meal: MealType.lunch),
        SavedMealItem(food: rice, grams: 100, meal: MealType.lunch),
      ],
    );

    final body = ApiCustomMealMapper.toPatchRequestBody(
      preset: preset,
      imageUrl: 'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg',
    );

    expect(body['name'], 'Updated Bowl');
    expect(body['mealTime'], 'lunch');
    expect(body['visibility'], 'private');
    expect(body['image'], 'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg');
    expect(body['calories'], preset.totalCalories);
    expect(body['protein'], isA<num>());
    expect(body['carbs'], isA<num>());
    expect(body['fat'], isA<num>());
    expect(body['items'], hasLength(2));
    expect(body['items'][0]['name'], 'chicken breast');
    expect(body['items'][0]['calories'], preset.items[0].calories);
    expect(body['items'][1]['name'], 'rice');
    expect(body['items'][1]['calories'], preset.items[1].calories);
  });

  test('ApiCustomMealMapper hydrates 0-kcal items from meal totals', () {
    final presets = ApiCustomMealMapper.presetsFromResponse({
      'data': [
        {
          'id': 'custom-1',
          'name': 'Oat Meal',
          'mealTime': 'breakfast',
          'calories': 389,
          'protein': 13,
          'carbs': 66,
          'fat': 7,
          'items': [
            {'name': 'oats', 'quantity': 100, 'unit': 'g'},
          ],
        },
      ],
    });

    expect(presets, hasLength(1));
    expect(presets.first.totalCalories, 389);
    expect(presets.first.items.single.calories, 389);
  });

  test('ApiCustomMealMapper hydrates from totalNutrients when items omit macros',
      () {
    final presets = ApiCustomMealMapper.presetsFromResponse({
      'data': [
        {
          'id': 'custom-2',
          'name': 'Bowl',
          'mealTime': 'lunch',
          'totalNutrients': {
            'calories': 400,
            'protein': 30,
            'carbs': 40,
            'fat': 10,
          },
          'items': [
            {'name': 'chicken', 'quantity': 100, 'unit': 'g'},
            {'name': 'rice', 'quantity': 100, 'unit': 'g'},
          ],
        },
      ],
    });

    expect(presets, hasLength(1));
    expect(presets.first.totalCalories, 400);
    expect(presets.first.items[0].calories, greaterThan(0));
    expect(presets.first.items[1].calories, greaterThan(0));
  });

  test('ApiCustomMealMapper omits empty image from PATCH body', () {
    final preset = CustomMealPreset(
      id: 'meal-1',
      name: 'Updated Bowl',
      createdAt: DateTime(2026, 7, 17),
      meal: MealType.lunch,
      visibility: MealShareVisibility.onlyMe,
      items: const [
        SavedMealItem(
          food: FoodItem(
            name: 'rice',
            caloriesPer100g: 130,
            protein: 2.7,
            carbs: 28,
            fat: 0.3,
          ),
          grams: 100,
          meal: MealType.lunch,
        ),
      ],
    );

    final body = ApiCustomMealMapper.toPatchRequestBody(preset: preset);
    expect(body.containsKey('image'), isFalse);
  });

  test('ApiCustomMealMapper maps snacks mealTime to snack', () {
    final preset = CustomMealPreset(
      id: 'local-2',
      name: 'Snack Pack',
      createdAt: DateTime(2026, 7, 17),
      meal: MealType.snacks,
      items: const [
        SavedMealItem(
          food: FoodItem(
            name: 'almonds',
            caloriesPer100g: 579,
            protein: 21,
            carbs: 22,
            fat: 50,
          ),
          grams: 30,
          meal: MealType.snacks,
        ),
      ],
    );

    final body = ApiCustomMealMapper.toCreateRequestBody(preset);
    expect(body['mealTime'], 'snack');
    expect(body['visibility'], 'private');
  });

  test('ApiCustomMealMapper maps wrapped create response', () {
    final source = CustomMealPreset(
      id: 'local-1',
      name: 'Oat Meal',
      createdAt: DateTime(2026, 7, 10),
      meal: MealType.breakfast,
      visibility: MealShareVisibility.public,
      items: const [
        SavedMealItem(
          food: FoodItem(
            name: 'oats',
            caloriesPer100g: 389,
            protein: 13,
            carbs: 66,
            fat: 7,
          ),
          grams: 100,
          meal: MealType.breakfast,
        ),
      ],
    );

    final preset = ApiCustomMealMapper.presetFromResponse(
      {
        'success': true,
        'data': {
          'id': 'srv-99',
          'name': 'Oat Meal',
          'mealTime': 'breakfast',
          'visibility': 'public',
          'totalNutrients': {
            'calories': 473,
            'protein': 14,
            'fat': 7,
            'carbs': 88,
          },
          'items': [
            {
              'name': 'oats',
              'quantity': 100,
              'unit': 'g',
              'calories': 389,
              'protein': 13,
              'fat': 7,
              'carbs': 66,
            },
          ],
        },
      },
      source: source,
    );

    expect(preset.id, 'srv-99');
    expect(preset.name, 'Oat Meal');
    expect(preset.meal, MealType.breakfast);
    expect(preset.visibility, MealShareVisibility.public);
    expect(preset.items.length, 1);
    expect(preset.items.first.food.name, 'oats');
    expect(preset.items.first.grams, 100);
  });

  test('ApiCustomMealMapper maps wrapped list response', () {
    final presets = ApiCustomMealMapper.presetsFromResponse({
      'success': true,
      'data': [
        {
          'id': 'custom-1',
          'name': 'Oat Meal',
          'mealTime': 'breakfast',
          'visibility': 'public',
          'createdAt': '2026-07-10T10:00:00.000Z',
          'items': [
            {
              'name': 'oats',
              'quantity': 100,
              'unit': 'g',
              'calories': 389,
              'protein': 13,
              'fat': 7,
              'carbs': 66,
            },
          ],
        },
        {
          'id': 'custom-2',
          'name': 'Misal Pav',
          'mealTime': 'snack',
          'visibility': 'private',
          'items': [
            {
              'name': 'misal',
              'quantity': 250,
              'unit': 'g',
              'calories': 300,
              'protein': 10,
              'fat': 12,
              'carbs': 30,
            },
          ],
        },
      ],
    });

    expect(presets.length, 2);
    expect(presets.first.id, 'custom-1');
    expect(presets.first.meal, MealType.breakfast);
    expect(presets.first.visibility, MealShareVisibility.public);
    expect(presets.last.id, 'custom-2');
    expect(presets.last.meal, MealType.snacks);
    expect(presets.last.visibility, MealShareVisibility.onlyMe);
  });

  test('ApiCustomMealMapper maps data.myMeals list response', () {
    final presets = ApiCustomMealMapper.presetsFromResponse({
      'success': true,
      'data': {
        'myMeals': [
          {
            'id': 'custom-1',
            'name': 'Oat Meal',
            'mealTime': 'breakfast',
            'visibility': 'public',
            'items': [
              {
                'name': 'oats',
                'quantity': '100',
                'unit': 'g',
                'calories': 389,
                'protein': 13,
                'fat': 7,
                'carbs': 66,
              },
            ],
          },
        ],
      },
    });

    expect(presets.length, 1);
    expect(presets.first.id, 'custom-1');
    expect(presets.first.name, 'Oat Meal');
    expect(presets.first.items.single.grams, 100);
  });

  test('ApiCustomMealMapper reads myMealId from response', () {
    final source = CustomMealPreset(
      id: 'local-1',
      name: 'Protein Bowl',
      createdAt: DateTime(2026, 7, 17),
      meal: MealType.lunch,
      items: const [
        SavedMealItem(
          food: FoodItem(
            name: 'rice',
            caloriesPer100g: 130,
            protein: 2.7,
            carbs: 28,
            fat: 0.3,
          ),
          grams: 100,
          meal: MealType.lunch,
        ),
      ],
    );

    final preset = ApiCustomMealMapper.presetFromResponse(
      {
        'data': {
          'myMealId': 'srv-meal-42',
          'name': 'Protein Bowl',
          'mealTime': 'lunch',
          'visibility': 'private',
          'items': [
            {'name': 'rice', 'quantity': 100, 'unit': 'g'},
          ],
        },
      },
      source: source,
    );

    expect(preset.id, 'srv-meal-42');
  });

  test('ApiCustomMealMapper sends uploads key on create, not signed URL', () {
    final preset = CustomMealPreset(
      id: 'local-1',
      name: 'Protein Bowl',
      createdAt: DateTime(2026, 7, 17),
      meal: MealType.lunch,
      imageUrl:
          'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
          'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg?X-Amz-Signature=abc',
      items: const [
        SavedMealItem(
          food: FoodItem(
            name: 'rice',
            caloriesPer100g: 130,
            protein: 2.7,
            carbs: 28,
            fat: 0.3,
          ),
          grams: 100,
          meal: MealType.lunch,
        ),
      ],
    );

    final body = ApiCustomMealMapper.toCreateRequestBody(preset);
    expect(body['image'], 'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg');
  });

  test('ApiCustomMealMapper resolves uploads key from list payload', () {
    final presets = ApiCustomMealMapper.presetsFromResponse({
      'data': [
        {
          'id': 'custom-1',
          'name': 'Oat Meal',
          'mealTime': 'breakfast',
          'image': 'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg',
          'items': [
            {'name': 'oats', 'quantity': 100, 'unit': 'g'},
          ],
        },
      ],
    });

    expect(presets, hasLength(1));
    expect(
      presets.first.imageUrl,
      'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
      'uploads/9f3c1e7a2b8d4f6019ac5e2d7b3f8c41.jpg',
    );
  });

  test('ApiCustomMealMapper keeps signed S3 image from GET my-meals', () {
    const signed =
        'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
        'uploads/f3c0b8fbb88db1c4e7645af0289ee6ed.png'
        '?X-Amz-Signature=abc';
    final presets = ApiCustomMealMapper.presetsFromResponse({
      'success': true,
      'data': {
        'myMeals': [
          {
            'id': '6a7ee5cea86e55d0a2b498b6',
            'name': 'Grrgr',
            'mealTime': 'breakfast',
            'image': signed,
            'items': [
              {'name': 'Acorn (Edible)', 'quantity': 100, 'unit': 'g'},
            ],
          },
        ],
      },
    });

    expect(presets, hasLength(1));
    expect(presets.first.imageUrl, signed);
  });

  test('ApiCustomMealMapper prefers signed URL over uploads key', () {
    const signed =
        'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
        'uploads/f3c0b8fbb88db1c4e7645af0289ee6ed.png'
        '?X-Amz-Signature=abc';
    final presets = ApiCustomMealMapper.presetsFromResponse({
      'data': [
        {
          'id': 'custom-1',
          'name': 'Oat Meal',
          'mealTime': 'breakfast',
          'image': 'uploads/f3c0b8fbb88db1c4e7645af0289ee6ed.png',
          'imageUrl': signed,
          'items': [
            {'name': 'oats', 'quantity': 100, 'unit': 'g'},
          ],
        },
      ],
    });

    expect(presets, hasLength(1));
    expect(presets.first.imageUrl, signed);
  });

  test('ApiCustomMealMapper reads image from data.myMeal create payload', () {
    const signed =
        'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
        'uploads/f3c0b8fbb88db1c4e7645af0289ee6ed.png'
        '?X-Amz-Signature=abc';
    final source = CustomMealPreset(
      id: 'local-1',
      name: 'Grrgr',
      createdAt: DateTime(2026, 8, 14),
      meal: MealType.breakfast,
      items: const [
        SavedMealItem(
          food: FoodItem(
            name: 'Acorn (Edible)',
            caloriesPer100g: 120,
            protein: 3.5,
            carbs: 24,
            fat: 1.5,
          ),
          grams: 100,
          meal: MealType.breakfast,
        ),
      ],
    );

    final preset = ApiCustomMealMapper.presetFromResponse(
      {
        'success': true,
        'data': {
          'myMeal': {
            'id': 'srv-meal-1',
            'name': 'Grrgr',
            'image': signed,
            'mealTime': 'breakfast',
            'items': [
              {'name': 'Acorn (Edible)', 'quantity': 100, 'unit': 'g'},
            ],
          },
        },
      },
      source: source,
    );

    expect(preset.id, 'srv-meal-1');
    expect(preset.imageUrl, signed);
  });

  test('ApiCustomMealMapper reads food photos on meal items', () {
    const signed =
        'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
        'uploads/akki-roti.png?X-Amz-Signature=abc';
    final presets = ApiCustomMealMapper.presetsFromResponse({
      'data': [
        {
          'id': 'gym-1',
          'name': 'Gym',
          'mealTime': 'breakfast',
          'items': [
            {
              'name': 'Akki Roti',
              'quantity': 2,
              'unit': 'Pieces',
              'calories': 211,
              'image': signed,
            },
            {
              'name': 'Chana Dal',
              'quantity': 100,
              'unit': 'g',
              'calories': 164,
              'icon': '/uploads/chana-dal.png',
            },
            {
              'name': 'Achari Aloo',
              'quantity': 1,
              'unit': 'Bowl',
              'calories': 297,
              'food': {
                'name': 'Achari Aloo',
                'imageUrl':
                    'https://fitbuddyai.srhsoftwares.com/uploads/aloo.png',
              },
            },
          ],
        },
      ],
    });

    expect(presets, hasLength(1));
    expect(presets.first.items, hasLength(3));
    expect(presets.first.items[0].food.imageUrl, signed);
    expect(
      presets.first.items[1].food.imageUrl,
      'https://fitbuddyai.srhsoftwares.com/uploads/chana-dal.png',
    );
    expect(
      presets.first.items[2].food.imageUrl,
      'https://fitbuddyai.srhsoftwares.com/uploads/aloo.png',
    );
  });

  test('ApiCustomMealMapper keeps source item photos when response omits them', () {
    const photo =
        'https://fitbuddyai.s3.ap-south-1.amazonaws.com/uploads/oats.png';
    final source = CustomMealPreset(
      id: 'local-1',
      name: 'Oat Meal',
      createdAt: DateTime(2026, 7, 10),
      meal: MealType.breakfast,
      items: const [
        SavedMealItem(
          food: FoodItem(
            name: 'oats',
            caloriesPer100g: 389,
            protein: 13,
            carbs: 66,
            fat: 7,
            imageUrl: photo,
          ),
          grams: 100,
          meal: MealType.breakfast,
        ),
      ],
    );

    final preset = ApiCustomMealMapper.presetFromResponse(
      {
        'data': {
          'id': 'srv-1',
          'name': 'Oat Meal',
          'mealTime': 'breakfast',
          'items': [
            {'name': 'oats', 'quantity': 100, 'unit': 'g'},
          ],
        },
      },
      source: source,
    );

    expect(preset.items.single.food.imageUrl, photo);
  });

  test('ApiCustomMealMapper sends item upload key on create', () {
    final preset = CustomMealPreset(
      id: 'local-1',
      name: 'Protein Bowl',
      createdAt: DateTime(2026, 7, 17),
      meal: MealType.lunch,
      items: const [
        SavedMealItem(
          food: FoodItem(
            name: 'rice',
            caloriesPer100g: 130,
            protein: 2.7,
            carbs: 28,
            fat: 0.3,
            imageUrl:
                'https://fitbuddyai.s3.ap-south-1.amazonaws.com/'
                'uploads/rice.png?X-Amz-Signature=abc',
          ),
          grams: 100,
          meal: MealType.lunch,
        ),
      ],
    );

    final body = ApiCustomMealMapper.toCreateRequestBody(preset);
    expect(body['items'][0]['name'], 'rice');
    expect(body['items'][0]['quantity'], 100);
    expect(body['items'][0]['unit'], 'g');
    expect(body['items'][0]['calories'], 130);
    expect(body['items'][0]['image'], 'uploads/rice.png');
  });

  test('ApiCustomMealMapper sends catalog item photo URL on create', () {
    final preset = CustomMealPreset(
      id: 'local-1',
      name: 'Gym',
      createdAt: DateTime(2026, 7, 17),
      meal: MealType.breakfast,
      items: const [
        SavedMealItem(
          food: FoodItem(
            name: 'Akki Roti',
            caloriesPer100g: 117,
            protein: 3,
            carbs: 22,
            fat: 2,
            imageUrl: 'https://fitbuddyai.srhsoftwares.com/uploads/akki-roti.png',
          ),
          grams: 180,
          meal: MealType.breakfast,
        ),
      ],
    );

    final body = ApiCustomMealMapper.toCreateRequestBody(preset);
    expect(
      body['items'][0]['image'],
      'https://fitbuddyai.srhsoftwares.com/uploads/akki-roti.png',
    );
  });
}
