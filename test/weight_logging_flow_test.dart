import 'dart:convert';

import 'package:calorie_ai/controllers/tracker_controller.dart';
import 'package:calorie_ai/controllers/user_controller.dart';
import 'package:calorie_ai/models/meal_entry.dart';
import 'package:calorie_ai/models/weight_entry.dart';
import 'package:calorie_ai/repositories/auth_repository.dart';
import 'package:calorie_ai/repositories/weight_repository.dart';
import 'package:calorie_ai/services/api_client.dart';
import 'package:calorie_ai/services/weight_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(this._session);

  final Map<String, dynamic> _session;

  @override
  Future<Map<String, dynamic>> loadSession() async => _session;
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
    Get.reset();
  });

  tearDown(Get.reset);

  test('resolveAccessTokenWithDiagnostics returns session token after login', () async {
    final controller = UserController(
      authRepository: _FakeAuthRepository({
        'userId': 'user-1',
        'provider': 'google',
        'email': 'user@example.com',
        'name': 'User',
        'accessToken': 'google-session-access-token',
        'refreshToken': 'refresh-token',
        'backendResponse': {'success': true},
      }),
    );

    await controller.localProfileReady;
    final resolution = await controller.resolveAccessTokenWithDiagnostics();

    expect(resolution.isResolved, isTrue);
    expect(resolution.source, 'session');
    expect(resolution.tokenLength, 'google-session-access-token'.length);
    expect(resolution.failureStage, isNull);
  });

  test('resolveAccessTokenWithDiagnostics hydrates nested backend token', () async {
    final controller = UserController(
      authRepository: _FakeAuthRepository({
        'userId': 'user-1',
        'provider': 'google',
        'email': 'user@example.com',
        'name': 'User',
        'accessToken': '',
        'refreshToken': '',
        'backendResponse': {
          'success': true,
          'data': {
            'tokens': {
              'accessToken': 'nested-google-access-token',
            },
          },
        },
      }),
    );

    await controller.localProfileReady;
    final resolution = await controller.resolveAccessTokenWithDiagnostics();

    expect(resolution.isResolved, isTrue);
    expect(resolution.source, 'session');
    expect(resolution.tokenLength, 'nested-google-access-token'.length);
    expect(controller.accessToken, 'nested-google-access-token');
  });

  test('resolveAccessTokenWithDiagnostics reports storage failure', () async {
    final controller = UserController(
      authRepository: _FakeAuthRepository({}),
    );

    await controller.localProfileReady;
    final resolution = await controller.resolveAccessTokenWithDiagnostics();

    expect(resolution.isResolved, isFalse);
    expect(resolution.failureStage, 'storage');
    expect(
      resolution.failureLocation,
      contains('user_controller.dart loadAuthSession'),
    );
  });

  test('logCurrentWeight posts, parses 201, and refreshes chart state', () async {
    var postCount = 0;
    var getCount = 0;

    final client = MockClient((request) async {
      if (request.method == 'POST') {
        postCount++;
        expect(request.headers['Authorization'], startsWith('Bearer '));
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'weightEntry': {
                'id': 'w-1',
                'weightKg': 68,
                'recordedAt': '2026-06-29T12:00:00.000Z',
              },
              'profileUpdated': true,
            },
          }),
          201,
        );
      }

      getCount++;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'entries': [
              {
                'id': 'w-1',
                'weightKg': 68,
                'recordedAt': '2026-06-29T12:00:00.000Z',
              },
            ],
          },
        }),
        200,
      );
    });

    final userController = UserController(
      authRepository: _FakeAuthRepository({
        'userId': 'user-1',
        'provider': 'google',
        'email': 'user@example.com',
        'name': 'User',
        'accessToken': 'valid-bearer-token',
        'refreshToken': 'refresh-token',
        'backendResponse': {'success': true},
      }),
    );
    Get.put(userController, permanent: true);
    await userController.localProfileReady;

    final weightRepository = WeightRepository(
      apiService: WeightApiService(apiClient: ApiClient(client: client)),
    );
    final tracker = TrackerController(
      weightRepository: weightRepository,
    );

    final outcome = await tracker.logCurrentWeight(
      date: DateTime(2026, 6, 29),
      weightKg: 68,
    );

    expect(postCount, 1);
    expect(getCount, 1);
    expect(outcome.status, WeightLogStatus.savedAndSynced);
    expect(tracker.currentWeight.value, 68);
    expect(tracker.weightEntries, hasLength(1));
    expect(tracker.weightEntries.first.kg, 68);
    expect(tracker.weightRevision.value, greaterThan(0));
  });

  test('logCurrentWeight keeps saved weight when GET history is stale', () async {
    var postCount = 0;
    var getCount = 0;
    final today = MealEntry.normalizeDate(DateTime.now());

    final client = MockClient((request) async {
      if (request.method == 'POST') {
        postCount++;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'weightEntry': {
                'id': 'w-new',
                'weightKg': 72.5,
                'recordedAt': MealEntry.dateToKey(today),
              },
            },
          }),
          201,
        );
      }

      getCount++;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'entries': [
              {
                'id': 'w-old',
                'weightKg': 80,
                'recordedAt': MealEntry.dateToKey(
                  today.subtract(const Duration(days: 14)),
                ),
              },
            ],
          },
        }),
        200,
      );
    });

    final userController = UserController(
      authRepository: _FakeAuthRepository({
        'userId': 'user-1',
        'provider': 'google',
        'email': 'user@example.com',
        'name': 'User',
        'accessToken': 'valid-bearer-token',
        'refreshToken': 'refresh-token',
        'backendResponse': {'success': true},
      }),
    );
    Get.put(userController, permanent: true);
    await userController.localProfileReady;

    final tracker = TrackerController(
      weightRepository: WeightRepository(
        apiService: WeightApiService(apiClient: ApiClient(client: client)),
      ),
    );

    final outcome = await tracker.logCurrentWeight(
      date: today,
      weightKg: 72.5,
    );

    expect(postCount, 1);
    expect(getCount, 1);
    expect(outcome.status, WeightLogStatus.savedAndSynced);
    expect(tracker.currentWeight.value, 72.5);
    expect(tracker.weightEntries, hasLength(2));
    expect(
      tracker.weightEntries
          .where((entry) => MealEntry.normalizeDate(entry.date) == today)
          .single
          .kg,
      72.5,
    );
  });

  test('refreshWeightFromApi syncs profile weight after login-style fetch', () async {
    final today = MealEntry.normalizeDate(DateTime.now());

    final client = MockClient((request) async {
      expect(request.method, 'GET');
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'entries': [
              {
                'id': 'w-1',
                'weightKg': 81.2,
                'recordedAt': MealEntry.dateToKey(today),
              },
            ],
          },
        }),
        200,
      );
    });

    final userController = UserController(
      authRepository: _FakeAuthRepository({
        'userId': 'user-1',
        'provider': 'google',
        'email': 'user@example.com',
        'name': 'User',
        'accessToken': 'valid-bearer-token',
        'refreshToken': 'refresh-token',
        'backendResponse': {'success': true},
      }),
    );
    Get.put(userController, permanent: true);
    await userController.localProfileReady;
    expect(userController.user.weightKg, 70);

    final tracker = TrackerController(
      weightRepository: WeightRepository(
        apiService: WeightApiService(apiClient: ApiClient(client: client)),
      ),
    );

    await tracker.refreshWeightFromApi();

    expect(tracker.currentWeight.value, 81.2);
    expect(userController.user.weightKg, 81);
    expect(tracker.weightRevision.value, greaterThan(0));
  });

  test('deleteWeightEntry removes entry via DELETE and refreshes history', () async {
    final today = MealEntry.normalizeDate(DateTime.now());
    var deleteCount = 0;
    var getCount = 0;

    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        deleteCount++;
        expect(request.url.path, endsWith('/w-1'));
        return http.Response(jsonEncode({'success': true}), 200);
      }

      getCount++;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'entries': [
              {
                'id': 'w-old',
                'weightKg': 79,
                'recordedAt': MealEntry.dateToKey(
                  today.subtract(const Duration(days: 7)),
                ),
              },
            ],
          },
        }),
        200,
      );
    });

    final userController = UserController(
      authRepository: _FakeAuthRepository({
        'userId': 'user-1',
        'provider': 'google',
        'email': 'user@example.com',
        'name': 'User',
        'accessToken': 'valid-bearer-token',
        'refreshToken': 'refresh-token',
        'backendResponse': {'success': true},
      }),
    );
    Get.put(userController, permanent: true);
    await userController.localProfileReady;

    final tracker = TrackerController(
      weightRepository: WeightRepository(
        apiService: WeightApiService(apiClient: ApiClient(client: client)),
      ),
    );

    tracker.weightEntries.assignAll([
      WeightEntry(id: 'w-1', date: today, kg: 82),
      WeightEntry(
        id: 'w-old',
        date: today.subtract(const Duration(days: 7)),
        kg: 79,
      ),
    ]);
    tracker.currentWeight.value = 82;

    final outcome = await tracker.deleteWeightEntry(
      WeightEntry(id: 'w-1', date: today, kg: 82),
    );

    expect(deleteCount, 1);
    expect(getCount, 1);
    expect(outcome.status, WeightDeleteStatus.deleted);
    expect(tracker.weightEntries, hasLength(1));
    expect(tracker.weightEntries.single.id, 'w-old');
    expect(tracker.currentWeight.value, 79);
  });
}
