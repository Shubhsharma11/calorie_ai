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

    expect(body, {
      'name': 'Protein Bowl',
      'mealTime': 'lunch',
      'visibility': 'private',
      'items': [
        {'name': 'chicken breast', 'quantity': 150, 'unit': 'g'},
        {'name': 'rice', 'quantity': 100, 'unit': 'g'},
      ],
    });
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
      imageUrl: 'https://example.com/bowl.jpg',
    );

    expect(body['name'], 'Updated Bowl');
    expect(body['mealTime'], 'lunch');
    expect(body['visibility'], 'private');
    expect(body['image'], 'https://example.com/bowl.jpg');
    expect(body['calories'], preset.totalCalories);
    expect(body['protein'], isA<num>());
    expect(body['carbs'], isA<num>());
    expect(body['fat'], isA<num>());
    expect(body.containsKey('items'), isFalse);
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
}
