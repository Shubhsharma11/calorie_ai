import 'dart:async';

import 'package:calorie_ai/controllers/food_controller.dart';
import 'package:calorie_ai/controllers/user_controller.dart';
import 'package:calorie_ai/core/home_hydrate.dart';
import 'package:calorie_ai/models/food_item.dart';
import 'package:calorie_ai/models/meal_entry.dart';
import 'package:calorie_ai/repositories/auth_repository.dart';
import 'package:calorie_ai/repositories/meals_repository.dart';
import 'package:calorie_ai/services/food_api_service.dart';
import 'package:calorie_ai/services/local_storage_service.dart';
import 'package:calorie_ai/services/meals_api_service.dart';
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

/// Incomplete catalog fields so post-meals enrichment will search.
FoodItem _sparseFood(String name) => FoodItem(
      name: name,
      caloriesPer100g: 120,
      protein: 5,
      carbs: 10,
      fat: 3,
    );

MealEntry _sparseMeal(String name, {String? id}) => MealEntry(
      id: id ?? 'm-$name',
      food: _sparseFood(name),
      grams: 100,
      meal: 'Custom',
    );

class _CountingMealsRepository extends MealsRepository {
  int fetchCount = 0;
  List<MealEntry> meals = const [];
  Object? throwError;

  @override
  Future<List<MealEntry>> fetchMeals({
    required String accessToken,
    DateTime? date,
    String? period,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    fetchCount++;
    final err = throwError;
    if (err != null) throw err;
    return List<MealEntry>.from(meals);
  }
}

class _CountingFoodApi extends FoodApiService {
  int searchCount = 0;
  final List<String> searchQueries = <String>[];
  final Map<String, Completer<List<FoodItem>>> gates =
      <String, Completer<List<FoodItem>>>{};
  final Map<String, Object> throwByQuery = <String, Object>{};
  final Map<String, List<FoodItem>> resultsByQuery = <String, List<FoodItem>>{};

  @override
  Future<List<FoodItem>> searchFoods(
    String query, {
    String? accessToken,
    int page = 1,
    int limit = 20,
  }) async {
    searchCount++;
    final trimmed = query.trim();
    searchQueries.add(trimmed);
    final key = trimmed.toLowerCase();

    final gate = gates[key];
    if (gate != null) await gate.future;

    final err = throwByQuery[key];
    if (err != null) {
      if (err is FoodApiException) throw err;
      throw err;
    }

    return List<FoodItem>.from(
      resultsByQuery[key] ??
          [
            FoodItem(
              name: trimmed,
              caloriesPer100g: 120,
              protein: 5,
              carbs: 10,
              fat: 3,
              imageUrl: 'https://example.com/$key.png',
              servingUnit: 'bowl',
              gramsPerServing: 100,
            ),
          ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingMealsRepository mealsRepo;
  late _CountingFoodApi foodApi;
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
    foodApi = _CountingFoodApi();
    food = FoodController(api: foodApi, mealsRepository: mealsRepo);
    Get.put(food, permanent: true);
  });

  tearDown(() async {
    HomeHydrate.debugReset();
    await Get.deleteAll(force: true);
  });

  Future<void> awaitCatalogHydrate() async {
    // Meals refresh returns before enrichment; give the microtask a chance to
    // assign [debugMealCatalogHydrateInFlight], then await it.
    await Future<void>.delayed(Duration.zero);
    final hydrate = food.debugMealCatalogHydrateInFlight;
    if (hydrate != null) await hydrate;
  }

  test('multiple meals with same food name → one search-foods request',
      () async {
    mealsRepo.meals = [
      _sparseMeal('Paneer', id: '1'),
      _sparseMeal('Paneer', id: '2'),
      _sparseMeal('Paneer', id: '3'),
    ];

    await food.refreshMealsFromApi();
    await awaitCatalogHydrate();

    expect(mealsRepo.fetchCount, 1);
    expect(foodApi.searchCount, 1);
    expect(food.apiMeals, hasLength(3));
    expect(food.mealsApiErrorMessage.value, isNull);
  });

  test('case-normalized names share one search (Paneer / paneer)', () async {
    mealsRepo.meals = [
      _sparseMeal('Paneer', id: '1'),
      _sparseMeal('paneer', id: '2'),
      _sparseMeal('PANEER', id: '3'),
    ];

    await food.refreshMealsFromApi();
    await awaitCatalogHydrate();

    expect(foodApi.searchCount, 1);
    expect(
      foodApi.searchQueries.map((q) => q.toLowerCase()).toSet(),
      {'paneer'},
    );
  });

  test('different food names issue separate searches', () async {
    mealsRepo.meals = [
      _sparseMeal('Paneer', id: '1'),
      _sparseMeal('Dal', id: '2'),
      _sparseMeal('Rice', id: '3'),
    ];

    await food.refreshMealsFromApi();
    await awaitCatalogHydrate();

    expect(foodApi.searchCount, 3);
    expect(
      foodApi.searchQueries.map((q) => q.toLowerCase()).toSet(),
      {'paneer', 'dal', 'rice'},
    );
  });

  test('normalization does not merge unrelated foods', () async {
    mealsRepo.meals = [
      _sparseMeal('Paneer Butter Masala', id: '1'),
      _sparseMeal('Paneer', id: '2'),
    ];

    await food.refreshMealsFromApi();
    await awaitCatalogHydrate();

    expect(foodApi.searchCount, 2);
  });

  test('identical in-flight searchFoodsEphemeral calls coalesce', () async {
    final gate = Completer<List<FoodItem>>();
    foodApi.gates['paneer'] = gate;

    final a = food.searchFoodsEphemeral('Paneer');
    final b = food.searchFoodsEphemeral('paneer');
    final c = food.searchFoodsEphemeral('PANEER');

    // Token resolution is async; wait until the single HTTP call is gated.
    for (var i = 0; i < 40 && foodApi.searchCount == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(foodApi.searchCount, 1);

    gate.complete([
      FoodItem(
        name: 'Paneer',
        caloriesPer100g: 120,
        protein: 5,
        carbs: 10,
        fat: 3,
        imageUrl: 'https://example.com/paneer.png',
        servingUnit: 'bowl',
        gramsPerServing: 100,
      ),
    ]);

    final results = await Future.wait([a, b, c]);
    expect(foodApi.searchCount, 1);
    expect(results.every((r) => r.length == 1), isTrue);
  });

  test('repeated meals refresh joins identical in-flight catalog search',
      () async {
    final gate = Completer<List<FoodItem>>();
    foodApi.gates['paneer'] = gate;
    mealsRepo.meals = [_sparseMeal('Paneer')];

    final first = food.refreshMealsFromApi();
    await Future<void>.delayed(Duration.zero);
    // First enrichment must have opened the search and be waiting on [gate].
    expect(foodApi.searchCount, 1);

    final second = food.refreshMealsFromApi();
    await first;
    await Future<void>.delayed(Duration.zero);
    // Second hydrate joins the same in-flight search — no second HTTP.
    expect(foodApi.searchCount, 1);

    gate.complete([
      FoodItem(
        name: 'Paneer',
        caloriesPer100g: 120,
        protein: 5,
        carbs: 10,
        fat: 3,
        imageUrl: 'https://example.com/paneer.png',
        servingUnit: 'bowl',
        gramsPerServing: 100,
      ),
    ]);
    await second;
    await awaitCatalogHydrate();
    expect(foodApi.searchCount, 1);
  });

  test('meal retry joins identical in-flight catalog search', () async {
    final gate = Completer<List<FoodItem>>();
    foodApi.gates['oats'] = gate;
    mealsRepo.meals = [_sparseMeal('Oats')];

    unawaited(food.refreshMealsFromApi());
    await Future<void>.delayed(Duration.zero);
    expect(foodApi.searchCount, 1);

    // Explicit retry while search is in flight.
    unawaited(food.refreshMealsFromApi());
    await Future<void>.delayed(Duration.zero);
    expect(foodApi.searchCount, 1);

    gate.complete([
      FoodItem(
        name: 'Oats',
        caloriesPer100g: 100,
        protein: 4,
        carbs: 17,
        fat: 2,
        imageUrl: 'https://example.com/oats.png',
        servingUnit: 'bowl',
        gramsPerServing: 100,
      ),
    ]);
    await awaitCatalogHydrate();
  });

  test('catalog search failure does not fail successful meals load', () async {
    foodApi.throwByQuery['paneer'] = const FoodApiException(
      'search down',
      statusCode: 500,
    );
    mealsRepo.meals = [
      _sparseMeal('Paneer', id: '1'),
      _sparseMeal('Paneer', id: '2'),
    ];

    await food.refreshMealsFromApi();
    await awaitCatalogHydrate();

    expect(mealsRepo.fetchCount, 1);
    expect(food.mealsApiErrorMessage.value, isNull);
    expect(food.hasCompletedMealsFetch.value, isTrue);
    expect(food.isLoadingMealsApi.value, isFalse);
    expect(food.apiMeals, hasLength(2));
    expect(food.apiMeals.first.food.name, 'Paneer');
    expect(food.entries, hasLength(2));
  });

  test('later refresh retries enrichment after prior search failure', () async {
    foodApi.throwByQuery['dal'] = const FoodApiException(
      'temporary',
      statusCode: 503,
    );
    mealsRepo.meals = [_sparseMeal('Dal')];

    await food.refreshMealsFromApi();
    await awaitCatalogHydrate();
    expect(foodApi.searchCount, 1);
    expect(food.apiMeals.single.food.imageUrl, isNull);

    foodApi.throwByQuery.remove('dal');
    await food.refreshMealsFromApi();
    await awaitCatalogHydrate();

    expect(foodApi.searchCount, 2);
    expect(food.apiMeals.single.food.imageUrl, isNotNull);
    expect(food.mealsApiErrorMessage.value, isNull);
  });

  test('pull-to-refresh style refreshMealsFromApi still coalesces searches',
      () async {
    mealsRepo.meals = [
      _sparseMeal('Paneer', id: '1'),
      _sparseMeal('paneer', id: '2'),
    ];

    await food.refreshMealsFromApi();
    await awaitCatalogHydrate();
    expect(foodApi.searchCount, 1);

    // Catalog now remembered — second PTR should not re-search.
    await food.refreshMealsFromApi();
    await awaitCatalogHydrate();
    expect(foodApi.searchCount, 1);
    expect(food.mealsApiErrorMessage.value, isNull);
  });

  test('existing meals API error path still sets meals error (not catalog)',
      () async {
    mealsRepo.throwError = const MealsApiException(
      'meals unavailable',
      statusCode: 500,
    );

    await food.refreshMealsFromApi();
    await awaitCatalogHydrate();

    expect(food.mealsApiErrorMessage.value, 'meals unavailable');
    expect(foodApi.searchCount, 0);
  });
}
