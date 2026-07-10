import 'package:calorie_ai/models/api_custom_meal_mapper.dart';
import 'package:calorie_ai/models/custom_meal_preset.dart';
import 'package:calorie_ai/models/food_item.dart';
import 'package:calorie_ai/models/meal_type.dart';
import 'package:calorie_ai/models/saved_meal_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiCustomMealMapper builds POST body with item macros', () {
    const oats = FoodItem(
      name: 'oats',
      caloriesPer100g: 389,
      protein: 13,
      carbs: 66,
      fat: 7,
    );
    const honey = FoodItem(
      name: 'honey',
      caloriesPer100g: 300,
      protein: 0,
      carbs: 80,
      fat: 0,
    );
    const banana = FoodItem(
      name: 'banana',
      caloriesPer100g: 90,
      protein: 1,
      carbs: 23,
      fat: 0,
    );

    final preset = CustomMealPreset(
      id: 'local-1',
      name: 'Oat Meal',
      createdAt: DateTime(2026, 7, 10),
      meal: MealType.breakfast,
      visibility: MealShareVisibility.public,
      items: [
        SavedMealItem(food: oats, grams: 100, meal: MealType.breakfast),
        SavedMealItem(food: honey, grams: 10, meal: MealType.breakfast),
        SavedMealItem(food: banana, grams: 60, meal: MealType.breakfast),
      ],
    );

    final body = ApiCustomMealMapper.toCreateRequestBody(preset);

    expect(body['name'], 'Oat Meal');
    expect(body['mealTime'], 'breakfast');
    expect(body['visibility'], 'public');
    expect(body['items'], [
      {
        'name': 'oats',
        'quantity': 100,
        'unit': 'gm',
        'calories': 389,
        'protein': 13,
        'fat': 7,
        'carbs': 66,
      },
      {
        'name': 'honey',
        'quantity': 10,
        'unit': 'gm',
        'calories': 30,
        'protein': 0,
        'fat': 0,
        'carbs': 8,
      },
      {
        'name': 'banana',
        'quantity': 60,
        'unit': 'gm',
        'calories': 54,
        'protein': 1,
        'fat': 0,
        'carbs': 14,
      },
    ]);
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
              'unit': 'gm',
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
              'unit': 'gm',
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
          'mealTime': 'snacks',
          'visibility': 'private',
          'items': [
            {
              'name': 'misal',
              'quantity': 250,
              'unit': 'gm',
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
}
