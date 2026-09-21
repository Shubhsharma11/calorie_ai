import 'dart:async';

import 'package:calorie_ai/controllers/food_controller.dart';
import 'package:calorie_ai/controllers/rewards_controller.dart';
import 'package:calorie_ai/controllers/user_controller.dart';
import 'package:calorie_ai/models/claimable_result.dart';
import 'package:calorie_ai/models/food_item.dart';
import 'package:calorie_ai/models/meal_entry.dart';
import 'package:calorie_ai/models/meal_type.dart';
import 'package:calorie_ai/repositories/auth_repository.dart';
import 'package:calorie_ai/repositories/meals_repository.dart';
import 'package:calorie_ai/services/api_client.dart';
import 'package:calorie_ai/services/coins_api_service.dart';
import 'package:calorie_ai/services/local_storage_service.dart';
import 'package:calorie_ai/services/meals_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(storage: LocalStorageService());

  Map<String, dynamic> disk = {
    'userId': 'u1',
    'provider': 'google',
    'email': 'a@b.com',
    'name': 'Test',
    'accessToken': 'test-access-token-xxxxxx',
    'refreshToken': 'test-refresh',
    'backendResponse': <String, dynamic>{},
    'setupComplete': true,
  };

  @override
  Future<Map<String, dynamic>> loadSession() async =>
      Map<String, dynamic>.from(disk);

  @override
  Future<void> saveSession({
    required String userId,
    required String provider,
    required String email,
    required String name,
    required String accessToken,
    String? refreshToken,
    required Map<String, dynamic> backendResponse,
    bool setupComplete = false,
    String? avatarUrl,
    String? avatarExpiresAt,
  }) async {
    disk = {
      'userId': userId,
      'provider': provider,
      'email': email,
      'name': name,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'backendResponse': backendResponse,
      'setupComplete': setupComplete,
    };
  }

  @override
  Future<void> clearLocalAuthData() async {
    disk = {};
  }
}

class _GatedMealsRepository extends MealsRepository {
  Completer<List<MealEntry>>? gate;
  Object? throwError;

  @override
  Future<List<MealEntry>> fetchMeals({
    required String accessToken,
    DateTime? date,
    String? period,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final g = gate;
    if (g != null) await g.future;
    final err = throwError;
    if (err != null) throw err;
    return [
      MealEntry(
        id: 'meal-from-old-session',
        food: const FoodItem(
          name: 'Old Session Meal',
          caloriesPer100g: 100,
          protein: 1,
          carbs: 1,
          fat: 1,
        ),
        grams: 100,
        meal: MealType.breakfast,
      ),
    ];
  }
}

class _CountingCoinsApi extends CoinsApiService {
  int walletFetches = 0;
  Object? walletError;
  Completer<void>? walletGate;

  @override
  Future<CoinsWalletResult> fetchWallet({required String accessToken}) async {
    final g = walletGate;
    if (g != null) await g.future;
    walletFetches++;
    final err = walletError;
    if (err != null) throw err;
    return const CoinsWalletResult(balance: 999);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
    await Get.deleteAll(force: true);
    ApiClient.clearRateLimit();
  });

  tearDown(() async {
    ApiClient.clearRateLimit();
    await Get.deleteAll(force: true);
  });

  test('a) logout/session clear resets ApiClient rate-limit state', () async {
    ApiClient.noteRateLimited(cooldown: const Duration(minutes: 5));
    expect(ApiClient.isRateLimited, isTrue);

    final auth = _FakeAuthRepository();
    final user = UserController(authRepository: auth);
    Get.put(user, permanent: true);
    await user.localProfileReady;
    expect(user.isLoggedIn, isTrue);

    // Same path as logout / clearInvalidSession.
    await user.clearInvalidSession();

    expect(ApiClient.isRateLimited, isFalse);
  });

  test(
    'b) old in-flight meal request cannot affect a new session',
    () async {
      final auth = _FakeAuthRepository();
      final user = UserController(authRepository: auth);
      Get.put(user, permanent: true);
      await user.localProfileReady;

      final meals = _GatedMealsRepository();
      meals.gate = Completer<List<MealEntry>>();
      final food = FoodController(mealsRepository: meals);
      Get.put(food, permanent: true);

      final genBefore = food.debugSessionGeneration;
      final pending = food.refreshMealsFromApi();
      await Future<void>.delayed(Duration.zero);

      food.clearSessionData();
      expect(food.debugSessionGeneration, greaterThan(genBefore));
      expect(food.entries, isEmpty);

      meals.gate!.complete([
        MealEntry(
          id: 'meal-from-old-session',
          food: const FoodItem(
            name: 'Old Session Meal',
            caloriesPer100g: 100,
            protein: 1,
            carbs: 1,
            fat: 1,
          ),
          grams: 100,
          meal: MealType.breakfast,
        ),
      ]);
      await pending;

      expect(food.entries, isEmpty);
      expect(food.apiMeals, isEmpty);
    },
  );

  test('c) old wallet retry cannot affect a new session', () async {
    final auth = _FakeAuthRepository();
    final user = UserController(authRepository: auth);
    Get.put(user, permanent: true);
    await user.localProfileReady;

    final coins = _CountingCoinsApi();
    final rewards = RewardsController(coinsApi: coins);
    Get.put(rewards, permanent: true);

    ApiClient.noteRateLimited(cooldown: const Duration(milliseconds: 40));
    await rewards.refreshWalletFromApi(retryOnRateLimit: true);
    expect(rewards.debugWalletRetryScheduled, isTrue);
    expect(coins.walletFetches, 0);

    final genBefore = rewards.debugSessionGeneration;
    rewards.clearSessionData();
    expect(rewards.debugSessionGeneration, greaterThan(genBefore));
    expect(rewards.debugWalletRetryScheduled, isFalse);

    // Retry was scheduled ~1s out (cooldown + 1s buffer). Wait past it.
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    expect(coins.walletFetches, 0);
    expect(rewards.balance.value, isNot(999));
  });

  test('d) meals 401 clears the session without retry', () async {
    final auth = _FakeAuthRepository();
    final user = UserController(authRepository: auth);
    Get.put(user, permanent: true);
    await user.localProfileReady;
    expect(user.isLoggedIn, isTrue);

    final meals = _CountingAuthMealsRepository();
    meals.error = const MealsApiException(
      'Invalid or expired access token',
      statusCode: 401,
    );
    final food = FoodController(mealsRepository: meals);
    Get.put(food, permanent: true);

    await food.refreshMealsFromApi();

    expect(meals.calls, 1);
    expect(user.isLoggedIn, isFalse);
    expect(user.accessToken, isEmpty);
    expect(auth.disk, isEmpty);
    // No blind retry of the same 401.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(meals.calls, 1);
  });

  test('e) wallet 401 clears the session without retry', () async {
    final auth = _FakeAuthRepository();
    final user = UserController(authRepository: auth);
    Get.put(user, permanent: true);
    await user.localProfileReady;
    expect(user.isLoggedIn, isTrue);

    final coins = _CountingCoinsApi();
    coins.walletError = const CoinsApiException(
      'Invalid or expired access token',
      statusCode: 401,
    );
    final rewards = RewardsController(coinsApi: coins);
    Get.put(rewards, permanent: true);

    await rewards.refreshWalletFromApi(retryOnRateLimit: true);

    expect(coins.walletFetches, 1);
    expect(user.isLoggedIn, isFalse);
    expect(user.accessToken, isEmpty);
    expect(auth.disk, isEmpty);
    // No second fetch (no auth retry).
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(coins.walletFetches, 1);
  });
}

class _CountingAuthMealsRepository extends MealsRepository {
  int calls = 0;
  Object? error;

  @override
  Future<List<MealEntry>> fetchMeals({
    required String accessToken,
    DateTime? date,
    String? period,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    calls++;
    final err = error;
    if (err != null) throw err;
    return const [];
  }
}
