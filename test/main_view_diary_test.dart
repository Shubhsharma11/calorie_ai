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
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    // Skip first-run coach overlay so Diary content is findable.
    SharedPreferences.setMockInitialValues({
      'coach_marks_seen_v1': true,
    });
    Get.testMode = true;
    Get.reset();
  });

  tearDown(Get.reset);

  /// Current MainView only builds a tab after it is activated, and
  /// [MainController.changeTab] no-ops (with snackbar) until [shellReady].
  Future<void> pumpDiaryTab(WidgetTester tester) async {
    Get.put(ThemeController(), permanent: true);
    Get.put(UserController(), permanent: true);
    HomeBinding().dependencies();

    await tester.pumpWidget(
      const GetMaterialApp(home: MainView()),
    );
    await tester.pump();

    final main = Get.find<MainController>();
    // Mark shell ready without waiting on settleShell's production frame delay.
    main.shellReady.value = true;
    main.changeTab(MainController.diaryTabIndex);
    await tester.pump();
    // Flush the 200ms timer already scheduled by settleShell.onReady.
    await tester.pump(const Duration(milliseconds: 200));
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

    await tester.pumpWidget(
      const GetMaterialApp(home: MainView()),
    );
    await tester.pump();

    final main = Get.find<MainController>();
    main.shellReady.value = true;
    main.changeTab(MainController.diaryTabIndex);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Daily Log'), findsOneWidget);
    expect(find.text('Oats'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
