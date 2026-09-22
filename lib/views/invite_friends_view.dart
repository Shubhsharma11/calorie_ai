import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/referral_controller.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/steps_claim_banner.dart';

/// Production Invite Friends screen — referral code, share, and stats.
class InviteFriendsView extends StatelessWidget {
  const InviteFriendsView({super.key});

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    if (!Get.isRegistered<ReferralController>()) {
      Get.put(ReferralController());
    }
    final referral = Get.find<ReferralController>();

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppAppBar(
        title: 'Invite Friends',
        actions: [
          Padding(
            padding: EdgeInsets.only(right: r.scale(12)),
            child: const CoinBalanceChip(),
          ),
        ],
      ),
      body: Obx(() {
        if (referral.isLoading.value && !referral.hasCompletedFetch.value) {
          return const _InviteLoading();
        }

        final error = referral.errorMessage.value;
        if (error != null && referral.info.value == null) {
          return _InviteError(
            message: error,
            onRetry: referral.retryReferralInfo,
          );
        }

        return _InviteBody(referral: referral);
      }),
    );
  }
}

class _InviteBody extends StatelessWidget {
  const _InviteBody({required this.referral});

  final ReferralController referral;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final isDark = AppColors.isDark(context);
    final surface = isDark ? AppColors.darkCard : Colors.white;

    return Obx(() {
      final code = referral.referralCode;
      final friends = referral.successfulReferralCount;
      final coins = referral.referralCoinsEarned;
      final hasCode = code.isNotEmpty;

      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          r.scale(20),
          r.scale(8),
          r.scale(20),
          r.scale(32),
        ),
        children: [
          Text(
            'Share MyCaloriePal with your friends and earn coins when they join.',
            style: TextStyle(
              fontSize: r.scale(15),
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
          SizedBox(height: r.scale(28)),
          Text(
            'YOUR REFERRAL CODE',
            style: TextStyle(
              fontSize: r.scale(12),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: textSecondary,
            ),
          ),
          SizedBox(height: r.scale(10)),
          DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(r.scale(16)),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                r.scale(16),
                r.scale(14),
                r.scale(8),
                r.scale(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hasCode ? code : '—',
                      style: TextStyle(
                        fontSize: r.scale(28),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.4,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: hasCode ? referral.copyReferralCode : null,
                    child: Text(
                      'Copy',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: hasCode
                            ? AppColors.primary
                            : textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: r.scale(16)),
          SizedBox(
            width: double.infinity,
            height: r.scale(52),
            child: FilledButton(
              onPressed: hasCode ? referral.shareReferral : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.scale(14)),
                ),
                textStyle: TextStyle(
                  fontSize: r.scale(16),
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Invite Friends'),
            ),
          ),
          SizedBox(height: r.scale(32)),
          Text(
            'Your progress',
            style: TextStyle(
              fontSize: r.scale(16),
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          SizedBox(height: r.scale(12)),
          _StatRow(
            label: 'Friends joined',
            value: '$friends',
            surface: surface,
          ),
          SizedBox(height: r.scale(10)),
          _StatRow(
            label: 'Coins earned',
            value: '$coins',
            surface: surface,
          ),
          if (friends == 0) ...[
            SizedBox(height: r.scale(24)),
            Text(
              'No friends have joined yet. Share your code to get started.',
              style: TextStyle(
                fontSize: r.scale(13),
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.surface,
  });

  final String label;
  final String value;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(r.scale(14)),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: r.scale(16),
          vertical: r.scale(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: r.scale(14),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: r.scale(18),
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteLoading extends StatelessWidget {
  const _InviteLoading();

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: r.scale(28),
            height: r.scale(28),
            child: const CircularProgressIndicator(strokeWidth: 2.6),
          ),
          SizedBox(height: r.scale(14)),
          Text(
            'Loading invite details…',
            style: TextStyle(
              fontSize: r.scale(14),
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteError extends StatelessWidget {
  const _InviteError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.scale(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: r.scale(14),
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            SizedBox(height: r.scale(16)),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontSize: r.scale(15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
