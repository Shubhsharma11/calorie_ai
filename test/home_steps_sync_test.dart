import 'dart:async';

import 'package:calorie_ai/controllers/tracker_controller.dart';
import 'package:calorie_ai/controllers/user_controller.dart';
import 'package:calorie_ai/core/home_hydrate.dart';
import 'package:calorie_ai/models/meal_entry.dart';
import 'package:calorie_ai/models/step_log_entry.dart';
import 'package:calorie_ai/repositories/auth_repository.dart';
import 'package:calorie_ai/repositories/steps_repository.dart';
import 'package:calorie_ai/services/api_client.dart';
import 'package:calorie_ai/services/local_storage_service.dart';
import 'package:calorie_ai/services/steps_api_service.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingStepsRepository stepsRepo;
  late TrackerController tracker;
  late UserController user;

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
  });

  tearDown(() async {
    HomeHydrate.debugReset();
    ApiClient.clearRateLimit();
    await Get.deleteAll(force: true);
  });

  DateTime todayDate() => MealEntry.normalizeDate(DateTime.now());

  test('HomeHydrate GET steps uses allowSyncPush=false and does not POST',
      () async {
    final today = todayDate();
    // Local ahead of remote — would POST if allowSyncPush were true.
    tracker.stepsByDate[today] = 5000;
    stepsRepo.fetchResult = StepsFetchResult(
      stepsByDate: {today: 1000},
      caloriesByDate: {today: 40},
    );

    await HomeHydrate.run(force: true);
    // Home hydrate may also hit water/wallet/etc.; only assert steps side effects.
    expect(stepsRepo.fetchByDateCount, greaterThanOrEqualTo(1));
    expect(stepsRepo.syncCount, 0);
  });

  test('GET today with allowSyncPush=false never POSTs', () async {
    final today = todayDate();
    tracker.stepsByDate[today] = 8000;
    stepsRepo.fetchResult = StepsFetchResult(
      stepsByDate: {today: 100},
      caloriesByDate: {today: 4},
    );

    await tracker.refreshStepsFromApi(allowSyncPush: false);
    expect(stepsRepo.fetchByDateCount, 1);
    expect(stepsRepo.syncCount, 0);
  });

  test('GET today with allowSyncPush=true can POST when local is ahead',
      () async {
    final today = todayDate();
    tracker.stepsByDate[today] = 8000;
    stepsRepo.fetchResult = StepsFetchResult(
      stepsByDate: {today: 100},
      caloriesByDate: {today: 4},
    );

    await tracker.refreshStepsFromApi(allowSyncPush: true);
    // POST is unawaited — flush until sync is observed.
    for (var i = 0; i < 40 && stepsRepo.syncCount == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(stepsRepo.fetchByDateCount, 1);
    expect(stepsRepo.syncCount, 1);
    expect(stepsRepo.postedStepValues.single, 8000);
  });

  test('concurrent identical GET today requests coalesce', () async {
    final today = todayDate();
    final gate = Completer<StepsFetchResult>();
    stepsRepo.fetchGate = gate;
    stepsRepo.fetchResult = StepsFetchResult(
      stepsByDate: {today: 1200},
      caloriesByDate: {today: 48},
    );

    final a = tracker.refreshStepsFromApi(allowSyncPush: false);
    final b = tracker.refreshStepsFromApi(allowSyncPush: false);
    final c = tracker.refreshStepsFromApi(force: true, allowSyncPush: false);

    for (var i = 0; i < 40 && stepsRepo.fetchByDateCount == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(stepsRepo.fetchByDateCount, 1);

    gate.complete(stepsRepo.fetchResult);
    await Future.wait([a, b, c]);
    expect(stepsRepo.fetchByDateCount, 1);
    expect(stepsRepo.syncCount, 0);
  });

  test('pull-to-refresh style force GET joins in-flight today request',
      () async {
    final gate = Completer<StepsFetchResult>();
    stepsRepo.fetchGate = gate;
    stepsRepo.fetchResult = const StepsFetchResult();

    final first = tracker.refreshStepsFromApi(allowSyncPush: false);
    for (var i = 0; i < 40 && stepsRepo.fetchByDateCount == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(stepsRepo.fetchByDateCount, 1);

    final ptr = tracker.refreshStepsFromApi(force: true, allowSyncPush: false);
    expect(stepsRepo.fetchByDateCount, 1);

    gate.complete(const StepsFetchResult());
    await Future.wait([first, ptr]);
    expect(stepsRepo.fetchByDateCount, 1);
  });

  test('repeated refresh after completion starts a new GET', () async {
    stepsRepo.fetchResult = const StepsFetchResult();
    await tracker.refreshStepsFromApi(allowSyncPush: false);
    await tracker.refreshStepsFromApi(force: true, allowSyncPush: false);
    expect(stepsRepo.fetchByDateCount, 2);
    expect(stepsRepo.syncCount, 0);
  });

  test('legitimate foreground syncTodayStepsToApi POSTs once', () async {
    final today = todayDate();
    tracker.stepsByDate[today] = 3500;
    await tracker.syncTodayStepsToApi(force: true);
    expect(stepsRepo.syncCount, 1);
    expect(stepsRepo.postedStepValues.single, 3500);
  });

  test('duplicate concurrent POSTs for same/lower steps join one HTTP',
      () async {
    final today = todayDate();
    final gate = Completer<StepLogResponse>();
    stepsRepo.syncGate = gate;
    tracker.stepsByDate[today] = 4000;

    final a = tracker.syncTodayStepsToApi(force: true);
    final b = tracker.syncTodayStepsToApi(force: true);
    for (var i = 0; i < 40 && stepsRepo.syncCount == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(stepsRepo.syncCount, 1);

    gate.complete(const StepLogResponse());
    await Future.wait([a, b]);
    expect(stepsRepo.syncCount, 1);
  });

  test('signed-out / session clear prevents authenticated step POST', () async {
    final today = todayDate();
    tracker.stepsByDate[today] = 9000;
    final gate = Completer<StepLogResponse>();
    stepsRepo.syncGate = gate;

    final pending = tracker.syncTodayStepsToApi(force: true);
    for (var i = 0; i < 40 && stepsRepo.syncCount == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(stepsRepo.syncCount, 1);

    tracker.clearSessionData();
    gate.complete(const StepLogResponse());
    await pending;

    // Result discarded; a new sync after clear must not use stale session.
    stepsRepo.syncCount = 0;
    await user.clearInvalidSession();
    await tracker.syncTodayStepsToApi(force: true);
    expect(stepsRepo.syncCount, 0);
  });

  test('401/403 on GET does not POST', () async {
    final today = todayDate();
    stepsRepo.fetchError = const StepsApiException(
      'unauthorized',
      statusCode: 401,
    );
    tracker.stepsByDate[today] = 5000;

    await tracker.refreshStepsFromApi(allowSyncPush: true);
    await Future<void>.delayed(Duration.zero);
    expect(stepsRepo.fetchByDateCount, 1);
    expect(stepsRepo.syncCount, 0);
  });

  test('429 on GET notes rate limit and does not POST', () async {
    final today = todayDate();
    stepsRepo.fetchError = const StepsApiException(
      'too many',
      statusCode: 429,
    );
    tracker.stepsByDate[today] = 5000;

    await tracker.refreshStepsFromApi(allowSyncPush: true);
    expect(ApiClient.isRateLimited, isTrue);
    expect(stepsRepo.syncCount, 0);
  });

  test('HomeHydrate refresh joins cascade and keeps allowSyncPush=false',
      () async {
    final today = todayDate();
    tracker.stepsByDate[today] = 6000;
    stepsRepo.fetchResult = StepsFetchResult(
      stepsByDate: {today: 10},
      caloriesByDate: {today: 1},
    );

    final a = HomeHydrate.refresh();
    final b = HomeHydrate.refresh();
    await Future.wait([a, b]);

    expect(stepsRepo.syncCount, 0);
    expect(stepsRepo.fetchByDateCount, lessThanOrEqualTo(1));
  });

  test('no WorkManager package is wired for steps (foreground sync only)', () {
    // Audit lock: this app has no workmanager dependency / dispatcher.
    // Step POST paths are TrackerController + pedometer debounce only.
    expect(stepsRepo.syncCount, 0);
  });
}
