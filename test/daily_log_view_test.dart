import 'package:calorie_ai/controllers/dashboard_controller.dart';
import 'package:calorie_ai/controllers/food_controller.dart';
import 'package:calorie_ai/controllers/user_controller.dart';
import 'package:calorie_ai/models/food_item.dart';
import 'package:calorie_ai/models/meal_entry.dart';
import 'package:calorie_ai/models/meal_type.dart';
import 'package:calorie_ai/models/saved_meal_item.dart';
import 'package:calorie_ai/views/daily_log_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('DailyLogView renders with meal entries and quick meals',
      (WidgetTester tester) async {
    final user = UserController();
    Get.put(user, permanent: true);

    final food = FoodController();
    Get.put(food, permanent: true);
    Get.put(DashboardController(), permanent: true);

    const oats = FoodItem(
      name: 'Oats',
      caloriesPer100g: 389,
      protein: 16.9,
      carbs: 66.3,
      fat: 6.9,
      emoji: '🥣',
    );

    final today = MealEntry.normalizeDate(DateTime.now());
    food.entries.addAll([
      MealEntry(
        id: 'entry-1',
        food: oats,
        grams: 150,
        meal: MealType.breakfast,
        date: today,
      ),
      MealEntry(
        id: 'entry-2',
        food: oats,
        grams: 100,
        meal: MealType.lunch,
        date: today,
      ),
    ]);
    food.apiMeals.addAll(food.entries);
    food.favoriteMeals.add(
      const SavedMealItem(
        food: oats,
        grams: 150,
        meal: MealType.breakfast,
      ),
    );
    food.entriesRevision.value++;

    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(body: DailyLogView()),
      ),
    );
    await tester.pump();

    expect(find.text('Daily Log'), findsOneWidget);
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Oats'), findsWidgets);
  });

  testWidgets('DailyLogView handles duplicate entry ids without crashing',
      (WidgetTester tester) async {
    Get.put(UserController(), permanent: true);
    final food = FoodController();
    Get.put(food, permanent: true);
    Get.put(DashboardController(), permanent: true);

    const oats = FoodItem(
      name: 'Oats',
      caloriesPer100g: 389,
      protein: 16.9,
      carbs: 66.3,
      fat: 6.9,
      emoji: '🥣',
    );

    final today = MealEntry.normalizeDate(DateTime.now());
    food.entries.addAll([
      MealEntry(
        id: 'duplicate-id',
        food: oats,
        grams: 150,
        meal: MealType.breakfast,
        date: today,
      ),
      MealEntry(
        id: 'duplicate-id',
        food: oats,
        grams: 100,
        meal: MealType.breakfast,
        date: today,
      ),
    ]);
    food.entriesRevision.value++;

    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(body: DailyLogView()),
      ),
    );

    final error = tester.takeException();
    expect(error, isNull);
  });
}
