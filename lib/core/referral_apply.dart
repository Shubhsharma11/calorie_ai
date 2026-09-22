import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../controllers/rewards_controller.dart';
import '../controllers/user_controller.dart';
import '../services/referral_api_service.dart';
import 'app_log.dart';
import 'pending_referral_code.dart';

/// Applies a pending invite code after auth / onboarding without blocking UX.
///
/// Coin awards come from the backend. On confirmed reward, refreshes the
/// existing [RewardsController] wallet — never mutates balance locally.
abstract final class ReferralApply {
  static Future<void> submitPendingIfNeeded({
    ReferralApiService? api,
  }) async {
    final pending = PendingReferralCode.instance.code;
    if (pending == null || pending.isEmpty) return;
    if (!Get.isRegistered<UserController>()) return;

    final user = Get.find<UserController>();
    if (!user.isLoggedIn ||
        user.accessToken.isEmpty ||
        user.isLoggingOut ||
        user.isDeletingAccount) {
      return;
    }

    final service = api ?? ReferralApiService();
    try {
      appLog('Referral: submitting pending code len=${pending.length}');
      final result = await service.claimReferral(
        accessToken: user.accessToken,
        code: pending,
      );
      if (result.success) {
        PendingReferralCode.instance.clear();
        if (result.rewardConfirmed) {
          await _refreshWalletQuietly();
        }
      }
    } on ReferralApiException catch (error) {
      // Keep pending for a later retry (e.g. after onboarding) unless auth died.
      if (error.statusCode == 401 || error.statusCode == 403) {
        if (Get.isRegistered<UserController>()) {
          await Get.find<UserController>().clearInvalidSession(
            debugController: 'ReferralApply',
            debugEndpoint: 'POST /referrals/claim',
            debugStatusCode: error.statusCode,
            debugRequestType: 'POST',
          );
        }
      } else {
        debugPrint('ReferralApply: claim deferred — ${error.message}');
      }
    } catch (error) {
      debugPrint('ReferralApply: claim deferred — $error');
    }
  }

  static Future<void> _refreshWalletQuietly() async {
    if (!Get.isRegistered<RewardsController>()) return;
    try {
      await Get.find<RewardsController>().refreshWalletFromApi();
    } catch (error) {
      debugPrint('ReferralApply: wallet refresh failed — $error');
    }
  }
}
