import 'dart:async';

import 'package:calorie_ai/controllers/rewards_controller.dart';
import 'package:calorie_ai/controllers/user_controller.dart';
import 'package:calorie_ai/core/home_hydrate.dart';
import 'package:calorie_ai/models/claimable_result.dart';
import 'package:calorie_ai/models/meal_entry.dart';
import 'package:calorie_ai/repositories/auth_repository.dart';
import 'package:calorie_ai/services/api_client.dart';
import 'package:calorie_ai/services/coins_api_service.dart';
import 'package:calorie_ai/services/local_storage_service.dart';
import 'package:calorie_ai/widgets/steps_claim_banner.dart';
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

class _GatedCoinsApi extends CoinsApiService {
  int walletFetches = 0;
  int claimableFetches = 0;
  Completer<void>? walletGate;
  Completer<void>? claimableGate;
  Object? walletError;
  Object? claimableError;
  CoinsWalletResult walletResult = const CoinsWalletResult(balance: 42);
  ClaimableResult claimableResult = const ClaimableResult(
    claimableCoins: 10,
    canClaim: true,
  );
  final List<DateTime> claimableDates = [];

  @override
  Future<CoinsWalletResult> fetchWallet({required String accessToken}) async {
    walletFetches++;
    final g = walletGate;
    if (g != null) await g.future;
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
    final g = claimableGate;
    if (g != null) await g.future;
    final err = claimableError;
    if (err != null) throw err;
    return claimableResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _GatedCoinsApi coins;
  late RewardsController rewards;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
    await Get.deleteAll(force: true);
    HomeHydrate.debugReset();
    ApiClient.clearRateLimit();

    final user = UserController(authRepository: _FakeAuthRepository());
    Get.put(user, permanent: true);
    await user.localProfileReady;

    coins = _GatedCoinsApi();
    rewards = RewardsController(coinsApi: coins);
    Get.put(rewards, permanent: true);
    await rewards.load();
  });

  tearDown(() async {
    HomeHydrate.debugReset();
    ApiClient.clearRateLimit();
    await Get.deleteAll(force: true);
  });

  group('wallet', () {
    test('loading → success', () async {
      coins.walletGate = Completer<void>();
      coins.walletResult = const CoinsWalletResult(balance: 77);
      final pending = rewards.refreshWalletFromApi();
      await Future<void>.delayed(Duration.zero);

      expect(rewards.isLoadingWallet.value, isTrue);
      expect(rewards.hasCompletedWalletFetch.value, isFalse);

      coins.walletGate!.complete();
      await pending;

      expect(rewards.isLoadingWallet.value, isFalse);
      expect(rewards.hasCompletedWalletFetch.value, isTrue);
      expect(rewards.balance.value, 77);
      expect(rewards.walletApiErrorMessage.value, isNull);
    });

    test('error sets message without Home cascade', () async {
      var hydrateBodies = 0;
      HomeHydrate.debugRunOverride = (_) async {
        hydrateBodies++;
      };

      coins.walletError = const CoinsApiException(
        'Wallet down',
        statusCode: 500,
      );
      await rewards.refreshWalletFromApi();

      expect(rewards.walletApiErrorMessage.value, 'Wallet down');
      expect(rewards.hasCompletedWalletFetch.value, isTrue);
      expect(hydrateBodies, 0);
    });

    test('retry joins in-flight and does not duplicate GET', () async {
      coins.walletGate = Completer<void>();
      coins.walletResult = const CoinsWalletResult(balance: 9);
      final a = rewards.refreshWalletFromApi();
      await Future<void>.delayed(Duration.zero);
      expect(coins.walletFetches, 1);

      final b = rewards.refreshWalletFromApi();
      expect(identical(a, b), isTrue);
      expect(coins.walletFetches, 1);

      coins.walletGate!.complete();
      await a;
      expect(coins.walletFetches, 1);
      expect(rewards.balance.value, 9);
    });

    testWidgets('chip shows Retry on error', (tester) async {
      rewards.walletApiErrorMessage.value = 'Wallet down';
      rewards.hasCompletedWalletFetch.value = true;
      rewards.isLoadingWallet.value = false;

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(body: CoinBalanceChip()),
        ),
      );
      await tester.pump();

      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('42'), findsNothing);
    });

    test('chip Retry entrypoint refreshes wallet only', () async {
      var hydrateBodies = 0;
      HomeHydrate.debugRunOverride = (_) async {
        hydrateBodies++;
      };

      coins.walletError = const CoinsApiException(
        'Wallet down',
        statusCode: 500,
      );
      await rewards.refreshWalletFromApi();
      expect(rewards.walletApiErrorMessage.value, isNotNull);

      coins.walletError = null;
      coins.walletResult = const CoinsWalletResult(balance: 55);
      await rewards.refreshWalletFromApi();

      expect(rewards.balance.value, 55);
      expect(rewards.walletApiErrorMessage.value, isNull);
      expect(hydrateBodies, 0);
      expect(HomeHydrate.debugInFlight, isNull);
    });
  });

  group('claimable', () {
    test('loading → claimable', () async {
      coins.claimableGate = Completer<void>();
      coins.claimableResult = const ClaimableResult(
        claimableCoins: 25,
        canClaim: true,
      );
      final pending = rewards.refreshClaimableFromApi(includeYesterday: false);
      await Future<void>.delayed(Duration.zero);

      expect(rewards.isLoadingClaimable.value, isTrue);

      coins.claimableGate!.complete();
      await pending;

      expect(rewards.isLoadingClaimable.value, isFalse);
      expect(rewards.hasCompletedClaimableFetch.value, isTrue);
      expect(rewards.pendingCoins, 25);
      expect(rewards.claimableApiErrorMessage.value, isNull);
    });

    test('not claimable after successful zero', () async {
      coins.claimableResult = const ClaimableResult(
        claimableCoins: 0,
        canClaim: false,
      );
      await rewards.refreshClaimableFromApi(includeYesterday: false);

      expect(rewards.pendingCoins, 0);
      expect(rewards.hasCompletedClaimableFetch.value, isTrue);
      expect(rewards.claimableApiErrorMessage.value, isNull);
    });

    test('error does not look like not-claimable zero', () async {
      coins.claimableError = const CoinsApiException(
        'Claimable down',
        statusCode: 500,
      );
      await rewards.refreshClaimableFromApi(includeYesterday: false);

      expect(rewards.claimableApiErrorMessage.value, 'Claimable down');
      expect(rewards.hasCompletedClaimableFetch.value, isTrue);
      // Today key must not be forced to 0 on error.
      final todayKey = MealEntry.dateToKey(DateTime.now());
      expect(rewards.claimableByDate.containsKey(todayKey), isFalse);
    });

    test('retry today only and joins in-flight', () async {
      var hydrateBodies = 0;
      HomeHydrate.debugRunOverride = (_) async {
        hydrateBodies++;
      };

      coins.claimableGate = Completer<void>();
      coins.claimableResult = const ClaimableResult(
        claimableCoins: 3,
        canClaim: true,
      );
      final a = rewards.retryClaimableToday();
      await Future<void>.delayed(Duration.zero);
      expect(coins.claimableFetches, 1);

      final b = rewards.retryClaimableToday();
      await Future<void>.delayed(Duration.zero);
      // Second call joins today's in-flight GET.
      expect(coins.claimableFetches, 1);
      expect(
        coins.claimableDates
            .every((d) => d == MealEntry.normalizeDate(DateTime.now())),
        isTrue,
      );

      coins.claimableGate!.complete();
      await a;
      await b;

      expect(hydrateBodies, 0);
      expect(rewards.pendingCoins, 3);
      // No yesterday date was requested.
      expect(coins.claimableDates.length, 1);
    });

    testWidgets('banner shows Retry on claimable error', (tester) async {
      rewards.claimableApiErrorMessage.value = 'Claimable down';
      rewards.hasCompletedClaimableFetch.value = true;
      rewards.isLoadingClaimable.value = false;

      await tester.pumpWidget(
        const GetMaterialApp(
          home: Scaffold(body: StepsClaimBanner()),
        ),
      );
      await tester.pump();

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Claimable down'), findsOneWidget);
      expect(find.textContaining('Keep walking'), findsNothing);
    });
  });
}
