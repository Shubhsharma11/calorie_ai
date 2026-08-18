import 'package:calorie_ai/controllers/food_controller.dart';
import 'package:calorie_ai/models/custom_food_preset.dart';
import 'package:calorie_ai/models/custom_meal_preset.dart';
import 'package:calorie_ai/models/food_item.dart';
import 'package:calorie_ai/models/meal_entry.dart';
import 'package:calorie_ai/models/meal_type.dart';
import 'package:calorie_ai/models/saved_meal_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(Get.reset);
  tearDown(Get.reset);
  const oats = FoodItem(
    name: 'Oats',
    caloriesPer100g: 389,
    protein: 16.9,
    carbs: 66.3,
    fat: 6.9,
    emoji: '🥣',
  );
  const rice = FoodItem(
    name: 'Rice',
    caloriesPer100g: 130,
    protein: 2.7,
    carbs: 28,
    fat: 0.3,
    emoji: '🍚',
  );
  const shake = FoodItem(
    name: 'Protein Shake',
    caloriesPer100g: 120,
    protein: 24,
    carbs: 3,
    fat: 1,
    emoji: '🥤',
  );

  test('recentQuickMeals reads from apiMeals not local entries', () {
    final food = FoodController();

    final today = MealEntry.normalizeDate(DateTime.now());
    food.entries.add(
      MealEntry(
        id: 'local-only',
        food: oats,
        grams: 150,
        meal: MealType.breakfast,
        date: today,
      ),
    );
    food.apiMeals.add(
      MealEntry(
        id: 'api-1',
        food: rice,
        grams: 200,
        meal: MealType.lunch,
        date: today,
      ),
    );

    final quick = food.recentQuickMeals;

    expect(quick, hasLength(1));
    expect(quick.first.food.name, 'Rice');
  });

  test('quickMealsFor uses apiMeals history for meal slot', () {
    final food = FoodController();

    final today = MealEntry.normalizeDate(DateTime.now());
    food.apiMeals.add(
      MealEntry(
        id: 'api-1',
        food: oats,
        grams: 150,
        meal: MealType.breakfast,
        date: today,
      ),
    );

    final quick = food.quickMealsFor(MealType.breakfast);

    expect(quick, hasLength(1));
    expect(quick.first.food.name, 'Oats');
  });

  test('recentQuickMeals hides a deleted my food', () async {
    final food = FoodController();
    final today = MealEntry.normalizeDate(DateTime.now());

    food.customFoodPresets.add(
      CustomFoodPreset(
        id: '1000000000001',
        food: shake,
        defaultGrams: 100,
        createdAt: DateTime.now(),
      ),
    );
    food.apiMeals.addAll([
      MealEntry(
        id: 'api-shake',
        food: shake,
        grams: 100,
        meal: MealType.breakfast,
        date: today,
      ),
      MealEntry(
        id: 'api-oats',
        food: oats,
        grams: 150,
        meal: MealType.breakfast,
        date: today,
      ),
    ]);

    expect(
      food.recentQuickMeals.map((item) => item.food.name),
      containsAll(['Protein Shake', 'Oats']),
    );

    await food.removeCustomFoodPreset('1000000000001');

    expect(
      food.recentQuickMeals.map((item) => item.food.name),
      ['Oats'],
    );
  });

  test('recentQuickMeals hides a deleted my meal and its foods', () async {
    final food = FoodController();
    final today = MealEntry.normalizeDate(DateTime.now());
    final preset = CustomMealPreset(
      id: '1000000000002',
      name: 'Gym Lunch',
      createdAt: DateTime.now(),
      meal: MealType.lunch,
      items: const [
        SavedMealItem(food: rice, grams: 200, meal: MealType.lunch),
        SavedMealItem(food: oats, grams: 150, meal: MealType.lunch),
      ],
    );

    food.customMealPresets.add(preset);
    food.apiMeals.addAll([
      MealEntry(
        id: 'api-meal',
        food: const FoodItem(
          name: 'Gym Lunch',
          caloriesPer100g: 200,
          protein: 10,
          carbs: 20,
          fat: 5,
        ),
        grams: 300,
        meal: MealType.lunch,
        date: today,
      ),
      MealEntry(
        id: 'api-rice',
        food: rice,
        grams: 200,
        meal: MealType.lunch,
        date: today,
      ),
      MealEntry(
        id: 'api-shake',
        food: shake,
        grams: 100,
        meal: MealType.breakfast,
        date: today,
      ),
    ]);

    await food.removeCustomMealPreset('1000000000002');

    expect(
      food.recentQuickMeals.map((item) => item.food.name),
      ['Protein Shake'],
    );
  });

  test('recentQuickMeals shows my meal name instead of its foods', () {
    final food = FoodController();
    final today = MealEntry.normalizeDate(DateTime.now());
    food.customMealPresets.add(
      CustomMealPreset(
        id: '1000000000003',
        name: 'Gym Lunch',
        createdAt: DateTime.now(),
        meal: MealType.lunch,
        items: const [
          SavedMealItem(food: rice, grams: 200, meal: MealType.lunch),
          SavedMealItem(food: oats, grams: 150, meal: MealType.lunch),
        ],
      ),
    );
    food.apiMeals.addAll([
      MealEntry(
        id: '3',
        food: rice,
        grams: 200,
        meal: MealType.lunch,
        date: today,
      ),
      MealEntry(
        id: '2',
        food: oats,
        grams: 150,
        meal: MealType.lunch,
        date: today,
      ),
      MealEntry(
        id: '1',
        food: shake,
        grams: 100,
        meal: MealType.breakfast,
        date: today,
      ),
    ]);

    expect(
      food.recentQuickMeals.map((item) => item.food.name),
      ['Gym Lunch', 'Protein Shake'],
    );
  });

  testWidgets('saveCustomMealPreset does not add foods to favourites', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
    final food = FoodController();
    final preset = CustomMealPreset(
      id: '1000000000004',
      name: 'Gym Lunch',
      createdAt: DateTime.now(),
      meal: MealType.lunch,
      items: const [
        SavedMealItem(food: rice, grams: 200, meal: MealType.lunch),
        SavedMealItem(food: oats, grams: 150, meal: MealType.lunch),
      ],
    );

    await food.saveCustomMealPreset(preset, awaitSync: false);
    await tester.pump();
    expect(food.customMealPresets, hasLength(1));
    expect(food.favoriteMeals, isEmpty);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('saveCustomFoodPreset does not add food to favourites', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: SizedBox.shrink()));
    final food = FoodController();
    final preset = CustomFoodPreset(
      id: '1000000000005',
      food: shake,
      defaultGrams: 100,
      createdAt: DateTime.now(),
    );

    await food.saveCustomFoodPreset(preset, awaitSync: false);
    await tester.pump();
    expect(food.customFoodPresets, hasLength(1));
    expect(food.favoriteMeals, isEmpty);
    await tester.pump(const Duration(seconds: 3));
  });

  test('withItemPhotos fills missing meal item images from my foods', () {
    final food = FoodController();
    const photo =
        'https://fitbuddyai.s3.ap-south-1.amazonaws.com/uploads/akki-roti.png';
    food.customFoodPresets.add(
      CustomFoodPreset(
        id: 'food-1',
        food: FoodItem(
          name: 'Akki Roti',
          caloriesPer100g: 117,
          protein: 3,
          carbs: 22,
          fat: 2,
          imageUrl: photo,
        ),
        defaultGrams: 90,
        createdAt: DateTime(2026, 8, 1),
      ),
    );

    final preset = CustomMealPreset(
      id: 'meal-1',
      name: 'Gym',
      createdAt: DateTime(2026, 8, 1),
      meal: MealType.breakfast,
      items: const [
        SavedMealItem(
          food: FoodItem(
            name: 'Akki Roti',
            caloriesPer100g: 117,
            protein: 3,
            carbs: 22,
            fat: 2,
          ),
          grams: 180,
          meal: MealType.breakfast,
        ),
      ],
    );

    expect(food.withItemPhotos(preset).items.single.food.imageUrl, photo);
  });

  test('withItemPhotos fills missing meal item images from search results', () {
    final food = FoodController();
    const photo =
        'https://fitbuddyai.srhsoftwares.com/uploads/chana-dal.png';
    food.searchResults.add(
      const FoodItem(
        name: 'Chana Dal',
        caloriesPer100g: 164,
        protein: 9,
        carbs: 25,
        fat: 3,
        imageUrl: photo,
      ),
    );

    final preset = CustomMealPreset(
      id: 'meal-2',
      name: 'Gym',
      createdAt: DateTime(2026, 8, 1),
      meal: MealType.breakfast,
      items: const [
        SavedMealItem(
          food: FoodItem(
            name: 'Chana Dal',
            caloriesPer100g: 164,
            protein: 9,
            carbs: 25,
            fat: 3,
          ),
          grams: 100,
          meal: MealType.breakfast,
        ),
      ],
    );

    expect(food.withItemPhotos(preset).items.single.food.imageUrl, photo);
  });

  test('hydrateCustomMealPhotos keeps items when catalog search is unavailable',
      () async {
    final food = FoodController();
    final preset = CustomMealPreset(
      id: 'meal-3',
      name: 'Gym',
      createdAt: DateTime(2026, 8, 1),
      meal: MealType.breakfast,
      items: const [
        SavedMealItem(
          food: FoodItem(
            name: 'Akki Roti',
            caloriesPer100g: 117,
            protein: 3,
            carbs: 22,
            fat: 2,
          ),
          grams: 180,
          meal: MealType.breakfast,
        ),
      ],
    );

    final hydrated = await food.hydrateCustomMealPhotos(preset);
    expect(hydrated.items.single.food.name, 'Akki Roti');
    expect(hydrated.items.single.food.imageUrl, isNull);
  });

  test('toggleFavorite adds a food once and removes it on the next tap',
      () async {
    final food = FoodController();
    final first = SavedMealItem(
      food: oats,
      grams: 150,
      meal: MealType.breakfast,
    );
    final secondPortion = SavedMealItem(
      food: oats,
      grams: 220,
      meal: MealType.lunch,
    );

    expect(await food.toggleFavorite(first), isTrue);
    expect(food.favoriteMeals, hasLength(1));
    expect(food.isFavoriteFood(oats), isTrue);
    expect(food.isFavoriteFood(oats, MealType.dinner), isTrue);

    expect(await food.toggleFavorite(secondPortion), isFalse);
    expect(food.favoriteMeals, isEmpty);
    expect(food.isFavoriteFood(oats), isFalse);
  });

  test('toggleFavorite removes duplicate rows of the same food', () async {
    final food = FoodController();
    food.favoriteMeals.addAll([
      SavedMealItem(
        food: oats,
        grams: 150,
        meal: MealType.breakfast,
      ),
      SavedMealItem(
        food: oats,
        grams: 220,
        meal: MealType.lunch,
      ),
    ]);

    expect(
      await food.toggleFavorite(
        SavedMealItem(food: oats, grams: 100, meal: MealType.dinner),
      ),
      isFalse,
    );
    expect(food.favoriteMeals, isEmpty);
  });
}
