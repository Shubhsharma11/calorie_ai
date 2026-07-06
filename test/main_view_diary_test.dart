import 'package:calorie_ai/bindings/home_binding.dart';
import 'package:calorie_ai/controllers/food_controller.dart';
import 'package:calorie_ai/controllers/main_controller.dart';
import 'package:calorie_ai/controllers/theme_controller.dart';
import 'package:calorie_ai/controllers/user_controller.dart';
import 'package:calorie_ai/models/food_item.dart';
import 'package:calorie_ai/models/meal_entry.dart';
import 'package:calorie_ai/models/meal_type.dart';
import 'package:calorie_ai/views/main_view.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  Future<void> pumpDiaryTab(WidgetTester tester) async {
    Get.put(ThemeController(), permanent: true);
    Get.put(UserController(), permanent: true);
    HomeBinding().dependencies();
    Get.find<MainController>().changeTab(1);

    await tester.pumpWidget(
      const GetMaterialApp(home: MainView()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('MainView Diary tab builds without throwing',
      (WidgetTester tester) async {
    await pumpDiaryTab(tester);

    expect(find.text('Daily Log'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MainView Diary tab with logged meals builds',
      (WidgetTester tester) async {
    Get.put(ThemeController(), permanent: true);
    Get.put(UserController(), permanent: true);
    HomeBinding().dependencies();

    final food = Get.find<FoodController>();
    final today = MealEntry.normalizeDate(DateTime.now());
    food.entries.add(
      MealEntry(
        id: 'entry-1',
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
        date: today,
      ),
    );
    food.entriesRevision.value++;

    Get.find<MainController>().changeTab(1);
    await tester.pumpWidget(
      const GetMaterialApp(home: MainView()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Daily Log'), findsOneWidget);
    expect(find.text('Oats'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
