import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/rewards_controller.dart';
import '../controllers/tracker_controller.dart';
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
  void initState() {
    super.initState();
    if (Get.isRegistered<RewardsController>()) {
      unawaited(Get.find<RewardsController>().refreshCoinsFromApi());
    }
  }

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
      final pending = rewards.pendingCoins;
      final canClaim = pending > 0 && !rewards.isClaiming.value;
      final claiming = rewards.isClaiming.value;
      rewards.claimableCoins.value;
      rewards.balance.value;

      final subtitle = canClaim
          ? '+$pending coins ready — claim to update balance'
          : claimed
              ? 'Open store to unlock gifts with your balance'
              : 'Keep walking — claimable coins show here when ready';

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
                      color: const Color(0xFF8E8E93),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: r.scale(8)),
            // Claim only updates wallet. Store opens from the coin chip.
            if (canClaim || claiming)
              _ClaimPill(
                label: 'Claim $pending',
                enabled: canClaim && !claiming,
                loading: claiming,
                claimed: false,
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  final claimedAmount = rewards.pendingCoins;
                  final ok = await rewards.claimDailyStepReward();
                  if (ok) {
                    await CoinClaimLotteryDialog.show(coins: claimedAmount);
                  }
                },
              )
            else
              _ClaimPill(
                label: 'Store',
                enabled: true,
                loading: false,
                claimed: claimed,
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
  });

  final String label;
  final bool enabled;
  final bool loading;
  final bool claimed;
  final VoidCallback onTap;

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
    if (claimed) {
      bg = _claimedBg;
      fg = _claimedText;
    } else if (enabled || loading) {
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
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: r.scale(38),
          padding: EdgeInsets.only(
            left: r.scale(14),
            right: r.scale(10),
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
                    if (!claimed) ...[
                      SizedBox(width: r.scale(6)),
                      RewardCoinIcon(size: r.scale(17)),
                    ] else ...[
                      SizedBox(width: r.scale(4)),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: r.scale(18),
                        color: fg,
                      ),
                    ],
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

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    if (!Get.isRegistered<RewardsController>()) {
      return const SizedBox.shrink();
    }
    final rewards = Get.find<RewardsController>();

    return Obx(() {
      final value = rewards.balance.value;
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
