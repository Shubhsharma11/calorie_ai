import 'dart:async';

import 'package:calorie_ai/controllers/referral_controller.dart';
import 'package:calorie_ai/controllers/rewards_controller.dart';
import 'package:calorie_ai/controllers/user_controller.dart';
import 'package:calorie_ai/core/pending_referral_code.dart';
import 'package:calorie_ai/core/referral_apply.dart';
import 'package:calorie_ai/core/referral_link_parser.dart';
import 'package:calorie_ai/models/claimable_result.dart';
import 'package:calorie_ai/models/referral_info.dart';
import 'package:calorie_ai/repositories/auth_repository.dart';
import 'package:calorie_ai/services/coins_api_service.dart';
import 'package:calorie_ai/services/local_storage_service.dart';
import 'package:calorie_ai/services/referral_api_service.dart';
import 'package:flutter/services.dart';
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

  @override
  Future<Map<String, dynamic>> loadSession() async =>
      Map<String, dynamic>.from(disk);

  @override
  Future<void> clearLocalAuthData() async {
    disk = {};
  }

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
}

class _FakeReferralApi extends ReferralApiService {
  int fetchCalls = 0;
  int claimCalls = 0;
  Completer<void>? fetchGate;
  Object? fetchError;
  Object? claimError;
  ReferralInfo info = const ReferralInfo(
    referralCode: 'AB12CD',
    referralLink: 'https://mycaloriepal.com/r/AB12CD',
    successfulReferralCount: 3,
    coinsEarned: 300,
  );
  ReferralClaimResult claimResult = const ReferralClaimResult(
    success: true,
    rewardConfirmed: true,
  );

  @override
  Future<ReferralInfo> fetchMyReferral({required String accessToken}) async {
    fetchCalls++;
    final gate = fetchGate;
    if (gate != null) await gate.future;
    final err = fetchError;
    if (err != null) throw err;
    return info;
  }

  @override
  Future<ReferralClaimResult> claimReferral({
    required String accessToken,
    required String code,
  }) async {
    claimCalls++;
    final err = claimError;
    if (err != null) throw err;
    return claimResult;
  }
}

class _CountingCoinsApi extends CoinsApiService {
  int walletFetches = 0;
  int balance = 100;

  @override
  Future<CoinsWalletResult> fetchWallet({required String accessToken}) async {
    walletFetches++;
    return CoinsWalletResult(balance: balance);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAuthRepository auth;
  late UserController user;
  late _FakeReferralApi referralApi;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
    await Get.deleteAll(force: true);
    PendingReferralCode.instance.debugReset();

    auth = _FakeAuthRepository();
    user = UserController(authRepository: auth);
    Get.put(user, permanent: true);
    await user.localProfileReady;

    referralApi = _FakeReferralApi();
  });

  tearDown(() async {
    PendingReferralCode.instance.debugReset();
    await Get.deleteAll(force: true);
  });

  test('ReferralLinkParser extracts code from mycaloriepal URL', () {
    expect(
      ReferralLinkParser.codeFromUri(
        Uri.parse('https://mycaloriepal.com/r/AB12CD'),
      ),
      'AB12CD',
    );
    expect(
      ReferralLinkParser.codeFromUri(
        Uri.parse('https://www.mycaloriepal.com/invite/zz99yy'),
      ),
      'ZZ99YY',
    );
    expect(
      ReferralLinkParser.codeFromUri(
        Uri.parse('https://mycaloriepal.com/?ref=hello1'),
      ),
      'HELLO1',
    );
    expect(
      ReferralLinkParser.codeFromString('ab12cd'),
      'AB12CD',
    );
  });

  test('pending referral code survives login navigation in memory', () {
    expect(
      PendingReferralCode.instance.captureFromUri(
        Uri.parse('https://mycaloriepal.com/r/JOIN88'),
      ),
      isTrue,
    );
    expect(PendingReferralCode.instance.code, 'JOIN88');

    // Simulate navigating login → onboarding without clearing process memory.
    expect(PendingReferralCode.instance.hasCode, isTrue);
    expect(PendingReferralCode.instance.code, 'JOIN88');
  });

  test('existing users without referral continue normally', () {
    expect(PendingReferralCode.instance.hasCode, isFalse);
    expect(user.isLoggedIn, isTrue);
  });

  test('loadReferralInfo success populates code and stats', () async {
    final controller = ReferralController(api: referralApi);
    Get.put(controller);

    await controller.loadReferralInfo();

    expect(controller.hasCompletedFetch.value, isTrue);
    expect(controller.errorMessage.value, isNull);
    expect(controller.referralCode, 'AB12CD');
    expect(controller.successfulReferralCount, 3);
    expect(controller.referralCoinsEarned, 300);
    expect(controller.referralLink, contains('AB12CD'));
    expect(referralApi.fetchCalls, 1);
  });

  test('loadReferralInfo does not expose fake zeros while loading', () async {
    referralApi.fetchGate = Completer<void>();
    final controller = ReferralController(api: referralApi);
    Get.put(controller);

    final future = controller.loadReferralInfo();
    expect(controller.isLoading.value, isTrue);
    expect(controller.info.value, isNull);
    expect(controller.hasCompletedFetch.value, isFalse);

    referralApi.fetchGate!.complete();
    await future;
    expect(controller.referralCode, 'AB12CD');
  });

  test('loadReferralInfo error then retry', () async {
    referralApi.fetchError = const ReferralApiException(
      'network down',
      statusCode: 500,
    );
    final controller = ReferralController(api: referralApi);
    Get.put(controller);

    await controller.loadReferralInfo();
    expect(controller.info.value, isNull);
    expect(controller.errorMessage.value, isNotNull);
    expect(controller.referralCode, isEmpty);

    referralApi.fetchError = null;
    await controller.retryReferralInfo();
    expect(controller.errorMessage.value, isNull);
    expect(controller.referralCode, 'AB12CD');
    expect(referralApi.fetchCalls, 2);
  });

  test('duplicate GET joins the same in-flight request', () async {
    referralApi.fetchGate = Completer<void>();
    final controller = ReferralController(api: referralApi);
    Get.put(controller);

    final a = controller.loadReferralInfo();
    final b = controller.loadReferralInfo();
    expect(identical(a, b), isTrue);

    referralApi.fetchGate!.complete();
    await Future.wait([a, b]);
    expect(referralApi.fetchCalls, 1);
  });

  test('copyReferralCode writes clipboard', () async {
    final controller = ReferralController(api: referralApi);
    Get.put(controller);
    await controller.loadReferralInfo();

    final bound = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      bound.add(call);
      return null;
    });

    await controller.copyReferralCode();
    expect(
      bound.any(
        (call) =>
            call.method == 'Clipboard.setData' &&
            call.arguments['text'] == 'AB12CD',
      ),
      isTrue,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('claim success refreshes wallet and never increments locally', () async {
    final coins = _CountingCoinsApi()..balance = 100;
    final rewards = RewardsController(coinsApi: coins);
    Get.put(rewards, permanent: true);
    rewards.balance.value = 100;

    final controller = ReferralController(api: referralApi);
    Get.put(controller);
    PendingReferralCode.instance.setCode('AB12CD');

    coins.balance = 400;
    final ok = await controller.submitReferralCodeIfRequired();
    expect(ok, isTrue);
    expect(referralApi.claimCalls, 1);
    expect(PendingReferralCode.instance.hasCode, isFalse);
    expect(coins.walletFetches, 1);
    expect(rewards.balance.value, 400);
  });

  test('claim failure keeps pending code and does not touch wallet', () async {
    final coins = _CountingCoinsApi();
    final rewards = RewardsController(coinsApi: coins);
    Get.put(rewards, permanent: true);
    rewards.balance.value = 50;

    referralApi.claimError = const ReferralApiException(
      'invalid code',
      statusCode: 400,
    );
    final controller = ReferralController(api: referralApi);
    Get.put(controller);
    PendingReferralCode.instance.setCode('BADCODE');

    final ok = await controller.submitReferralCodeIfRequired();
    expect(ok, isFalse);
    expect(PendingReferralCode.instance.code, 'BADCODE');
    expect(coins.walletFetches, 0);
    expect(rewards.balance.value, 50);
  });

  test('401 on referral fetch clears session via existing path', () async {
    referralApi.fetchError = const ReferralApiException(
      'Invalid or expired access token',
      statusCode: 401,
    );
    final controller = ReferralController(api: referralApi);
    Get.put(controller);

    await controller.loadReferralInfo();
    expect(user.isLoggedIn, isFalse);
    expect(user.accessToken, isEmpty);
  });

  test('ReferralApply submits pending after auth without blocking', () async {
    PendingReferralCode.instance.setCode('JOIN88');
    await ReferralApply.submitPendingIfNeeded(api: referralApi);
    expect(referralApi.claimCalls, 1);
    expect(PendingReferralCode.instance.hasCode, isFalse);
  });

  test('ReferralInfo.fromJson accepts snake_case', () {
    final info = ReferralInfo.fromJson({
      'referral_code': 'snake1',
      'referral_link': 'https://mycaloriepal.com/r/snake1',
      'successful_referral_count': 2,
      'coins_earned': 200,
    });
    expect(info.referralCode, 'SNAKE1');
    expect(info.successfulReferralCount, 2);
    expect(info.coinsEarned, 200);
  });
}
