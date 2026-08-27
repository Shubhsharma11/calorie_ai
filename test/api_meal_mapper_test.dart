import 'package:calorie_ai/models/api_meal_mapper.dart';
import 'package:calorie_ai/models/food_item.dart';
import 'package:calorie_ai/models/meal_entry.dart';
import 'package:calorie_ai/models/meal_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiMealMapper.entriesFromResponse maps wrapped meals payload', () {
    final entries = ApiMealMapper.entriesFromResponse({
      'success': true,
      'data': {
        'date': '2026-06-23',
        'meals': [
          {
            'id': '1719123456789',
            'meal': 'Breakfast',
            'grams': 150,
            'food': {
              'name': 'Oats',
              'caloriesPer100g': 389,
              'protein': 16.9,
              'carbs': 66.3,
              'fat': 6.9,
              'emoji': '🥣',
            },
          },
        ],
      },
    });

    expect(entries.length, 1);
    expect(entries.first.id, '1719123456789');
    expect(entries.first.meal, MealType.breakfast);
    expect(entries.first.grams, 150);
    expect(entries.first.food.name, 'Oats');
    expect(entries.first.food.caloriesPer100g, 389);
    expect(entries.first.date, DateTime(2026, 6, 23));
    expect(entries.first.calories, 584);
  });

  test('ApiMealMapper normalizes snack meal types', () {
    final entry = ApiMealMapper.entryFromApiJson({
      'id': '2',
      'meal': 'snacks',
      'grams': 50,
      'food': {
        'name': 'Almonds',
        'caloriesPer100g': 579,
        'protein': 21,
        'carbs': 22,
        'fat': 50,
      },
    });

    expect(entry, isNotNull);
    expect(entry!.meal, MealType.snacks);
  });

  test('ApiMealMapper maps flat GET /api/v1/meals payload', () {
    final entry = ApiMealMapper.entryFromApiJson({
      'id': 'meal-42',
      'name': 'Oats',
      'calories': 584,
      'protein': 25,
      'carbs': 99,
      'fat': 10,
      'mealTime': 'breakfast',
      'quantity': 150,
      'date': '2026-06-23',
    });

    expect(entry, isNotNull);
    expect(entry!.id, 'meal-42');
    expect(entry.meal, MealType.breakfast);
    expect(entry.grams, 150);
    expect(entry.food.name, 'Oats');
    expect(entry.food.caloriesPer100g, 389);
    expect(entry.calories, 584);
    expect(entry.date, DateTime(2026, 6, 23));
  });

  test('ApiMealMapper.entriesFromResponse maps flat meals list', () {
    final entries = ApiMealMapper.entriesFromResponse({
      'success': true,
      'data': {
        'meals': [
          {
            'id': '1',
            'name': 'Boiled Egg',
            'calories': 155,
            'protein': 13,
            'carbs': 1,
            'fat': 11,
            'mealTime': 'breakfast',
            'quantity': 100,
          },
        ],
      },
    });

    expect(entries.length, 1);
    expect(entries.first.food.name, 'Boiled Egg');
    expect(entries.first.meal, MealType.breakfast);
  });

  test('ApiMealMapper.entriesFromResponse maps data array payload', () {
    final entries = ApiMealMapper.entriesFromResponse({
      'success': true,
      'data': [
        {
          'id': '1',
          'name': 'Oats',
          'calories': 584,
          'protein': 25,
          'carbs': 99,
          'fat': 10,
          'mealTime': 'breakfast',
          'quantity': 150,
        },
        {
          'id': '2',
          'name': 'Dal',
          'calories': 210,
          'protein': 15,
          'carbs': 28,
          'fat': 5,
          'meal_time': 'lunch',
          'quantity': 200,
        },
      ],
    });

    expect(entries.length, 2);
    expect(entries.first.food.name, 'Oats');
    expect(entries.last.meal, MealType.lunch);
  });

  test('ApiMealMapper skips invalid meal items', () {
    final entries = ApiMealMapper.entriesFromResponse({
      'data': {
        'meals': [
          {'id': '1', 'meal': 'Breakfast', 'grams': 0, 'food': {'name': 'X'}},
          {'id': '2', 'meal': 'Unknown', 'grams': 100, 'food': {'name': 'Y'}},
        ],
      },
    });

    expect(entries, isEmpty);
  });

  test('ApiMealMapper.toCreateRequestBody maps entry to POST payload', () {
    final entry = MealEntry(
      food: const FoodItem(
        name: 'Oats',
        caloriesPer100g: 389,
        protein: 16.9,
        carbs: 66.3,
        fat: 6.9,
        emoji: '🥣',
      ),
      grams: 150,
      meal: MealType.breakfast,
      date: DateTime(2026, 6, 23),
    );

    expect(
      ApiMealMapper.toCreateRequestBody(entry),
      {
        'name': 'Oats',
        'calories': 584,
        'protein': 25,
        'carbs': 99,
        'fat': 10,
        'mealTime': 'breakfast',
        'quantity': 150,
        'unit': 'g',
        'grams': 150,
        'emoji': '🥣',
        'date': '2026-06-23',
      },
    );
  });

  test('ApiMealMapper.toCreateRequestBody sends snack not snacks', () {
    final entry = MealEntry(
      food: const FoodItem(
        name: 'Almonds',
        caloriesPer100g: 579,
        protein: 21,
        carbs: 22,
        fat: 50,
      ),
      grams: 50,
      meal: MealType.snacks,
      date: DateTime(2026, 6, 23),
    );

    expect(ApiMealMapper.toCreateRequestBody(entry)['mealTime'], 'snack');
  });

  test('ApiMealMapper.mergeCreateResponse keeps local food when id only', () {
    final source = MealEntry(
      id: 'local-1',
      food: const FoodItem(
        name: 'Oats',
        caloriesPer100g: 389,
        protein: 16.9,
        carbs: 66.3,
        fat: 6.9,
      ),
      grams: 150,
      meal: MealType.breakfast,
    );

    final merged = ApiMealMapper.mergeCreateResponse(
      {
        'success': true,
        'data': {'id': 'server-99'},
      },
      source: source,
    );

    expect(merged.id, 'server-99');
    expect(merged.food.name, 'Oats');
    expect(merged.grams, 150);
  });

  test('ApiMealMapper reads _id from GET payload', () {
    final entry = ApiMealMapper.entryFromApiJson({
      '_id': 'mongo-meal-1',
      'name': 'Oats',
      'calories': 389,
      'protein': 13,
      'carbs': 66,
      'fat': 7,
      'mealTime': 'breakfast',
      'quantity': 100,
    });

    expect(entry, isNotNull);
    expect(entry!.id, 'mongo-meal-1');
  });

  test('ApiMealMapper keeps bowl serving on logged meals', () {
    final entry = ApiMealMapper.entryFromApiJson({
      'id': 'meal-bowl',
      'name': 'Bharwa Bhindi',
      'category': 'Indian Main Course',
      'calories': 180,
      'protein': 6.6,
      'carbs': 18,
      'fat': 9,
      'mealTime': 'lunch',
      'quantity': 220,
      'unit': 'bowl',
      'gramsPerServing': 220,
    });

    expect(entry, isNotNull);
    expect(entry!.grams, 220);
    expect(entry.food.servingUnit, 'bowl');
    expect(entry.food.usesHouseholdServing, isTrue);
    expect(entry.quantityLabel, '1 Bowl (220 g)');
  });

  test('ApiMealMapper.toCreateRequestBody sends household unit', () {
    final entry = MealEntry(
      food: const FoodItem(
        name: 'Bharwa Bhindi',
        caloriesPer100g: 82,
        protein: 3,
        carbs: 8,
        fat: 4,
        servingQuantity: 1,
        servingUnit: 'bowl',
        gramsPerServing: 220,
      ),
      grams: 220,
      meal: MealType.lunch,
      date: DateTime(2026, 6, 23),
    );

    final body = ApiMealMapper.toCreateRequestBody(entry);
    expect(body['quantity'], 220);
    expect(body['unit'], 'bowl');
    expect(body['grams'], 220);
    expect(body['gramsPerServing'], 220);
  });

  test('ApiMealMapper.toCreateRequestBody sends food image', () {
    final entry = MealEntry(
      food: const FoodItem(
        name: 'Oats',
        caloriesPer100g: 389,
        protein: 16.9,
        carbs: 66.3,
        fat: 6.9,
        emoji: '🥣',
        imageUrl: 'https://example.com/oats.png',
      ),
      grams: 150,
      meal: MealType.breakfast,
      date: DateTime(2026, 6, 23),
    );

    final body = ApiMealMapper.toCreateRequestBody(entry);
    expect(body['image'], 'https://example.com/oats.png');
    expect(body['imageUrl'], 'https://example.com/oats.png');
    expect(body['emoji'], '🥣');
  });

  test('ApiMealMapper reads nested and relative meal images', () {
    final nested = ApiMealMapper.entryFromApiJson({
      'id': 'meal-img-1',
      'mealTime': 'lunch',
      'quantity': 240,
      'name': 'Ajwain Paratha',
      'calories': 590,
      'protein': 12,
      'carbs': 70,
      'fat': 20,
      'food': {
        'name': 'Ajwain Paratha',
        'caloriesPer100g': 246,
        'protein': 5,
        'carbs': 29,
        'fat': 8,
      },
      'image': {'url': 'https://cdn.example.com/paratha.png'},
    });

    expect(nested, isNotNull);
    expect(nested!.food.imageUrl, 'https://cdn.example.com/paratha.png');

    final relative = ApiMealMapper.entryFromApiJson({
      'id': 'meal-img-2',
      'mealTime': 'breakfast',
      'quantity': 100,
      'name': 'Aam Panna',
      'calories': 110,
      'protein': 1,
      'carbs': 26,
      'fat': 0,
      'image': '/uploads/aam-panna.png',
    });

    expect(relative, isNotNull);
    expect(
      relative!.food.imageUrl,
      'https://fitbuddyai.srhsoftwares.com/uploads/aam-panna.png',
    );
  });

  test('ApiMealMapper.mergeCreateResponse keeps source image', () {
    final source = MealEntry(
      id: 'local-1',
      food: const FoodItem(
        name: 'Oats',
        caloriesPer100g: 389,
        protein: 16.9,
        carbs: 66.3,
        fat: 6.9,
        emoji: '🥣',
        imageUrl: 'https://example.com/oats.png',
      ),
      grams: 150,
      meal: MealType.breakfast,
    );

    final merged = ApiMealMapper.mergeCreateResponse(
      {
        'success': true,
        'data': {
          'id': 'server-99',
          'name': 'Oats',
          'calories': 584,
          'protein': 25,
          'carbs': 99,
          'fat': 10,
          'mealTime': 'breakfast',
          'quantity': 150,
        },
      },
      source: source,
    );

    expect(merged.id, 'server-99');
    expect(merged.food.imageUrl, 'https://example.com/oats.png');
    expect(merged.food.emoji, '🥣');
  });

  test('ApiMealMapper.mergeCreateResponse keeps bowl serving', () {
    final source = MealEntry(
      id: 'local-1',
      food: const FoodItem(
        name: 'Bharwa Bhindi',
        caloriesPer100g: 82,
        protein: 3,
        carbs: 8,
        fat: 4,
        servingQuantity: 1,
        servingUnit: 'bowl',
        gramsPerServing: 220,
      ),
      grams: 220,
      meal: MealType.lunch,
    );

    final merged = ApiMealMapper.mergeCreateResponse(
      {
        'success': true,
        'data': {
          'id': 'server-99',
          'name': 'Bharwa Bhindi',
          'calories': 180,
          'protein': 6.6,
          'carbs': 18,
          'fat': 9,
          'mealTime': 'lunch',
          'quantity': 220,
        },
      },
      source: source,
    );

    expect(merged.id, 'server-99');
    expect(merged.food.servingUnit, 'bowl');
    expect(merged.quantityLabel, '1 Bowl (220 g)');
  });

  test('ApiMealMapper reads household quantity as serving count', () {
    final entry = ApiMealMapper.entryFromApiJson({
      'id': 'meal-bowl-count',
      'name': 'Dal',
      'calories': 210,
      'protein': 12,
      'carbs': 28,
      'fat': 5,
      'mealTime': 'lunch',
      'quantity': 1,
      'unit': 'bowl',
    });

    expect(entry, isNotNull);
    expect(entry!.grams, 220);
    expect(entry.food.servingUnit, 'bowl');
    expect(entry.quantityLabel, '1 Bowl (220 g)');
  });

  test('ApiMealMapper keeps milliliter quantity', () {
    final entry = ApiMealMapper.entryFromApiJson({
      'id': 'meal-ml',
      'name': 'Buttermilk',
      'calories': 80,
      'protein': 4,
      'carbs': 10,
      'fat': 2,
      'mealTime': 'breakfast',
      'quantity': 250,
      'unit': 'ml',
    });

    expect(entry, isNotNull);
    expect(entry!.grams, 250);
    expect(entry.food.servingUnit, 'ml');
    expect(entry.quantityLabel, '250 ml');
  });
}
