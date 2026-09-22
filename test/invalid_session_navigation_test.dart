import 'package:calorie_ai/controllers/auth_controller.dart';
import 'package:calorie_ai/controllers/food_controller.dart';
import 'package:calorie_ai/controllers/main_controller.dart';
import 'package:calorie_ai/controllers/rewards_controller.dart';
import 'package:calorie_ai/controllers/user_controller.dart';
import 'package:calorie_ai/core/home_hydrate.dart';
import 'package:calorie_ai/core/signed_out_navigation.dart';
import 'package:calorie_ai/models/logout_result.dart';
import 'package:calorie_ai/repositories/auth_repository.dart';
import 'package:calorie_ai/routes/app_routes.dart';
import 'package:calorie_ai/services/local_storage_service.dart';
import 'package:flutter/material.dart';
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

  int clearCalls = 0;

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
    clearCalls++;
    disk = {};
  }

  @override
  Future<LogoutResult> logout({
    String? refreshToken,
    String? accessToken,
  }) async {
    await clearLocalAuthData();
    return const LogoutResult(backendRevoked: true);
  }
}

class _SignedOutLoginStub extends StatelessWidget {
  const _SignedOutLoginStub();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {},
      child: const Scaffold(
        key: Key('signed-out-login'),
        body: Text('LOGIN'),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAuthRepository auth;
  late UserController user;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    Get.testMode = true;
    HomeHydrate.debugReset();

    auth = _FakeAuthRepository();
    user = UserController(authRepository: auth);
    Get.put(user, permanent: true);
    await user.localProfileReady;
  });

  tearDown(() async {
    HomeHydrate.debugReset();
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }
    Get.reset();
  });

  Future<void> pumpAuthedShell(WidgetTester tester) async {
    // Prevent settleShell from starting a real network hydrate in widget tests.
    HomeHydrate.debugRunOverride = (_) async {};

    Get.put(MainController(), permanent: true);
    Get.put(FoodController(), permanent: true);
    Get.put(RewardsController(), permanent: true);

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.main,
        getPages: [
          GetPage(
            name: AppRoutes.main,
            page: () => const Scaffold(
              key: Key('authed-main'),
              body: Text('AUTHED_MAIN'),
            ),
          ),
          GetPage(
            name: AppRoutes.login,
            page: () => const _SignedOutLoginStub(),
            binding: BindingsBuilder(() {
              if (!Get.isRegistered<AuthController>()) {
                Get.lazyPut(AuthController.new);
              }
            }),
            popGesture: false,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(Get.currentRoute, AppRoutes.main);
    expect(user.isLoggedIn, isTrue);
  }

  Future<void> pumpAfterNav(WidgetTester tester) async {
    await tester.pump();
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
      await tester.pump();
    }
  }

  testWidgets(
    '401 Invalid or expired access token clears session and leaves Main',
    (tester) async {
      await pumpAuthedShell(tester);
      final genBefore = HomeHydrate.debugGeneration;

      await user.clearInvalidSession(
        debugController: 'test',
        debugEndpoint: 'GET /onboarding',
        debugStatusCode: 401,
        debugRequestType: 'GET',
      );
      await pumpAfterNav(tester);

      expect(user.isLoggedIn, isFalse);
      expect(user.accessToken, isEmpty);
      expect(auth.disk, isEmpty);
      expect(auth.clearCalls, 1);
      expect(HomeHydrate.debugGeneration, greaterThan(genBefore));
      expect(Get.currentRoute, AppRoutes.login);
      expect(find.byKey(const Key('signed-out-login')), findsOneWidget);
      expect(find.byKey(const Key('authed-main')), findsNothing);
      expect(Get.isRegistered<MainController>(), isFalse);
    },
  );

  testWidgets('403 also clears session and navigates to Login', (tester) async {
    await pumpAuthedShell(tester);

    await user.clearInvalidSession(debugStatusCode: 403);
    await pumpAfterNav(tester);

    expect(user.isLoggedIn, isFalse);
    expect(Get.currentRoute, AppRoutes.login);
    expect(find.byKey(const Key('authed-main')), findsNothing);
  });

  testWidgets('Back after invalid session cannot return to Home',
      (tester) async {
    await pumpAuthedShell(tester);
    await user.clearInvalidSession(debugStatusCode: 401);
    await pumpAfterNav(tester);

    expect(Get.key.currentState?.canPop() ?? false, isFalse);
    Get.back();
    await pumpAfterNav(tester);

    expect(Get.currentRoute, AppRoutes.login);
    expect(find.byKey(const Key('authed-main')), findsNothing);
  });

  testWidgets('concurrent 401 clears navigate only once', (tester) async {
    await pumpAuthedShell(tester);

    await Future.wait([
      user.clearInvalidSession(debugStatusCode: 401),
      user.clearInvalidSession(debugStatusCode: 401),
      user.clearInvalidSession(debugStatusCode: 403),
    ]);
    await pumpAfterNav(tester);

    expect(auth.clearCalls, 1);
    expect(Get.currentRoute, AppRoutes.login);
    expect(find.byKey(const Key('signed-out-login')), findsOneWidget);
  });

  test('without navigator, 401 still clears session (cold start)', () async {
    expect(Get.key.currentState, isNull);
    await user.clearInvalidSession(debugStatusCode: 401);

    expect(user.isLoggedIn, isFalse);
    expect(user.accessToken, isEmpty);
    expect(auth.disk, isEmpty);
    expect(auth.clearCalls, 1);
  });

  test('normal resource 404 does not call clearInvalidSession', () async {
    // Controllers only clear on 401/403 — a lone 404 must not wipe the session.
    expect(user.isLoggedIn, isTrue);
    // Simulate what NutritionPlan does for missing plan: leave session alone.
    expect(user.accessToken, isNotEmpty);
    expect(auth.disk.isNotEmpty, isTrue);
  });

  testWidgets('manual Logout still works after invalid-session path exists',
      (tester) async {
    await pumpAuthedShell(tester);
    await user.performLogout();
    await pumpAfterNav(tester);

    expect(Get.currentRoute, AppRoutes.login);
    expect(user.isLoggedIn, isFalse);
  });

  testWidgets('re-login after invalid session can open Main again',
      (tester) async {
    await pumpAuthedShell(tester);
    await user.clearInvalidSession(debugStatusCode: 401);
    await pumpAfterNav(tester);
    expect(Get.isRegistered<MainController>(), isFalse);

    await auth.saveSession(
      userId: 'u2',
      provider: 'google',
      email: 'new@b.com',
      name: 'New',
      accessToken: 'test-access-token-yyyyyy',
      refreshToken: 'refresh-2',
      backendResponse: const {},
      setupComplete: true,
    );
    await user.loadAuthSession();
    expect(user.isLoggedIn, isTrue);

    Get.put(MainController(), permanent: true);
    Get.offAll(
      () => const Scaffold(
        key: Key('authed-main'),
        body: Text('AUTHED_MAIN'),
      ),
      routeName: AppRoutes.main,
      transition: Transition.noTransition,
      duration: Duration.zero,
      predicate: (_) => false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(Get.currentRoute, AppRoutes.main);
    expect(find.byKey(const Key('authed-main')), findsOneWidget);

    SignedOutNavigation.disposeAuthenticatedShellControllers();
    await tester.pump();
  });
}
