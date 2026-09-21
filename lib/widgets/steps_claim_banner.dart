import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/rewards_controller.dart';
import '../controllers/tracker_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../routes/app_routes.dart';
import 'coin_claim_lottery_dialog.dart';

/// Home steps + claim card — matches the soft mint home design.
class StepsClaimBanner extends StatefulWidget {
  const StepsClaimBanner({super.key});

  /// Opens the rewards shop from the home coin chip or claim button.
  static void openRewardsShop() => Get.toNamed(AppRoutes.rewardsShop);

  @override
  State<StepsClaimBanner> createState() => _StepsClaimBannerState();
}

class _StepsClaimBannerState extends State<StepsClaimBanner> {
  static const _iconBg = Color(0xFFDFF5E5);
  static const _iconFg = Color(0xFF1B8F3A);

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    if (!Get.isRegistered<RewardsController>()) {
      return const SizedBox.shrink();
    }
    final rewards = Get.find<RewardsController>();

    return Obx(() {
      if (Get.isRegistered<TrackerController>()) {
        Get.find<TrackerController>().activityRevision.value;
      }

      final steps = rewards.todaySteps;
      final goal = rewards.stepsGoal;
      final claimed = rewards.hasClaimedToday;
      final todayPending = rewards.pendingCoins;
      final yesterdayPending = rewards.yesterdayPendingCoins;
      final pending = todayPending > 0 ? todayPending : yesterdayPending;
      final claimingYesterday = todayPending <= 0 && yesterdayPending > 0;
      final canClaim = pending > 0 && !rewards.isClaiming.value;
      final claiming = rewards.isClaiming.value;
      final claimableLoading = rewards.isLoadingClaimable.value;
      final claimableCompleted = rewards.hasCompletedClaimableFetch.value;
      final claimableError = rewards.claimableApiErrorMessage.value;
      rewards.claimableCoins.value;
      rewards.claimableByDate.length;
      rewards.balance.value;

      final showClaimableLoading = !claimableCompleted && claimableLoading;
      final showClaimableError =
          claimableError != null && !claimableLoading;

      final String subtitle;
      if (showClaimableLoading) {
        subtitle = 'Loading today’s rewards…';
      } else if (showClaimableError) {
        subtitle = claimableError;
      } else if (canClaim) {
        subtitle = claimingYesterday
            ? '+$pending from yesterday — claim to update balance'
            : todayPending > 0 && yesterdayPending > 0
                ? '+$todayPending today, +$yesterdayPending yesterday — claim'
                : '+$pending coins ready — claim to update balance';
      } else if (claimed && yesterdayPending <= 0) {
        subtitle = 'Open store to unlock gifts with your balance';
      } else {
        subtitle = 'Keep walking — claimable coins show here when ready';
      }

      return Container(
        padding: EdgeInsets.fromLTRB(
          r.scale(16),
          r.scale(16),
          r.scale(12),
          r.scale(16),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1B8F3A).withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: r.scale(48),
              height: r.scale(48),
              decoration: const BoxDecoration(
                color: _iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_run_rounded,
                size: r.scale(26),
                color: _iconFg,
              ),
            ),
            SizedBox(width: r.scale(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step ${_format(steps)} of ${_format(goal)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: r.scale(16),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E),
                      height: 1.15,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: r.scale(5)),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: r.scale(12.5),
                      fontWeight: FontWeight.w500,
                      color: showClaimableError
                          ? const Color(0xFFB42318)
                          : const Color(0xFF8E8E93),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: r.scale(8)),
            if (showClaimableLoading)
              _ClaimPill(
                label: '…',
                enabled: false,
                loading: true,
                claimed: false,
                onTap: () {},
              )
            else if (showClaimableError)
              _ClaimPill(
                label: 'Retry',
                enabled: true,
                loading: false,
                claimed: false,
                onTap: () {
                  HapticFeedback.selectionClick();
                  rewards.retryClaimableToday();
                },
              )
            else if (canClaim || claiming)
              _ClaimPill(
                label: todayPending > 0 && yesterdayPending > 0
                    ? 'Claim ${todayPending + yesterdayPending}'
                    : 'Claim $pending',
                enabled: canClaim && !claiming,
                loading: claiming,
                claimed: false,
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  final total = await rewards.claimPendingStepRewards();
                  if (total > 0) {
                    await CoinClaimLotteryDialog.show(coins: total);
                  } else {
                    AppSnackbar.error(
                      rewards.lastClaimError.value ??
                          'Couldn’t claim coins. Try again.',
                      title: 'Claim failed',
                    );
                  }
                },
              )
            else
              _ClaimPill(
                label: 'Store',
                enabled: true,
                loading: false,
                claimed: claimed,
                showChevron: true,
                onTap: StepsClaimBanner.openRewardsShop,
              ),
          ],
        ),
      );
    });
  }

  String _format(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

class _ClaimPill extends StatelessWidget {
  const _ClaimPill({
    required this.label,
    required this.enabled,
    required this.loading,
    required this.claimed,
    required this.onTap,
    this.showChevron = false,
  });

  final String label;
  final bool enabled;
  final bool loading;
  final bool claimed;
  final VoidCallback onTap;
  final bool showChevron;

  static const _readyGreen = Color(0xFF34C759);
  static const _lockedBg = Color(0xFFF2F2F7);
  static const _lockedText = Color(0xFF636366);
  static const _claimedBg = Color(0xFFEAF8EE);
  static const _claimedText = Color(0xFF1B8F3A);

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    final Color bg;
    final Color fg;
    if (claimed && !showChevron) {
      bg = _claimedBg;
      fg = _claimedText;
    } else if (enabled || loading || showChevron) {
      bg = _readyGreen;
      fg = Colors.white;
    } else {
      bg = _lockedBg;
      fg = _lockedText;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: (enabled || showChevron) ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: r.scale(38),
          padding: EdgeInsets.only(
            left: r.scale(14),
            right: r.scale(showChevron ? 8 : 10),
          ),
          alignment: Alignment.center,
          child: loading
              ? SizedBox(
                  width: r.scale(16),
                  height: r.scale(16),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: fg,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: r.scale(13),
                        fontWeight: FontWeight.w800,
                        color: fg,
                        height: 1,
                      ),
                    ),
                    SizedBox(width: r.scale(showChevron ? 2 : 6)),
                    if (showChevron)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: r.scale(20),
                        color: fg,
                      )
                    else if (!claimed)
                      RewardCoinIcon(size: r.scale(17))
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        size: r.scale(18),
                        color: fg,
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class CoinBalanceChip extends StatelessWidget {
  const CoinBalanceChip({super.key, this.onTap});

  final VoidCallback? onTap;

  static const _chipBg = Color(0xFFFFF4D6);
  static const _chipText = Color(0xFF9A6700);
  static const _errorBg = Color(0xFFFFF0F0);
  static const _errorText = Color(0xFFB42318);

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    if (!Get.isRegistered<RewardsController>()) {
      return const SizedBox.shrink();
    }
    final rewards = Get.find<RewardsController>();

    return Obx(() {
      final loading = rewards.isLoadingWallet.value;
      final completed = rewards.hasCompletedWalletFetch.value;
      final error = rewards.walletApiErrorMessage.value;
      final value = rewards.balance.value;

      if (error != null && !loading) {
        return Material(
          color: _errorBg,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: () => rewards.refreshWalletFromApi(),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 42,
              padding: EdgeInsets.symmetric(horizontal: r.scale(12)),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: r.scale(16),
                    color: _errorText,
                  ),
                  SizedBox(width: r.scale(6)),
                  Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: r.scale(13),
                      fontWeight: FontWeight.w800,
                      color: _errorText,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // Never paint a pre-API / invented balance — wait for wallet GET.
      if (!completed) {
        return Material(
          color: _chipBg,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: 42,
            padding: EdgeInsets.symmetric(horizontal: r.scale(14)),
            alignment: Alignment.center,
            child: SizedBox(
              width: r.scale(16),
              height: r.scale(16),
              child: const CircularProgressIndicator(
                strokeWidth: 2.2,
                color: _chipText,
              ),
            ),
          ),
        );
      }

      return Material(
        color: _chipBg,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: 42,
            padding: EdgeInsets.symmetric(horizontal: r.scale(12)),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RewardCoinIcon(size: r.scale(20)),
                SizedBox(width: r.scale(6)),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: r.scale(15),
                    fontWeight: FontWeight.w800,
                    color: _chipText,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class RewardCoinIcon extends StatelessWidget {
  const RewardCoinIcon({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF1A8),
            Color(0xFFFFD54F),
            Color(0xFFF0A202),
          ],
        ),
        border: Border.all(color: const Color(0xFFE09B00), width: size * 0.06),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF0A202).withValues(alpha: 0.35),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '\$',
        style: TextStyle(
          fontSize: size * 0.52,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF8A5A00),
          height: 1,
        ),
      ),
    );
  }
}
