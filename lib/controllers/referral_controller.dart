import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_snackbar.dart';
import '../core/pending_referral_code.dart';
import '../core/referral_apply.dart';
import '../core/referral_link_parser.dart';
import '../models/referral_info.dart';
import '../services/referral_api_service.dart';
import 'rewards_controller.dart';
import 'user_controller.dart';

/// Invite Friends / referral frontend state.
///
/// Does not award coins locally — refreshes [RewardsController] after a
/// confirmed backend claim.
class ReferralController extends GetxController {
  ReferralController({ReferralApiService? api})
      : _api = api ?? ReferralApiService();

  final ReferralApiService _api;

  final isLoading = false.obs;
  final hasCompletedFetch = false.obs;
  final errorMessage = RxnString();
  final info = Rxn<ReferralInfo>();
  final isClaiming = false.obs;
  final claimErrorMessage = RxnString();

  Future<void>? _loadInFlight;
  int _sessionGeneration = 0;

  String get referralCode => info.value?.referralCode ?? '';
  String? get referralLink => info.value?.referralLink;
  int get successfulReferralCount =>
      info.value?.successfulReferralCount ?? 0;
  int get referralCoinsEarned => info.value?.coinsEarned ?? 0;

  @override
  void onReady() {
    super.onReady();
    unawaited(loadReferralInfo());
  }

  void clearSessionData() {
    _sessionGeneration++;
    _loadInFlight = null;
    isLoading.value = false;
    hasCompletedFetch.value = false;
    errorMessage.value = null;
    info.value = null;
    isClaiming.value = false;
    claimErrorMessage.value = null;
  }

  Future<void> loadReferralInfo({bool force = false}) {
    if (!force && _loadInFlight != null) return _loadInFlight!;
    final started = _loadReferralInfo();
    _loadInFlight = started;
    started.whenComplete(() {
      if (identical(_loadInFlight, started)) {
        _loadInFlight = null;
      }
    });
    return started;
  }

  Future<void> retryReferralInfo() => loadReferralInfo(force: true);

  Future<void> _loadReferralInfo() async {
    final sessionGen = _sessionGeneration;
    isLoading.value = true;
    errorMessage.value = null;
    if (!hasCompletedFetch.value) {
      info.value = null;
    }

    if (!Get.isRegistered<UserController>()) {
      errorMessage.value = 'Sign in to view your invite code.';
      hasCompletedFetch.value = true;
      isLoading.value = false;
      return;
    }

    final user = Get.find<UserController>();
    await user.localProfileReady;
    if (sessionGen != _sessionGeneration) return;

    if (!user.isLoggedIn || user.accessToken.isEmpty) {
      errorMessage.value = 'Sign in to view your invite code.';
      hasCompletedFetch.value = true;
      info.value = null;
      isLoading.value = false;
      return;
    }

    try {
      final loaded = await _api.fetchMyReferral(accessToken: user.accessToken);
      if (sessionGen != _sessionGeneration) return;
      info.value = loaded;
      errorMessage.value = null;
    } on ReferralApiException catch (error) {
      if (sessionGen != _sessionGeneration) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _clearSessionOnAuthFailure(statusCode: error.statusCode);
        return;
      }
      info.value = null;
      errorMessage.value = error.message;
    } catch (_) {
      if (sessionGen != _sessionGeneration) return;
      info.value = null;
      errorMessage.value =
          'Unable to load invite details. Please try again.';
    } finally {
      if (sessionGen == _sessionGeneration) {
        isLoading.value = false;
        hasCompletedFetch.value = true;
      }
    }
  }

  Future<void> copyReferralCode() async {
    final code = referralCode;
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!Get.testMode) {
      AppSnackbar.success('Referral code copied', title: 'Copied');
    }
  }

  Future<void> shareReferral() async {
    final code = referralCode;
    if (code.isEmpty) return;

    final link = referralLink;
    final text = (link != null && link.isNotEmpty)
        ? 'Join me on MyCaloriePal and track your food, calories and '
            'nutrition. Use my referral link:\n$link'
        : 'Join me on MyCaloriePal and track your food, calories and '
            'nutrition. Use my referral code $code when you sign up.';

    await SharePlus.instance.share(
      ShareParams(text: text, title: 'Invite friends to MyCaloriePal'),
    );
  }

  /// Captures an incoming invite URI into in-memory pending state.
  bool handleIncomingReferralUri(Uri uri) {
    return PendingReferralCode.instance.captureFromUri(uri);
  }

  bool handleIncomingReferralCode(String raw) {
    return PendingReferralCode.instance.setCode(raw);
  }

  /// Submits a pending (or explicit) code via POST /referrals/claim.
  Future<bool> submitReferralCodeIfRequired({String? code}) async {
    final toSubmit = (code == null || code.trim().isEmpty)
        ? PendingReferralCode.instance.code
        : ReferralLinkParser.codeFromString(code);
    if (toSubmit == null || toSubmit.isEmpty) return false;
    if (!Get.isRegistered<UserController>()) return false;

    final user = Get.find<UserController>();
    if (!user.isLoggedIn || user.accessToken.isEmpty) return false;

    final sessionGen = _sessionGeneration;
    isClaiming.value = true;
    claimErrorMessage.value = null;

    try {
      final result = await _api.claimReferral(
        accessToken: user.accessToken,
        code: toSubmit,
      );
      if (sessionGen != _sessionGeneration) return false;

      if (!result.success) {
        claimErrorMessage.value =
            result.message ?? 'Unable to apply that invite code.';
        return false;
      }

      PendingReferralCode.instance.clear();
      if (result.rewardConfirmed && Get.isRegistered<RewardsController>()) {
        await Get.find<RewardsController>().refreshWalletFromApi();
      }
      return true;
    } on ReferralApiException catch (error) {
      if (sessionGen != _sessionGeneration) return false;
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _clearSessionOnAuthFailure(statusCode: error.statusCode);
        return false;
      }
      claimErrorMessage.value = error.message;
      return false;
    } catch (_) {
      if (sessionGen != _sessionGeneration) return false;
      claimErrorMessage.value =
          'Unable to apply that invite code. Please try again.';
      return false;
    } finally {
      if (sessionGen == _sessionGeneration) {
        isClaiming.value = false;
      }
    }
  }

  Future<void> submitPendingAfterAuth() => ReferralApply.submitPendingIfNeeded(
        api: _api,
      );

  Future<void> _clearSessionOnAuthFailure({required int? statusCode}) async {
    if (!Get.isRegistered<UserController>()) return;
    final user = Get.find<UserController>();
    if (user.isLoggingOut || user.isDeletingAccount || !user.isLoggedIn) {
      return;
    }
    await user.clearInvalidSession(
      debugController: 'ReferralController',
      debugEndpoint: 'referrals',
      debugStatusCode: statusCode,
      debugRequestType: 'HTTP',
    );
  }
}
