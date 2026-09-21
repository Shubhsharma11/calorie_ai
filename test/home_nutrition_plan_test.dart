import 'dart:async';

import 'package:calorie_ai/controllers/food_controller.dart';
import 'package:calorie_ai/controllers/nutrition_plan_controller.dart';
import 'package:calorie_ai/controllers/rewards_controller.dart';
import 'package:calorie_ai/controllers/tracker_controller.dart';
import 'package:calorie_ai/controllers/user_controller.dart';
import 'package:calorie_ai/core/home_hydrate.dart';
import 'package:calorie_ai/models/claimable_result.dart';
import 'package:calorie_ai/models/meal_entry.dart';
import 'package:calorie_ai/models/nutrition_plan_model.dart';
import 'package:calorie_ai/models/water_log_entry.dart';
import 'package:calorie_ai/repositories/auth_repository.dart';
import 'package:calorie_ai/repositories/meals_repository.dart';
import 'package:calorie_ai/repositories/nutrition_plan_repository.dart';
import 'package:calorie_ai/repositories/water_repository.dart';
import 'package:calorie_ai/services/coins_api_service.dart';
import 'package:calorie_ai/services/local_storage_service.dart';
import 'package:calorie_ai/services/nutrition_plan_api_service.dart';
import 'package:calorie_ai/services/water_api_service.dart';
import 'package:calorie_ai/widgets/ai_meal_plan_card.dart';
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

class _GatedNutritionRepo extends NutritionPlanRepository {
  int fetchCount = 0;
  int createCount = 0;
  Completer<void>? gate;
  Object? throwError;
  NutritionPlanModel plan = _planWithPreview();

  @override
  Future<NutritionPlanModel> fetchPlan({required String accessToken}) async {
    fetchCount++;
    final g = gate;
    if (g != null) await g.future;
    final err = throwError;
    if (err != null) throw err;
    return plan;
  }

  @override
  Future<NutritionPlanModel> createPlan({
    required String accessToken,
    Map<String, dynamic>? body,
  }) async {
    createCount++;
    throw const NutritionPlanApiException('create not used in Phase 3 tests');
  }
}

class _CountingMealsRepo extends MealsRepository {
  int fetches = 0;

  @override
  Future<List<MealEntry>> fetchMeals({
    required String accessToken,
    DateTime? date,
    String? period,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    fetches++;
    return const [];
  }
}

class _CountingCoinsApi extends CoinsApiService {
  int walletFetches = 0;
  int claimableFetches = 0;

  @override
  Future<CoinsWalletResult> fetchWallet({required String accessToken}) async {
    walletFetches++;
    return const CoinsWalletResult(balance: 1);
  }

  @override
  Future<ClaimableResult> fetchClaimable({
    required String accessToken,
    required DateTime date,
    String? timezone,
  }) async {
    claimableFetches++;
    return const ClaimableResult(claimableCoins: 0);
  }
}

class _CountingWaterRepo extends WaterRepository {
  int dateFetches = 0;

  @override
  Future<WaterFetchResult> fetchWaterByDate({
    required String accessToken,
    required DateTime date,
  }) async {
    dateFetches++;
    throw const WaterApiException('not expected');
  }
}

NutritionPlanModel _planWithPreview() => const NutritionPlanModel(
      calories: 2000,
      proteinG: 120,
      carbsG: 200,
      fatG: 60,
      meals: [],
      foodsToAvoid: [],
      tips: [],
      homePreview: NutritionPlanMeal(
        title: 'Breakfast',
        name: 'Oats Bowl',
        calories: 350,
        proteinG: 18,
        items: ['Oats'],
      ),
    );

NutritionPlanModel _emptyPlan() => const NutritionPlanModel(
      calories: 0,
      proteinG: 0,
      carbsG: 0,
      fatG: 0,
      meals: [],
      foodsToAvoid: [],
      tips: [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _GatedNutritionRepo nutritionRepo;
  late NutritionPlanController nutrition;
  late _CountingMealsRepo mealsRepo;
  late _CountingCoinsApi coinsApi;
  late _CountingWaterRepo waterRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
    await Get.deleteAll(force: true);
    HomeHydrate.debugReset();

    final user = UserController(authRepository: _FakeAuthRepository());
    Get.put(user, permanent: true);
    await user.localProfileReady;

    nutritionRepo = _GatedNutritionRepo();
    nutrition = NutritionPlanController(repository: nutritionRepo);
    Get.put(nutrition, permanent: true);

    mealsRepo = _CountingMealsRepo();
    Get.put(FoodController(mealsRepository: mealsRepo), permanent: true);

    coinsApi = _CountingCoinsApi();
    Get.put(RewardsController(coinsApi: coinsApi), permanent: true);

    waterRepo = _CountingWaterRepo();
    Get.put(TrackerController(waterRepository: waterRepo), permanent: true);
  });

  tearDown(() async {
    HomeHydrate.debugReset();
    await Get.deleteAll(force: true);
  });

  test('loading → success', () async {
    nutritionRepo.gate = Completer<void>();
    nutritionRepo.plan = _planWithPreview();

    final pending = nutrition.loadPlan();
    await Future<void>.delayed(Duration.zero);

    expect(nutrition.isLoading.value, isTrue);
    expect(nutrition.hasCompletedFetch.value, isFalse);

    nutritionRepo.gate!.complete();
    await pending;

    expect(nutrition.isLoading.value, isFalse);
    expect(nutrition.hasCompletedFetch.value, isTrue);
    expect(nutrition.hasHomePreview, isTrue);
    expect(nutrition.errorMessage.value, isNull);
    expect(nutrition.plan.value?.previewMeal?.displayName, 'Oats Bowl');
  });

  test('missing / no-plan after successful empty response', () async {
    nutritionRepo.plan = _emptyPlan();
    await nutrition.loadPlan();

    expect(nutrition.hasCompletedFetch.value, isTrue);
    expect(nutrition.errorMessage.value, isNull);
    expect(nutrition.isMissingPlan, isTrue);
    expect(nutrition.hasHomePreview, isFalse);
  });

  test('404 is missing, not error', () async {
    nutritionRepo.throwError = const NutritionPlanApiException(
      'Not found',
      statusCode: 404,
    );
    await nutrition.loadPlan();

    expect(nutrition.errorMessage.value, isNull);
    expect(nutrition.plan.value, isNull);
    expect(nutrition.hasCompletedFetch.value, isTrue);
    expect(nutrition.isMissingPlan, isTrue);
  });

  test('API error sets message', () async {
    nutritionRepo.throwError = const NutritionPlanApiException(
      'Server down',
      statusCode: 500,
    );
    await nutrition.loadPlan();

    expect(nutrition.errorMessage.value, 'Server down');
    expect(nutrition.hasCompletedFetch.value, isTrue);
    expect(nutrition.isMissingPlan, isFalse);
  });

  test('simultaneous loadPlan calls coalesce into one HTTP request', () async {
    nutritionRepo.gate = Completer<void>();
    final a = nutrition.loadPlan();
    final b = nutrition.loadPlan();
    await Future<void>.delayed(Duration.zero);

    expect(identical(a, b), isTrue);
    expect(nutritionRepo.fetchCount, 1);

    nutritionRepo.gate!.complete();
    await Future.wait([a, b]);
    expect(nutritionRepo.fetchCount, 1);
  });

  test('retry only refreshes nutrition — not HomeHydrate or other sections',
      () async {
    var hydrateBodies = 0;
    HomeHydrate.debugRunOverride = (_) async {
      hydrateBodies++;
    };

    nutritionRepo.throwError = const NutritionPlanApiException(
      'Server down',
      statusCode: 500,
    );
    await nutrition.loadPlan();
    final fetchesAfterError = nutritionRepo.fetchCount;
    final mealsBefore = mealsRepo.fetches;
    final walletBefore = coinsApi.walletFetches;
    final claimableBefore = coinsApi.claimableFetches;
    final waterBefore = waterRepo.dateFetches;

    nutritionRepo.throwError = null;
    nutritionRepo.plan = _planWithPreview();
    await nutrition.retryPlan();

    expect(nutritionRepo.fetchCount, fetchesAfterError + 1);
    expect(nutrition.hasHomePreview, isTrue);
    expect(hydrateBodies, 0);
    expect(HomeHydrate.debugInFlight, isNull);
    expect(mealsRepo.fetches, mealsBefore);
    expect(coinsApi.walletFetches, walletBefore);
    expect(coinsApi.claimableFetches, claimableBefore);
    expect(waterRepo.dateFetches, waterBefore);
    expect(nutritionRepo.createCount, 0);
  });

  test('repeated retry taps join in-flight request', () async {
    nutritionRepo.throwError = const NutritionPlanApiException(
      'Server down',
      statusCode: 500,
    );
    await nutrition.loadPlan();
    final afterError = nutritionRepo.fetchCount;

    nutritionRepo.throwError = null;
    nutritionRepo.gate = Completer<void>();
    nutritionRepo.plan = _planWithPreview();

    final a = nutrition.retryPlan();
    await Future<void>.delayed(Duration.zero);
    final b = nutrition.retryPlan();
    await Future<void>.delayed(Duration.zero);

    expect(nutritionRepo.fetchCount, afterError + 1);
    expect(identical(a, b), isTrue);

    nutritionRepo.gate!.complete();
    await a;
    expect(nutrition.hasHomePreview, isTrue);
  });

  test('401 clears session without nutrition retry loop', () async {
    final user = Get.find<UserController>();
    expect(user.isLoggedIn, isTrue);

    nutritionRepo.throwError = const NutritionPlanApiException(
      'Invalid or expired access token',
      statusCode: 401,
    );
    await nutrition.loadPlan();

    expect(user.isLoggedIn, isFalse);
    expect(nutritionRepo.fetchCount, 1);
  });

  testWidgets('card shows loading / success / missing / error+retry',
      (tester) async {
    // Loading
    nutrition.isLoading.value = true;
    nutrition.hasCompletedFetch.value = false;
    await tester.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: AiMealPlanCard())),
    );
    await tester.pump();
    expect(find.text('Fetching your nutrition plan…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Success
    nutrition.setLoadedPlan(_planWithPreview());
    await tester.pump();
    expect(find.text('Oats Bowl'), findsOneWidget);
    expect(find.text('View Plan'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);

    // Missing
    nutrition.plan.value = _emptyPlan();
    nutrition.errorMessage.value = null;
    nutrition.hasCompletedFetch.value = true;
    nutrition.isLoading.value = false;
    nutrition.revision.value++;
    await tester.pump();
    expect(find.text('No meal plan yet'), findsOneWidget);
    expect(find.text('Generate'), findsOneWidget);

    // Error
    nutrition.plan.value = null;
    nutrition.errorMessage.value = 'Server down';
    nutrition.hasCompletedFetch.value = true;
    nutrition.isLoading.value = false;
    nutrition.revision.value++;
    await tester.pump();
    expect(find.text('Couldn’t load your nutrition plan'), findsOneWidget);
    expect(find.text('Server down'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
