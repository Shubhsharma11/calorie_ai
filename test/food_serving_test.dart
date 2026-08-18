import 'package:calorie_ai/core/food_serving.dart';
import 'package:calorie_ai/models/api_favourite_meal_mapper.dart';
import 'package:calorie_ai/models/api_my_food_mapper.dart';
import 'package:calorie_ai/models/food_item.dart';
import 'package:flutter_test/flutter_test.dart';

double _stepperStart(FoodItem food) =>
    food.usesHouseholdServing ? 1 : food.servingQuantity;

void _expectPlusDoesNotJumpTo51(String name, FoodItem food) {
  final start = _stepperStart(food);
  final next = FoodServing.steppedQuantity(
    unit: food.servingUnit,
    quantity: start,
    direction: 1,
  );
  expect(
    next - start,
    lessThan(20),
    reason: '$name jumped from $start ${food.servingUnit} to $next',
  );
  expect(next, isNot(51), reason: '$name became 51 after one plus tap');
}

void main() {
  test('parses Indian household serving from description', () {
    final parsed = FoodServing.parseDescription('1 bowl (220 g)');

    expect(parsed, isNotNull);
    expect(parsed!.quantity, 1);
    expect(parsed.unit, 'bowl');
    expect(parsed.gramsPerServing, 220);
    expect(parsed.defaultGrams, 220);
    expect(parsed.isHousehold, isTrue);
  });

  test('formats bowl labels for users', () {
    expect(FoodServing.format(quantity: 1, unit: 'bowl'), '1 bowl');
    expect(FoodServing.format(quantity: 2, unit: 'bowl'), '2 bowls');
    expect(
      FoodServing.formatVisible(quantity: 1, unit: 'bowl', grams: 220),
      '1 Bowl (220 g)',
    );
    expect(
      FoodServing.formatVisible(quantity: 1, unit: 'glass', grams: 250),
      '1 Glass (250 g)',
    );
  });

  test('parses catalog food with serving string and per-bowl calories', () {
    final food = FoodItem.tryFromApiJson({
      'name': 'Bharwa Bhindi',
      'category': 'Indian Main Course',
      'serving': '1 bowl (220 g)',
      'calories': 180,
      'protein': 6.6,
      'carbs': 18,
      'fat': 9,
    });

    expect(food, isNotNull);
    expect(food!.servingUnit, 'bowl');
    expect(food.servingQuantity, 1);
    expect(food.gramsPerServing, 220);
    expect(food.defaultGrams, 220);
    expect(food.usesHouseholdServing, isTrue);
    expect(food.servingDescription, '1 Bowl (220 g)');
    expect(food.searchSubtitle, 'Indian Main Course · 1 Bowl (220 g)');
    expect(food.caloriesPer100g, 82);
    expect(food.caloriesForDefaultServing, 180);
    expect(food.servingLabelForGrams(330), '1.5 Bowls (330 g)');
  });

  test('keeps explicit per-100g calories', () {
    final food = FoodItem.tryFromApiJson({
      'name': 'Bharwa Karela',
      'servingSize': '1 bowl (220 g)',
      'caloriesPer100g': 90,
      'calories': 198,
    });

    expect(food, isNotNull);
    expect(food!.caloriesPer100g, 90);
    expect(food.defaultGrams, 220);
    expect(food.caloriesForDefaultServing, 198);
  });

  test('quantity stepper does not jump from 1 serving to 51', () {
    expect(
      FoodServing.steppedQuantity(unit: 'serving', quantity: 1, direction: 1),
      1.5,
    );
    expect(
      FoodServing.steppedQuantity(unit: 'piece', quantity: 1, direction: 1),
      1.5,
    );
    expect(
      FoodServing.steppedQuantity(unit: 'burger', quantity: 1, direction: 1),
      1.5,
    );
    expect(
      FoodServing.steppedQuantity(unit: 'g', quantity: 1, direction: 1),
      2,
    );
    expect(
      FoodServing.steppedQuantity(unit: 'g', quantity: 100, direction: 1),
      110,
    );
    expect(
      FoodServing.steppedQuantity(unit: 'g', quantity: 100, direction: -1),
      90,
    );
  });

  test('plus tap does not jump to 51 for catalog, my food, or favourites', () {
    final catalog = <String, Map<String, dynamic>>{
      'Burger': {'name': 'Burger', 'serving': '1 piece', 'calories': 295},
      'Idli': {'name': 'Idli', 'serving': '1 piece (40 g)', 'calories': 58},
      'Dosa': {'name': 'Dosa', 'quantity': 1, 'unit': 'dosa', 'calories': 120},
      'Roti': {'name': 'Roti', 'servingSize': '1 roti', 'calories': 70},
      'Rice bowl': {
        'name': 'Rice',
        'serving': '1 bowl (220 g)',
        'calories': 280,
      },
      'Apple': {'name': 'Apple', 'caloriesPer100g': 52},
      'Oats 100g': {
        'name': 'Oats',
        'quantity': 100,
        'unit': 'g',
        'caloriesPer100g': 389,
      },
      'Mis-tagged 1 g': {
        'name': 'Sandwich',
        'quantity': 1,
        'unit': 'g',
        'calories': 250,
      },
    };

    for (final entry in catalog.entries) {
      final food = FoodItem.tryFromApiJson(entry.value);
      expect(food, isNotNull, reason: entry.key);
      _expectPlusDoesNotJumpTo51(entry.key, food!);
    }

    final myFood = ApiMyFoodMapper.presetFromApiJson({
      'id': 'my-1',
      'name': 'Homemade burger',
      'quantity': 1,
      'unit': 'serving',
      'calories': 310,
      'protein': 18,
      'carbs': 28,
      'fat': 12,
    });
    expect(myFood, isNotNull);
    _expectPlusDoesNotJumpTo51('My Food burger', myFood!.food);

    final favourite = ApiFavouriteMealMapper.itemFromApiJson({
      'id': 'fav-1',
      'name': 'Veg sandwich',
      'quantity': 1,
      'unit': 'piece',
      'calories': 220,
      'protein': 8,
      'carbs': 30,
      'fat': 7,
      'mealtime': 'lunch',
    });
    expect(favourite, isNotNull);
    _expectPlusDoesNotJumpTo51(
      'Favourite sandwich',
      favourite!.foodWithServing,
    );
  });

  test('defaults to 100g when serving is missing', () {
    final food = FoodItem.tryFromApiJson({
      'name': 'Apple',
      'caloriesPer100g': 52,
    });

    expect(food, isNotNull);
    expect(food!.servingUnit, 'g');
    expect(food.defaultGrams, 100);
    expect(food.usesHouseholdServing, isFalse);
    expect(food.servingDescription, '100 g');
  });

  test('parses structured bowl unit and grams', () {
    final serving = FoodServing.parseFromApi({
      'quantity': 1,
      'unit': 'bowl',
      'grams': 220,
    });

    expect(serving.unit, 'bowl');
    expect(serving.gramsPerServing, 220);
    expect(serving.defaultGrams, 220);
  });

  test('uses servingWeight for plate portions', () {
    final serving = FoodServing.parseFromApi({
      'servingSize': '1 plate',
      'servingWeight': 420,
    });

    expect(serving.unit, 'plate');
    expect(serving.quantity, 1);
    expect(serving.gramsPerServing, 420);
    expect(serving.defaultGrams, 420);
  });

  test('parses public meal search result with ingredients', () {
    final food = FoodItem.tryFromApiJson({
      'type': 'public_meal',
      'id': '6a82c783a86e55d0a2b50ad2',
      'name': '12',
      'category': 'Main Course',
      'servingSize': '1 plate',
      'servingWeight': 420,
      'calories': 538,
      'protein': 16,
      'fat': 13,
      'carbs': 87,
      'mealTime': 'breakfast',
      'items': [
        {
          'name': 'Chana Dal',
          'quantity': 100,
          'unit': 'g',
          'calories': 164,
          'protein': 9,
          'fat': 1,
          'carbs': 27,
        },
        {
          'name': 'Achari Aloo',
          'quantity': 220,
          'unit': 'g',
          'calories': 330,
          'protein': 6,
          'fat': 12,
          'carbs': 50,
        },
      ],
    });

    expect(food, isNotNull);
    expect(food!.isCompositeMeal, isTrue);
    expect(food.ingredients.length, 2);
    expect(food.ingredients.first.food.name, 'Chana Dal');
    expect(food.ingredients.last.food.name, 'Achari Aloo');
    expect(food.defaultGrams, 420);
    expect(food.totalCaloriesForPortions(1), 494);
    expect(food.ingredientsForPortions(2).first.grams, 200);
  });

  test('uses the catalog photo from the server', () {
    final food = FoodItem.tryFromApiJson({
      'name': 'Aam Panna',
      'calories': 110,
      'protein': 1,
      'carbs': 26,
      'fat': 0,
      'icon': '/uploads/aam-panna.png',
    });

    expect(food, isNotNull);
    expect(
      food!.imageUrl,
      'https://fitbuddyai.srhsoftwares.com/uploads/aam-panna.png',
    );
  });

  test('withServingFrom restores catalog glass serving and photo', () {
    const logged = FoodItem(
      name: 'Aam Panna',
      caloriesPer100g: 44,
      protein: 0.4,
      carbs: 10.4,
      fat: 0,
    );
    final catalog = FoodItem.tryFromApiJson({
      'name': 'Aam Panna',
      'category': 'Indian Beverage',
      'serving': '1 glass (250 g)',
      'calories': 110,
      'protein': 1,
      'carbs': 26,
      'fat': 0,
      'icon': '/uploads/aam-panna.png',
    })!;

    final hydrated = logged.withServingFrom(catalog);
    expect(hydrated.servingUnit, 'glass');
    expect(hydrated.gramsPerServing, 250);
    expect(hydrated.servingDescription, '1 Glass (250 g)');
    expect(hydrated.hasDisplayServing, isTrue);
    expect(
      hydrated.imageUrl,
      'https://fitbuddyai.srhsoftwares.com/uploads/aam-panna.png',
    );
    expect(hydrated.servingLabelForGrams(250), '1 Glass (250 g)');
    expect(hydrated.caloriesForGrams(250), 110);
  });

  test('withServingFrom restores a glass when the log is 250 g', () {
    const logged = FoodItem(
      name: 'Aam Panna',
      caloriesPer100g: 44,
      protein: 0.4,
      carbs: 10.4,
      fat: 0,
    );
    final catalog = FoodItem.tryFromApiJson({
      'name': 'Aam Panna',
      'serving': '1 glass (250 g)',
      'calories': 110,
      'protein': 1,
      'carbs': 26,
      'fat': 0,
    })!;

    final hydrated = logged.withServingFrom(catalog, loggedGrams: 250);
    expect(hydrated.servingUnit, 'glass');
    expect(hydrated.gramsPerServing, 250);
    expect(hydrated.caloriesForGrams(250), 110);
  });

  test('withServingFrom does not overlay a glass onto a 100 g log', () {
    const logged = FoodItem(
      name: 'Aam Panna',
      caloriesPer100g: 110,
      protein: 1,
      carbs: 26,
      fat: 0,
    );
    final catalog = FoodItem.tryFromApiJson({
      'name': 'Aam Panna',
      'category': 'Indian Beverage',
      'serving': '1 glass (250 g)',
      'calories': 110,
      'protein': 1,
      'carbs': 26,
      'fat': 0,
      'icon': '/uploads/aam-panna.png',
    })!;

    final hydrated = logged.withServingFrom(catalog, loggedGrams: 100);
    expect(hydrated.servingUnit, 'g');
    expect(hydrated.caloriesForGrams(100), 110);
    expect(hydrated.imageUrl, catalog.imageUrl);
  });
}
