import 'dart:async';

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

  LogoutResult logoutResult = const LogoutResult(backendRevoked: true);
  Completer<void>? logoutGate;

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

  @override
  Future<LogoutResult> logout({
    String? refreshToken,
    String? accessToken,
  }) async {
    final gate = logoutGate;
    if (gate != null) await gate.future;
    await clearLocalAuthData();
    return logoutResult;
  }
}

/// Stand-in for LoginView without platform phone-hint channels.
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
    // Let MainController.settleShell's 200ms delay complete so no pending timer.
    await tester.pump(const Duration(milliseconds: 250));
    expect(Get.currentRoute, AppRoutes.main);
    expect(find.byKey(const Key('authed-main')), findsOneWidget);
    expect(user.isLoggedIn, isTrue);
  }

  Future<void> pumpAfterLogout(WidgetTester tester) async {
    // Zero-duration offAll + post-frame dispose + snackbar.
    await tester.pump();
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
      await tester.pump();
    }
  }

  testWidgets('successful logout removes Main and shows login', (tester) async {
    await pumpAuthedShell(tester);
    final genBefore = HomeHydrate.debugGeneration;

    await user.performLogout();
    await pumpAfterLogout(tester);

    expect(user.isLoggedIn, isFalse);
    expect(user.accessToken, isEmpty);
    expect(Get.currentRoute, AppRoutes.login);
    expect(find.byKey(const Key('signed-out-login')), findsOneWidget);
    expect(find.byKey(const Key('authed-main')), findsNothing);
    expect(Get.isRegistered<MainController>(), isFalse);
    expect(HomeHydrate.debugGeneration, greaterThan(genBefore));
  });

  testWidgets('Back after logout does not return to Main', (tester) async {
    await pumpAuthedShell(tester);
    await user.performLogout();
    await pumpAfterLogout(tester);
    expect(Get.currentRoute, AppRoutes.login);

    expect(Get.key.currentState?.canPop() ?? false, isFalse);

    Get.back();
    await pumpAfterLogout(tester);

    expect(Get.currentRoute, AppRoutes.login);
    expect(find.byKey(const Key('authed-main')), findsNothing);
    expect(find.byKey(const Key('signed-out-login')), findsOneWidget);
  });

  testWidgets('Back after logout does not return to Profile', (tester) async {
    await pumpAuthedShell(tester);
    Get.find<MainController>().changeTab(MainController.profileTabIndex);
    await tester.pump();

    await user.performLogout();
    await pumpAfterLogout(tester);

    Get.back();
    await pumpAfterLogout(tester);

    expect(Get.currentRoute, AppRoutes.login);
    expect(find.byKey(const Key('authed-main')), findsNothing);
    expect(Get.isRegistered<MainController>(), isFalse);
  });

  testWidgets('signed-out login PopScope blocks pop', (tester) async {
    await pumpAuthedShell(tester);
    await user.performLogout();
    await pumpAfterLogout(tester);

    expect(find.byKey(const Key('signed-out-login')), findsOneWidget);
    expect(Get.key.currentState?.canPop() ?? false, isFalse);
  });

  testWidgets('logout clears shell controllers and HomeHydrate', (tester) async {
    await pumpAuthedShell(tester);

    await user.performLogout();
    await pumpAfterLogout(tester);

    expect(Get.isRegistered<MainController>(), isFalse);
    expect(Get.isRegistered<FoodController>(), isFalse);
    expect(Get.isRegistered<RewardsController>(), isFalse);
    expect(HomeHydrate.debugInFlight, isNull);
  });

  testWidgets('MainController does not hydrate Home after logout',
      (tester) async {
    await pumpAuthedShell(tester);

    await user.performLogout();
    await pumpAfterLogout(tester);
    expect(Get.isRegistered<MainController>(), isFalse);

    var hydrateRuns = 0;
    HomeHydrate.debugRunOverride = (_) async {
      hydrateRuns++;
    };

    // Re-creating Main while signed out must not hydrate.
    Get.put(MainController(), permanent: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(user.isLoggedIn, isFalse);
    expect(hydrateRuns, 0);

    SignedOutNavigation.disposeAuthenticatedShellControllers();
    await tester.pump();
  });

  testWidgets('logout while HomeHydrate in flight does not restore Main',
      (tester) async {
    await pumpAuthedShell(tester);

    final release = Completer<void>();
    HomeHydrate.debugRunOverride = (_) => release.future;
    final hydrate = HomeHydrate.run(force: true);
    await tester.pump();
    expect(HomeHydrate.debugInFlight, isNotNull);

    await user.performLogout();
    await pumpAfterLogout(tester);

    release.complete();
    await hydrate;
    await pumpAfterLogout(tester);

    expect(Get.currentRoute, AppRoutes.login);
    expect(find.byKey(const Key('authed-main')), findsNothing);
    expect(user.isLoggedIn, isFalse);
  });

  testWidgets('backend logout error still clears local session and stack',
      (tester) async {
    await pumpAuthedShell(tester);
    auth.logoutResult = const LogoutResult(
      backendRevoked: false,
      errorMessage: 'network down',
    );

    await user.performLogout();
    await pumpAfterLogout(tester);

    expect(user.isLoggedIn, isFalse);
    expect(Get.currentRoute, AppRoutes.login);
    expect(find.byKey(const Key('authed-main')), findsNothing);
  });

  test('SignedOutNavigation.dispose removes MainController', () {
    Get.put(MainController(), permanent: true);
    expect(Get.isRegistered<MainController>(), isTrue);
    SignedOutNavigation.disposeAuthenticatedShellControllers();
    expect(Get.isRegistered<MainController>(), isFalse);
  });

  testWidgets('re-login can register MainController again', (tester) async {
    await pumpAuthedShell(tester);
    await user.performLogout();
    await pumpAfterLogout(tester);
    expect(Get.isRegistered<MainController>(), isFalse);

    // Restore a session as a successful re-login would.
    await auth.saveSession(
      userId: 'u1',
      provider: 'google',
      email: 'a@b.com',
      name: 'Test',
      accessToken: 'test-access-token-yyyyyy',
      refreshToken: 'test-refresh',
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
