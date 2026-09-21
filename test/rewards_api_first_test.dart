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

class _CoinsApi extends CoinsApiService {
  int walletFetches = 0;
  int claimableFetches = 0;
  int claimPosts = 0;
  int claimableInFlight = 0;
  int maxClaimableInFlight = 0;
  Completer<void>? walletGate;
  Completer<void>? claimableGate;
  Object? walletError;
  Object? claimError;
  Object? claimableError;
  CoinsWalletResult walletResult = const CoinsWalletResult(balance: 100);
  ClaimableResult claimableResult = const ClaimableResult(
    claimableCoins: 20,
    canClaim: true,
  );
  CoinClaimResult claimResult = const CoinClaimResult(claimedCoins: 20);
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
    claimableInFlight++;
    if (claimableInFlight > maxClaimableInFlight) {
      maxClaimableInFlight = claimableInFlight;
    }
    try {
      final g = claimableGate;
      if (g != null) await g.future;
      final err = claimableError;
      if (err != null) {
        if (err is CoinsApiException && err.statusCode == 429) {
          ApiClient.noteRateLimited();
        }
        throw err;
      }
      return claimableResult;
    } finally {
      claimableInFlight--;
    }
  }

  @override
  Future<CoinClaimResult> claimCoins({
    required String accessToken,
    DateTime? date,
    String? timezone,
  }) async {
    claimPosts++;
    final err = claimError;
    if (err != null) throw err;
    return claimResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CoinsApi coins;
  late RewardsController rewards;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'rewards_coin_balance_v1_u1': 999,
      'rewards_earned_by_date_v1_u1': '{"2026-01-01":50}',
      'rewards_steps_claimed_date_v1_u1': '2026-01-01',
      'rewards_unlocked_items_v1_u1': '["duffel_bag"]',
    });
    Get.testMode = true;
    await Get.deleteAll(force: true);
    HomeHydrate.debugReset();
    ApiClient.clearRateLimit();

    final user = UserController(authRepository: _FakeAuthRepository());
    Get.put(user, permanent: true);
    await user.localProfileReady;

    coins = _CoinsApi();
    rewards = RewardsController(coinsApi: coins);
    Get.put(rewards, permanent: true);
    await rewards.load();
  });

  tearDown(() async {
    HomeHydrate.debugReset();
    ApiClient.clearRateLimit();
    await Get.deleteAll(force: true);
  });

  test('A: load() does not restore wallet balance from SharedPreferences',
      () async {
    expect(rewards.balance.value, 0);
    expect(rewards.hasCompletedWalletFetch.value, isFalse);
    expect(rewards.unlockedIds, isEmpty);
    expect(rewards.earnedCoinsByDate, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('rewards_coin_balance_v1_u1'), isNull);
    expect(prefs.getString('rewards_earned_by_date_v1_u1'), isNull);
  });

  test('B: successful GET /coins sets balance from API', () async {
    coins.walletResult = const CoinsWalletResult(balance: 321);
    await rewards.refreshWalletFromApi();
    expect(rewards.balance.value, 321);
    expect(rewards.hasCompletedWalletFetch.value, isTrue);
    expect(rewards.walletApiErrorMessage.value, isNull);
  });

  test('C: wallet API failure does not fall back to old local balance',
      () async {
    coins.walletResult = const CoinsWalletResult(balance: 50);
    await rewards.refreshWalletFromApi();
    expect(rewards.balance.value, 50);

    coins.walletError = const CoinsApiException('down', statusCode: 500);
    await rewards.refreshWalletFromApi();

    expect(rewards.walletApiErrorMessage.value, isNotNull);
    // Balance must not jump back to wiped prefs (999) or invent a new value.
    expect(rewards.balance.value, 50);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('rewards_coin_balance_v1_u1'), isNull);
  });

  test('D: claim without balance refreshes wallet from API only', () async {
    coins.claimableResult = const ClaimableResult(
      claimableCoins: 15,
      canClaim: true,
    );
    await rewards.refreshClaimableFromApi(includeYesterday: false);
    expect(rewards.pendingCoins, 15);

    coins.claimResult = const CoinClaimResult(claimedCoins: 15);
    coins.walletResult = const CoinsWalletResult(balance: 215);
    coins.walletFetches = 0;
    coins.claimableFetches = 0;

    final ok = await rewards.claimDailyStepReward();
    expect(ok, isTrue);
    expect(coins.claimPosts, 1);
    // Wallet refresh only — no post-claim claimable storm.
    expect(coins.walletFetches, 1);
    expect(coins.claimableFetches, 0);
    expect(rewards.balance.value, 215);
    expect(rewards.pendingCoins, 0);
  });

  test('D2: claim with balance skips wallet and claimable refresh', () async {
    coins.claimableResult = const ClaimableResult(
      claimableCoins: 10,
      canClaim: true,
    );
    await rewards.refreshClaimableFromApi(includeYesterday: false);

    coins.claimResult = const CoinClaimResult(
      claimedCoins: 10,
      balance: 410,
    );
    coins.walletFetches = 0;
    coins.claimableFetches = 0;

    final ok = await rewards.claimDailyStepReward();
    expect(ok, isTrue);
    expect(rewards.balance.value, 410);
    expect(coins.walletFetches, 0);
    expect(coins.claimableFetches, 0);
  });

  test('E: claimable response balance is not persisted locally', () async {
    coins.claimableResult = const ClaimableResult(
      claimableCoins: 5,
      canClaim: true,
      balance: 777,
    );
    await rewards.refreshClaimableFromApi(includeYesterday: false);
    expect(rewards.balance.value, 777);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('rewards_coin_balance_v1_u1'), isNull);
  });

  test('F: unlockItem cannot locally deduct the API wallet', () async {
    coins.walletResult = const CoinsWalletResult(balance: 800);
    await rewards.refreshWalletFromApi();
    expect(rewards.balance.value, 800);

    final err = await rewards.unlockItem(
      'duffel_bag',
      shipping: const GiftShippingAddress(
        fullName: 'A',
        phone: '1',
        line1: 'x',
        city: 'y',
        pincode: '1',
      ),
    );
    expect(err, 'Shop purchases are not available yet.');
    expect(rewards.balance.value, 800);
    expect(rewards.unlockedIds, isEmpty);
  });

  test('G: session clear removes in-memory reward state', () async {
    coins.walletResult = const CoinsWalletResult(balance: 40);
    await rewards.refreshWalletFromApi();
    rewards.claimableCoins.value = 3;
    rewards.earnedCoinsByDate['2026-09-21'] = 3;

    rewards.clearSessionData();

    expect(rewards.balance.value, 0);
    expect(rewards.hasCompletedWalletFetch.value, isFalse);
    expect(rewards.claimableCoins.value, 0);
    expect(rewards.earnedCoinsByDate, isEmpty);
    expect(rewards.claimableByDate, isEmpty);
  });

  test('H: wallet in-flight coalescing still works', () async {
    coins.walletGate = Completer<void>();
    final a = rewards.refreshWalletFromApi();
    await Future<void>.delayed(Duration.zero);
    expect(coins.walletFetches, 1);
    final b = rewards.refreshWalletFromApi();
    expect(identical(a, b), isTrue);
    expect(coins.walletFetches, 1);
    coins.walletGate!.complete();
    await a;
  });

  test('I: claimable in-flight coalescing still works', () async {
    final day = MealEntry.normalizeDate(DateTime.now());
    final a = rewards.refreshClaimableForDate(day);
    final b = rewards.refreshClaimableForDate(day);
    await Future.wait([a, b]);
    expect(coins.claimableFetches, 1);
  });

  test('L: historical dates load sequentially (no unbounded fan-out)', () async {
    coins.claimableGate = Completer<void>();
    final today = MealEntry.normalizeDate(DateTime.now());
    final days = List.generate(7, (i) => today.subtract(Duration(days: i)));

    final pending = rewards.refreshClaimableForDates(days);
    // First GET is gated — only one may be in flight.
    for (var i = 0; i < 40 && coins.claimableFetches == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(coins.claimableFetches, 1);
    expect(coins.maxClaimableInFlight, 1);

    coins.claimableGate!.complete();
    await pending;

    expect(coins.claimableFetches, 7);
    expect(coins.maxClaimableInFlight, 1);
    expect(
      coins.claimableDates.toSet().length,
      7,
    );
  });

  test('M: historical prefetch reuses in-flight same-date Future', () async {
    coins.claimableGate = Completer<void>();
    final today = MealEntry.normalizeDate(DateTime.now());

    final a = rewards.refreshClaimableForDate(today);
    for (var i = 0; i < 40 && coins.claimableFetches == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(coins.claimableFetches, 1);

    final b = rewards.refreshClaimableForDates([today, today]);
    expect(coins.claimableFetches, 1);

    coins.claimableGate!.complete();
    await Future.wait([a, b]);
    expect(coins.claimableFetches, 1);
  });

  test('N: 429 on claimable stops further historical dates', () async {
    final today = MealEntry.normalizeDate(DateTime.now());
    coins.claimableError = const CoinsApiException(
      'too many',
      statusCode: 429,
    );
    await rewards.refreshClaimableForDates([
      today,
      today.subtract(const Duration(days: 1)),
      today.subtract(const Duration(days: 2)),
    ]);
    expect(ApiClient.isRateLimited, isTrue);
    // First request fails with 429; loop exits before starting more.
    expect(coins.claimableFetches, 1);
  });

  test('O: session clear discards in-flight claimable result', () async {
    coins.claimableGate = Completer<void>();
    coins.claimableResult = const ClaimableResult(
      claimableCoins: 99,
      canClaim: true,
    );
    final pending = rewards.refreshClaimableForDate(DateTime.now());
    for (var i = 0; i < 40 && coins.claimableFetches == 0; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    rewards.clearSessionData();
    coins.claimableGate!.complete();
    await pending;
    expect(rewards.claimableCoins.value, 0);
    expect(rewards.claimableByDate, isEmpty);
  });

  testWidgets('J: chip does not show pre-API balance', (tester) async {
    // Stale in-memory value without completed fetch must not paint as truth.
    rewards.balance.value = 999;
    rewards.hasCompletedWalletFetch.value = false;
    rewards.isLoadingWallet.value = false;
    rewards.walletApiErrorMessage.value = null;

    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(body: CoinBalanceChip()),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('999'), findsNothing);
  });

  testWidgets('K: chip shows API balance after successful fetch', (tester) async {
    coins.walletResult = const CoinsWalletResult(balance: 64);
    await rewards.refreshWalletFromApi();

    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(body: CoinBalanceChip()),
      ),
    );
    await tester.pump();

    expect(find.text('64'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
