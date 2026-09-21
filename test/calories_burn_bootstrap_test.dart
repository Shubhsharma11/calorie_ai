import 'dart:async';

import 'package:calorie_ai/controllers/rewards_controller.dart';
import 'package:calorie_ai/controllers/tracker_controller.dart';
import 'package:calorie_ai/controllers/user_controller.dart';
import 'package:calorie_ai/core/home_hydrate.dart';
import 'package:calorie_ai/models/claimable_result.dart';
import 'package:calorie_ai/models/meal_entry.dart';
import 'package:calorie_ai/models/step_log_entry.dart';
import 'package:calorie_ai/repositories/auth_repository.dart';
import 'package:calorie_ai/repositories/steps_repository.dart';
import 'package:calorie_ai/services/api_client.dart';
import 'package:calorie_ai/services/coins_api_service.dart';
import 'package:calorie_ai/services/local_storage_service.dart';
import 'package:calorie_ai/services/steps_api_service.dart';
import 'package:calorie_ai/views/calories_burn_view.dart';
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

class _CountingStepsRepository extends StepsRepository {
  int fetchByDateCount = 0;
  int syncCount = 0;
  final List<DateTime> fetchDates = <DateTime>[];
  final List<int> postedStepValues = <int>[];

  Completer<StepsFetchResult>? fetchGate;
  Completer<StepLogResponse>? syncGate;

  StepsFetchResult fetchResult = const StepsFetchResult();
  StepLogResponse syncResponse = const StepLogResponse();
  Object? fetchError;
  Object? syncError;

  @override
  Future<StepsFetchResult> fetchStepsByDate({
    required String accessToken,
    required DateTime date,
  }) async {
    fetchByDateCount++;
    fetchDates.add(MealEntry.normalizeDate(date));
    final gate = fetchGate;
    if (gate != null) await gate.future;
    final err = fetchError;
    if (err != null) {
      if (err is StepsApiException) throw err;
      throw err;
    }
    return fetchResult;
  }

  @override
  Future<StepLogResponse> syncSteps({
    required String accessToken,
    required int steps,
    required int caloriesBurned,
    DateTime? date,
  }) async {
    syncCount++;
    postedStepValues.add(steps);
    final gate = syncGate;
    if (gate != null) await gate.future;
    final err = syncError;
    if (err != null) {
      if (err is StepsApiException) throw err;
      throw err;
    }
    return syncResponse;
  }
}

class _CoinsApi extends CoinsApiService {
  int walletFetches = 0;
  int claimableFetches = 0;
  final List<DateTime> claimableDates = <DateTime>[];
  Object? walletError;
  CoinsWalletResult walletResult = const CoinsWalletResult(balance: 42);
  ClaimableResult claimableResult = const ClaimableResult(
    claimableCoins: 10,
    canClaim: true,
  );

  @override
  Future<CoinsWalletResult> fetchWallet({required String accessToken}) async {
    walletFetches++;
    final err = walletError;
    if (err != null) throw err;
    return walletResult;
  }

  @override
  Future<ClaimableResult> fetchClaimable({
    required String accessToken,
    required DateTime date,
    String? timezone,
  }) async {
    claimableFetches++;
    claimableDates.add(MealEntry.normalizeDate(date));
    return claimableResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingStepsRepository stepsRepo;
  late _CoinsApi coinsApi;
  late TrackerController tracker;
  late RewardsController rewards;
  late UserController user;

  DateTime todayDate() => MealEntry.normalizeDate(DateTime.now());

  Future<void> flushPosts() async {
    for (var i = 0; i < 40 && stepsRepo.syncCount == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
    await Get.deleteAll(force: true);
    HomeHydrate.debugReset();
    ApiClient.clearRateLimit();

    user = UserController(authRepository: _FakeAuthRepository());
    Get.put(user, permanent: true);
    await user.localProfileReady;

    stepsRepo = _CountingStepsRepository();
    tracker = TrackerController(stepsRepository: stepsRepo);
    Get.put(tracker, permanent: true);

    coinsApi = _CoinsApi();
    rewards = RewardsController(coinsApi: coinsApi);
    Get.put(rewards, permanent: true);
  });

  tearDown(() async {
    HomeHydrate.debugReset();
    ApiClient.clearRateLimit();
    await Get.deleteAll(force: true);
  });

  test('backend current => today GET only, zero POST, no yesterday GET',
      () async {
    final today = todayDate();
    final yesterday = today.subtract(const Duration(days: 1));
    tracker.stepsByDate[today] = 5000;
    stepsRepo.fetchResult = StepsFetchResult(
      stepsByDate: {today: 5000},
      caloriesByDate: {today: StepLogEntry.caloriesFromSteps(5000)},
    );

    await runCaloriesBurnBootstrap(tracker: tracker, rewards: rewards);
    await Future<void>.delayed(Duration.zero);

    expect(stepsRepo.fetchByDateCount, 1);
    expect(stepsRepo.fetchDates, [today]);
    expect(stepsRepo.fetchDates.contains(yesterday), isFalse);
    expect(stepsRepo.syncCount, 0);
  });

  test('local steps ahead => exactly one POST', () async {
    final today = todayDate();
    tracker.stepsByDate[today] = 8000;
    stepsRepo.fetchResult = StepsFetchResult(
      stepsByDate: {today: 1000},
      caloriesByDate: {today: StepLogEntry.caloriesFromSteps(1000)},
    );

    await runCaloriesBurnBootstrap(tracker: tracker, rewards: rewards);
    await flushPosts();

    expect(stepsRepo.fetchByDateCount, 1);
    expect(stepsRepo.syncCount, 1);
    expect(stepsRepo.postedStepValues.single, 8000);
  });

  test('todaySteps == 0 => zero POST', () async {
    final today = todayDate();
    tracker.stepsByDate.remove(today);
    stepsRepo.fetchResult = const StepsFetchResult();

    await runCaloriesBurnBootstrap(tracker: tracker, rewards: rewards);
    await Future<void>.delayed(Duration.zero);

    expect(stepsRepo.fetchByDateCount, 1);
    expect(stepsRepo.syncCount, 0);
  });

  test('wallet already completed successfully => no GET /coins', () async {
    await rewards.refreshWalletFromApi();
    expect(coinsApi.walletFetches, 1);
    expect(rewards.hasCompletedWalletFetch.value, isTrue);
    expect(rewards.walletApiErrorMessage.value, isNull);

    stepsRepo.fetchResult = const StepsFetchResult();
    await runCaloriesBurnBootstrap(tracker: tracker, rewards: rewards);

    expect(coinsApi.walletFetches, 1);
  });

  test('wallet incomplete => fetches wallet', () async {
    expect(rewards.hasCompletedWalletFetch.value, isFalse);
    stepsRepo.fetchResult = const StepsFetchResult();

    await runCaloriesBurnBootstrap(tracker: tracker, rewards: rewards);

    expect(coinsApi.walletFetches, 1);
    expect(rewards.hasCompletedWalletFetch.value, isTrue);
  });

  test('wallet previous error => retries GET /coins', () async {
    coinsApi.walletError = const CoinsApiException('fail', statusCode: 500);
    await rewards.refreshWalletFromApi();
    expect(rewards.hasCompletedWalletFetch.value, isTrue);
    expect(rewards.walletApiErrorMessage.value, isNotNull);
    expect(coinsApi.walletFetches, 1);

    coinsApi.walletError = null;
    stepsRepo.fetchResult = const StepsFetchResult();
    await runCaloriesBurnBootstrap(tracker: tracker, rewards: rewards);

    expect(coinsApi.walletFetches, 2);
    expect(rewards.walletApiErrorMessage.value, isNull);
  });

  test('claimable already loaded => no duplicate claimable GETs', () async {
    final today = todayDate();
    final yesterday = today.subtract(const Duration(days: 1));
    await rewards.refreshClaimableForDates([today, yesterday]);
    expect(coinsApi.claimableFetches, 2);

    stepsRepo.fetchResult = const StepsFetchResult();
    await runCaloriesBurnBootstrap(tracker: tracker, rewards: rewards);

    expect(coinsApi.claimableFetches, 2);
  });

  test('claimable missing => loads today and yesterday only', () async {
    stepsRepo.fetchResult = const StepsFetchResult();
    await runCaloriesBurnBootstrap(tracker: tracker, rewards: rewards);

    final today = todayDate();
    final yesterday = today.subtract(const Duration(days: 1));
    expect(coinsApi.claimableFetches, 2);
    expect(coinsApi.claimableDates.toSet(), {today, yesterday});
  });

  test('selected date still fetches required steps (no wallet refresh)',
      () async {
    await rewards.refreshWalletFromApi();
    final walletBefore = coinsApi.walletFetches;
    final past = todayDate().subtract(const Duration(days: 3));
    stepsRepo.fetchResult = StepsFetchResult(
      stepsByDate: {past: 2200},
      caloriesByDate: {past: StepLogEntry.caloriesFromSteps(2200)},
    );

    tracker.setSelectedStepsDate(past);
    for (var i = 0; i < 40 && stepsRepo.fetchByDateCount == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    await Future<void>.delayed(Duration.zero);

    expect(stepsRepo.fetchDates.last, past);
    expect(coinsApi.walletFetches, walletBefore);
  });

  test('concurrent same-day bootstrap GETs still join', () async {
    final today = todayDate();
    final gate = Completer<StepsFetchResult>();
    stepsRepo.fetchGate = gate;
    stepsRepo.fetchResult = StepsFetchResult(
      stepsByDate: {today: 1200},
      caloriesByDate: {today: StepLogEntry.caloriesFromSteps(1200)},
    );

    final a = runCaloriesBurnBootstrap(tracker: tracker, rewards: rewards);
    final b = runCaloriesBurnBootstrap(tracker: tracker, rewards: rewards);

    for (var i = 0; i < 40 && stepsRepo.fetchByDateCount == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(stepsRepo.fetchByDateCount, 1);

    gate.complete(stepsRepo.fetchResult);
    await Future.wait([a, b]);
    expect(stepsRepo.fetchByDateCount, 1);
    expect(stepsRepo.syncCount, 0);
  });

  test('open again does not force POST when backend already current', () async {
    final today = todayDate();
    tracker.stepsByDate[today] = 4000;
    stepsRepo.fetchResult = StepsFetchResult(
      stepsByDate: {today: 4000},
      caloriesByDate: {today: StepLogEntry.caloriesFromSteps(4000)},
    );

    await runCaloriesBurnBootstrap(tracker: tracker, rewards: rewards);
    await runCaloriesBurnBootstrap(tracker: tracker, rewards: rewards);
    await Future<void>.delayed(Duration.zero);

    expect(stepsRepo.fetchByDateCount, 2);
    expect(stepsRepo.syncCount, 0);
  });

  test('HomeHydrate step-sync behavior remains allowSyncPush=false', () async {
    final today = todayDate();
    tracker.stepsByDate[today] = 9000;
    stepsRepo.fetchResult = StepsFetchResult(
      stepsByDate: {today: 100},
      caloriesByDate: {today: 4},
    );

    await HomeHydrate.run(force: true);
    expect(stepsRepo.syncCount, 0);
  });
}
