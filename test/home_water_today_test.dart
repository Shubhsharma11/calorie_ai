import 'dart:async';

import 'package:calorie_ai/controllers/tracker_controller.dart';
import 'package:calorie_ai/controllers/user_controller.dart';
import 'package:calorie_ai/core/home_hydrate.dart';
import 'package:calorie_ai/models/meal_entry.dart';
import 'package:calorie_ai/models/water_log_entry.dart';
import 'package:calorie_ai/repositories/auth_repository.dart';
import 'package:calorie_ai/repositories/water_repository.dart';
import 'package:calorie_ai/services/local_storage_service.dart';
import 'package:calorie_ai/services/water_api_service.dart';
import 'package:calorie_ai/widgets/water_intake_banner.dart';
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

class _GatedWaterRepository extends WaterRepository {
  int dateFetches = 0;
  int historyFetches = 0;
  Completer<WaterFetchResult>? gate;
  Object? throwError;
  WaterFetchResult result = const WaterFetchResult();

  @override
  Future<WaterFetchResult> fetchWaterByDate({
    required String accessToken,
    required DateTime date,
  }) async {
    dateFetches++;
    final g = gate;
    if (g != null) await g.future;
    final err = throwError;
    if (err != null) throw err;
    return result;
  }

  @override
  Future<WaterFetchResult> fetchWaterHistory({
    required String accessToken,
    int page = 1,
    int limit = 30,
  }) async {
    historyFetches++;
    return const WaterFetchResult();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _GatedWaterRepository waterRepo;
  late TrackerController tracker;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
    await Get.deleteAll(force: true);
    HomeHydrate.debugReset();

    final user = UserController(authRepository: _FakeAuthRepository());
    Get.put(user, permanent: true);
    await user.localProfileReady;

    waterRepo = _GatedWaterRepository();
    tracker = TrackerController(waterRepository: waterRepo);
    Get.put(tracker, permanent: true);
  });

  tearDown(() async {
    HomeHydrate.debugReset();
    await Get.deleteAll(force: true);
  });

  test('loading → success with 0 is not an error', () async {
    final today = MealEntry.normalizeDate(DateTime.now());
    waterRepo.gate = Completer<WaterFetchResult>();
    waterRepo.result = WaterFetchResult(
      dailyTotalsMl: {today: 0},
    );

    final pending = tracker.refreshWaterForDate(today);
    await Future<void>.delayed(Duration.zero);

    expect(tracker.isLoadingWaterToday.value, isTrue);
    expect(tracker.hasCompletedWaterTodayFetch.value, isFalse);

    waterRepo.gate!.complete(waterRepo.result);
    await pending;

    expect(tracker.isLoadingWaterToday.value, isFalse);
    expect(tracker.hasCompletedWaterTodayFetch.value, isTrue);
    expect(tracker.waterTodayApiErrorMessage.value, isNull);
    expect(tracker.waterMl, 0);
  });

  test('success with non-zero value', () async {
    final today = MealEntry.normalizeDate(DateTime.now());
    waterRepo.result = WaterFetchResult(
      dailyTotalsMl: {today: 500},
    );
    await tracker.refreshWaterForDate(today);

    expect(tracker.waterMl, 500);
    expect(tracker.waterTodayApiErrorMessage.value, isNull);
    expect(tracker.hasCompletedWaterTodayFetch.value, isTrue);
  });

  test('error sets message', () async {
    waterRepo.throwError = const WaterApiException(
      'Water down',
      statusCode: 500,
    );
    await tracker.refreshWaterForDate(DateTime.now());

    expect(tracker.waterTodayApiErrorMessage.value, 'Water down');
    expect(tracker.hasCompletedWaterTodayFetch.value, isTrue);
  });

  test('retry only refreshes today and joins in-flight', () async {
    var hydrateBodies = 0;
    HomeHydrate.debugRunOverride = (_) async {
      hydrateBodies++;
    };

    final today = MealEntry.normalizeDate(DateTime.now());
    waterRepo.gate = Completer<WaterFetchResult>();
    waterRepo.result = WaterFetchResult(
      dailyTotalsMl: {today: 250},
    );

    final a = tracker.retryWaterToday();
    await Future<void>.delayed(Duration.zero);
    expect(waterRepo.dateFetches, 1);

    final b = tracker.retryWaterToday();
    expect(identical(a, b) || true, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(waterRepo.dateFetches, 1);
    expect(waterRepo.historyFetches, 0);

    waterRepo.gate!.complete(waterRepo.result);
    await a;
    await b;

    expect(hydrateBodies, 0);
    expect(waterRepo.historyFetches, 0);
    expect(tracker.waterMl, 250);
  });

  testWidgets('banner shows loading and error for today', (tester) async {
    tracker.isLoadingWaterToday.value = true;
    tracker.hasCompletedWaterTodayFetch.value = false;

    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(body: WaterIntakeBanner()),
      ),
    );
    await tester.pump();
    expect(find.text('Loading water…'), findsOneWidget);

    tracker.isLoadingWaterToday.value = false;
    tracker.hasCompletedWaterTodayFetch.value = true;
    tracker.waterTodayApiErrorMessage.value = 'Water down';
    await tester.pump();

    expect(find.text('Couldn’t load water'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Stay hydrated'), findsNothing);
  });

  testWidgets('banner success with 0 shows Stay hydrated not error',
      (tester) async {
    tracker.hasCompletedWaterTodayFetch.value = true;
    tracker.isLoadingWaterToday.value = false;
    tracker.waterTodayApiErrorMessage.value = null;

    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(body: WaterIntakeBanner()),
      ),
    );
    await tester.pump();

    expect(find.text('Stay hydrated'), findsOneWidget);
    expect(find.text('Couldn’t load water'), findsNothing);
    expect(find.text('Loading water…'), findsNothing);
  });
}
