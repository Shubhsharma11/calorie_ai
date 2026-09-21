import 'dart:async';

import 'package:calorie_ai/controllers/food_controller.dart';
import 'package:calorie_ai/controllers/user_controller.dart';
import 'package:calorie_ai/core/home_hydrate.dart';
import 'package:calorie_ai/models/food_item.dart';
import 'package:calorie_ai/models/meal_entry.dart';
import 'package:calorie_ai/repositories/auth_repository.dart';
import 'package:calorie_ai/repositories/meals_repository.dart';
import 'package:calorie_ai/services/local_storage_service.dart';
import 'package:calorie_ai/widgets/home_meals_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(storage: LocalStorageService());

  @override
  Future<Map<String, dynamic>> loadSession() async => {
        'userId': 'u1',
        'provider': 'google',
        'email': 'a@b.com',
        'name': 'Test',
        'accessToken': 'test-access-token-xxxxxx',
        'refreshToken': 'test-refresh',
        'backendResponse': <String, dynamic>{},
        'setupComplete': true,
      };
}

class _CountingMealsRepository extends MealsRepository {
  int fetchCount = 0;
  Completer<List<MealEntry>>? gate;
  Object? throwError;
  List<MealEntry> meals = const [];

  @override
  Future<List<MealEntry>> fetchMeals({
    required String accessToken,
    DateTime? date,
    String? period,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    fetchCount++;
    final g = gate;
    if (g != null) await g.future;
    final err = throwError;
    if (err != null) throw err;
    return List<MealEntry>.from(meals);
  }
}

/// Catalog-complete food so refresh won't kick a background food search.
FoodItem _food(String name) => FoodItem(
      name: name,
      caloriesPer100g: 100,
      protein: 1,
      carbs: 1,
      fat: 1,
      imageUrl: 'https://example.com/$name.png',
      servingUnit: 'bowl',
      gramsPerServing: 100,
    );

MealEntry _meal(String name) => MealEntry(
      id: 'm-$name',
      food: _food(name),
      grams: 100,
      // Avoid MealTypeIcon SVG asset loads that can stall widget tests.
      meal: 'Custom',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingMealsRepository mealsRepo;
  late FoodController food;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
    await Get.deleteAll(force: true);
    HomeHydrate.debugReset();

    final user = UserController(authRepository: _FakeAuthRepository());
    Get.put(user, permanent: true);
    await user.localProfileReady;

    mealsRepo = _CountingMealsRepository();
    food = FoodController(mealsRepository: mealsRepo);
    Get.put(food, permanent: true);
  });

  tearDown(() async {
    HomeHydrate.debugReset();
    await Get.deleteAll(force: true);
  });

  Future<void> pumpPreview(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeMealsPreview(
              food: food,
              viewingToday: true,
              dateLabel: 'Today',
              onAddFood: () {},
              onRetry: () {
                food.refreshMealsFromApi();
              },
            ),
          ),
        ),
      ),
    );
  }

  void seedCompleted({
    List<MealEntry> meals = const [],
    String? error,
    bool loading = false,
  }) {
    food.entries.assignAll(meals);
    food.apiMeals.assignAll(meals);
    food.hasCompletedMealsFetch.value = true;
    food.isLoadingMealsApi.value = loading;
    food.mealsApiErrorMessage.value = error;
    food.entriesRevision.value++;
  }

  testWidgets('meals loading state is shown before first fetch completes',
      (tester) async {
    expect(food.hasCompletedMealsFetch.value, isFalse);
    food.isLoadingMealsApi.value = true;

    await pumpPreview(tester);
    await tester.pump();

    expect(find.text('Loading meals…'), findsOneWidget);
    expect(find.text('Tap Add Food to log your first meal today.'), findsNothing);
  });

  testWidgets('meals success state shows meal previews', (tester) async {
    seedCompleted(meals: [_meal('Oatmeal')]);

    await pumpPreview(tester);
    await tester.pump();

    expect(find.text('Custom'), findsOneWidget);
    expect(find.textContaining('Oatmeal'), findsOneWidget);
    expect(find.text('Loading meals…'), findsNothing);
    expect(find.text('Couldn’t load meals'), findsNothing);
  });

  testWidgets('meals empty state after successful empty response',
      (tester) async {
    seedCompleted();

    await pumpPreview(tester);
    await tester.pump();

    expect(find.text('Tap Add Food to log your first meal today.'), findsOneWidget);
    expect(find.text('Loading meals…'), findsNothing);
    expect(find.text('Couldn’t load meals'), findsNothing);
  });

  testWidgets('meals error state is shown with retry', (tester) async {
    seedCompleted(error: 'Server unavailable');

    await pumpPreview(tester);
    await tester.pump();

    expect(find.text('Couldn’t load meals'), findsOneWidget);
    expect(find.text('Server unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Tap Add Food to log your first meal today.'), findsNothing);
  });

  test('meals retry coalesces identical GETs and does not start Home cascade',
      () async {
    var hydrateBodies = 0;
    HomeHydrate.debugRunOverride = (_) async {
      hydrateBodies++;
    };

    mealsRepo.meals = [_meal('Toast')];
    mealsRepo.gate = Completer<List<MealEntry>>();

    final first = food.refreshMealsFromApi();
    // Flush auth awaits so the repository is reached.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(mealsRepo.fetchCount, 1);
    expect(hydrateBodies, 0);
    expect(HomeHydrate.debugInFlight, isNull);
    expect(food.isLoadingMealsApi.value, isTrue);

    final joined = food.refreshMealsFromApi();
    expect(identical(first, joined), isTrue);
    expect(mealsRepo.fetchCount, 1);

    mealsRepo.gate!.complete(List<MealEntry>.from(mealsRepo.meals));
    await first;

    expect(hydrateBodies, 0);
    expect(food.hasCompletedMealsFetch.value, isTrue);
    expect(food.mealsApiErrorMessage.value, isNull);
    expect(food.entries.any((e) => e.food.name == 'Toast'), isTrue);
  });

  testWidgets('meals Retry button triggers meals refresh callback only',
      (tester) async {
    var mealsRetries = 0;
    var hydrateBodies = 0;
    HomeHydrate.debugRunOverride = (_) async {
      hydrateBodies++;
    };

    seedCompleted(error: 'Network blip');
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: HomeMealsPreview(
            food: food,
            viewingToday: true,
            dateLabel: 'Today',
            onAddFood: () {},
            onRetry: () {
              mealsRetries++;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(mealsRetries, 1);
    expect(hydrateBodies, 0);
    expect(HomeHydrate.debugInFlight, isNull);
  });
}
