import 'dart:async';

import 'package:calorie_ai/controllers/user_controller.dart';
import 'package:calorie_ai/models/onboarding_response_model.dart';
import 'package:calorie_ai/repositories/auth_repository.dart';
import 'package:calorie_ai/repositories/onboarding_repository.dart';
import 'package:calorie_ai/services/api_client.dart';
import 'package:calorie_ai/services/local_storage_service.dart';
import 'package:calorie_ai/services/onboarding_api_service.dart';
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

class _CountingOnboardingRepo extends OnboardingRepository {
  int fetchCount = 0;
  Completer<OnboardingResponseModel>? gate;
  Object? throwError;
  OnboardingResponseModel response = const OnboardingResponseModel(
    message: 'ok',
    raw: {
      'name': 'Test',
      'email': 'a@b.com',
      'weightKg': 70,
      'heightCm': 170,
      'goal': 'maintainWeight',
      'activityLevel': 'moderate',
      'dailyCalorieGoal': 2000,
    },
  );

  @override
  Future<OnboardingResponseModel> fetchOnboarding({
    required String accessToken,
  }) async {
    fetchCount++;
    final g = gate;
    if (g != null) await g.future;
    final err = throwError;
    if (err != null) {
      if (err is OnboardingApiException) throw err;
      throw err;
    }
    return response;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingOnboardingRepo onboarding;
  late UserController user;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
    await Get.deleteAll(force: true);
    ApiClient.clearRateLimit();

    onboarding = _CountingOnboardingRepo();
    user = UserController(
      authRepository: _FakeAuthRepository(),
      onboardingRepository: onboarding,
    );
    Get.put(user, permanent: true);
    await user.localProfileReady;
  });

  tearDown(() async {
    ApiClient.clearRateLimit();
    await Get.deleteAll(force: true);
  });

  test('successful profile fetch is a single repository call', () async {
    final err = await user.fetchProfile(force: true);
    expect(err, isNull);
    expect(onboarding.fetchCount, 1);
    expect(user.lastProfileFetchStatusCode, 200);
    expect(user.isLoadingProfile, isFalse);
  });

  test('502/503 do not get an extra UserController retry layer', () async {
    onboarding.throwError = const OnboardingApiException(
      'bad gateway',
      statusCode: 502,
    );
    final err = await user.fetchProfile(force: true);
    expect(err, isNotNull);
    // Repository is invoked once; ApiClient would already have retried inside
    // a real OnboardingApiService GET. This counting repo proves no outer loop.
    expect(onboarding.fetchCount, 1);
    expect(user.lastProfileFetchStatusCode, 502);
  });

  test('503 is a single logical call (same as 502)', () async {
    onboarding.throwError = const OnboardingApiException(
      'unavailable',
      statusCode: 503,
    );
    await user.fetchProfile(force: true);
    expect(onboarding.fetchCount, 1);
    expect(user.lastProfileFetchStatusCode, 503);
  });

  test('401 clears invalid session without a second profile attempt', () async {
    expect(user.isLoggedIn, isTrue);
    onboarding.throwError = const OnboardingApiException(
      'unauthorized',
      statusCode: 401,
    );
    final err = await user.fetchProfile(force: true);
    expect(err, isNotNull);
    expect(onboarding.fetchCount, 1);
    // clearInvalidSession wipes lastProfileFetchStatusCode by design.
    expect(user.isLoggedIn, isFalse);
    expect(user.accessToken, isEmpty);
  });

  test('403 clears invalid session without a second profile attempt', () async {
    onboarding.throwError = const OnboardingApiException(
      'forbidden',
      statusCode: 403,
    );
    final err = await user.fetchProfile(force: true);
    expect(err, isNotNull);
    expect(onboarding.fetchCount, 1);
    expect(user.isLoggedIn, isFalse);
    expect(user.accessToken, isEmpty);
  });

  test('429 sets cooldown and is not retried by UserController', () async {
    onboarding.throwError = const OnboardingApiException(
      'too many',
      statusCode: 429,
    );
    final err = await user.fetchProfile(force: true);
    expect(err, isNotNull);
    expect(onboarding.fetchCount, 1);
    expect(user.lastProfileFetchStatusCode, 429);
    expect(ApiClient.isRateLimited, isTrue);

    // Second call skips while cooling down (even force) — no extra GET.
    await user.fetchProfile(force: true);
    expect(onboarding.fetchCount, 1);
    expect(user.lastProfileFetchStatusCode, 429);
  });

  test('concurrent fetchProfile calls coalesce into one repository call',
      () async {
    onboarding.gate = Completer<OnboardingResponseModel>();
    final a = user.fetchProfile(force: true);
    final b = user.fetchProfile(force: true);
    await Future<void>.delayed(Duration.zero);
    expect(onboarding.fetchCount, 1);

    onboarding.gate!.complete(onboarding.response);
    final results = await Future.wait([a, b]);
    expect(results.every((e) => e == null), isTrue);
    expect(onboarding.fetchCount, 1);
  });
}
