import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/referral_controller.dart';
import '../controllers/rewards_controller.dart';
import '../core/responsive.dart';
import '../models/coin_history_item.dart';
import '../models/meal_entry.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/steps_claim_banner.dart';

enum _HistoryFilter { all, earned, spent }

/// Coin wallet + history — same soft mint card language as Home.
class CoinHistoryView extends StatefulWidget {
  const CoinHistoryView({super.key});

  @override
  State<CoinHistoryView> createState() => _CoinHistoryViewState();
}

class _CoinHistoryViewState extends State<CoinHistoryView> {
  _HistoryFilter _filter = _HistoryFilter.all;

  static const _mintIconBg = Color(0xFFDFF5E5);
  static const _mintIconFg = Color(0xFF1B8F3A);
  static const _softGreenFill = Color(0xFFE8F8EE);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Get.isRegistered<RewardsController>()) {
        Get.put(RewardsController(), permanent: true);
      }
      if (!Get.isRegistered<ReferralController>()) {
        Get.put(ReferralController());
      }
      final rewards = Get.find<RewardsController>();
      unawaited(_refreshHistory(rewards));
    });
  }

  Future<void> _refreshHistory(RewardsController rewards) async {
    await rewards.refreshWalletFromApi(retryOnRateLimit: true);
    if (!mounted) return;
    // Pull recent day claimable/earned from API so Activity isn't session-only.
    final today = MealEntry.normalizeDate(DateTime.now());
    final recent = <DateTime>[
      for (var i = 0; i < 7; i++) today.subtract(Duration(days: i)),
    ];
    // Force re-fetch even if keys exist — we need claimed amounts after claim.
    for (final day in recent) {
      if (!mounted) return;
      await rewards.refreshClaimableForDate(day);
    }
    if (Get.isRegistered<ReferralController>()) {
      await Get.find<ReferralController>().loadReferralInfo();
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    if (!Get.isRegistered<RewardsController>()) {
      Get.put(RewardsController(), permanent: true);
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: const AppAppBar(
        title: 'Coin History',
      ),
      body: Obx(() {
        final rewards = Get.find<RewardsController>();
        final balance = rewards.balance.value;
        final lifetime = rewards.lifetimeEarned.value;
        rewards.earnedCoinsByDate.length;
        rewards.unlockedIds.length;
        rewards.unlockedAtById.length;
        rewards.hasCompletedWalletFetch.value;
        rewards.isLoadingWallet.value;

        final referral = Get.isRegistered<ReferralController>()
            ? Get.find<ReferralController>()
            : null;
        referral?.info.value;
        referral?.hasCompletedFetch.value;

        final items = _buildItems(rewards, referral);
        final filtered = items.where((item) {
          switch (_filter) {
            case _HistoryFilter.all:
              return true;
            case _HistoryFilter.earned:
              return item.isCredit;
            case _HistoryFilter.spent:
              return !item.isCredit;
          }
        }).toList(growable: false);

        final loading = rewards.isLoadingWallet.value &&
            !rewards.hasCompletedWalletFetch.value;
        final isDark = AppColors.isDark(context);
        final spentFromGifts = items
            .where((item) => !item.isCredit)
            .fold<int>(0, (sum, item) => sum + item.amount.abs());
        final totalSpent = spentFromGifts > 0
            ? spentFromGifts
            : (lifetime - balance).clamp(0, lifetime);

        return RefreshIndicator(
          onRefresh: () async {
            await _refreshHistory(rewards);
          },
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              r.scale(16),
              r.scale(8),
              r.scale(16),
              r.scale(36),
            ),
            children: [
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
                )
              else ...[
                _WalletSummaryCard(
                  balance: balance,
                  lifetimeEarned: lifetime,
                  totalSpent: totalSpent,
                ),
              ],
              SizedBox(height: r.scale(22)),
              Row(
                children: [
                  Text(
                    'Activity',
                    style: TextStyle(
                      fontSize: r.scale(17),
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  const Spacer(),
                  _FilterLink(
                    label: 'All',
                    selected: _filter == _HistoryFilter.all,
                    onTap: () => setState(() => _filter = _HistoryFilter.all),
                  ),
                  _FilterDot(),
                  _FilterLink(
                    label: 'Earned',
                    selected: _filter == _HistoryFilter.earned,
                    onTap: () =>
                        setState(() => _filter = _HistoryFilter.earned),
                  ),
                  _FilterDot(),
                  _FilterLink(
                    label: 'Spent',
                    selected: _filter == _HistoryFilter.spent,
                    onTap: () =>
                        setState(() => _filter = _HistoryFilter.spent),
                  ),
                ],
              ),
              SizedBox(height: r.scale(12)),
              if (filtered.isEmpty)
                _EmptyTrail(
                  filter: _filter,
                  isDark: isDark,
                  onInvite: () => Get.toNamed(AppRoutes.inviteFriends),
                  onSteps: () => Get.toNamed(AppRoutes.caloriesBurn),
                  onShop: () => Get.toNamed(AppRoutes.rewardsShop),
                )
              else
                _ActivityCard(items: filtered, isDark: isDark),
            ],
          ),
        );
      }),
    );
  }

  List<CoinHistoryItem> _buildItems(
    RewardsController rewards,
    ReferralController? referral,
  ) {
    final items = <CoinHistoryItem>[];

    final referralCoins = referral?.referralCoinsEarned ?? 0;
    final friends = referral?.successfulReferralCount ?? 0;
    if (referralCoins > 0) {
      items.add(
        CoinHistoryItem(
          id: 'referral-total',
          title: friends <= 1 ? 'Referral bonus' : 'Referral rewards',
          subtitle: friends <= 0
              ? 'Invite Friends'
              : friends == 1
                  ? '1 friend joined'
                  : '$friends friends joined',
          amount: referralCoins,
          source: CoinHistorySource.referral,
        ),
      );
    }

    final earned = Map<String, int>.from(rewards.earnedCoinsByDate);
    final keys = earned.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final key in keys) {
      final amount = earned[key] ?? 0;
      if (amount <= 0) continue;
      DateTime? date;
      try {
        date = MealEntry.dateFromKey(key);
      } catch (_) {
        date = null;
      }
      final label = date == null ? key : DateFormat('MMM d').format(date);
      items.add(
        CoinHistoryItem(
          id: 'steps-$key',
          title: 'Steps claim',
          subtitle: '$label · Move & Earn',
          amount: amount,
          source: CoinHistorySource.steps,
          at: date,
        ),
      );
    }

    for (final gift in rewards.ownedItems) {
      final at = rewards.unlockedAt(gift.id);
      final when = at == null ? 'Gift Shop' : DateFormat('MMM d').format(at);
      items.add(
        CoinHistoryItem(
          id: 'gift-${gift.id}',
          title: gift.name,
          subtitle: '$when · Gift Shop',
          amount: -gift.cost,
          source: CoinHistorySource.giftShop,
          at: at,
        ),
      );
    }

    items.sort((a, b) {
      final aAt = a.at;
      final bAt = b.at;
      if (aAt == null && bAt == null) return 0;
      if (aAt == null) return -1;
      if (bAt == null) return 1;
      return bAt.compareTo(aAt);
    });

    return items;
  }
}

/// Balance summary card — Available / Lifetime / Spent (app theme).
class _WalletSummaryCard extends StatelessWidget {
  const _WalletSummaryCard({
    required this.balance,
    required this.lifetimeEarned,
    required this.totalSpent,
  });

  final int balance;
  final int lifetimeEarned;
  final int totalSpent;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        r.scale(18),
        r.scale(18),
        r.scale(18),
        r.scale(18),
      ),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(r.scale(18)),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available balance',
            style: TextStyle(
              fontSize: r.scale(13),
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          SizedBox(height: r.scale(12)),
          Row(
            children: [
              RewardCoinIcon(size: r.scale(34)),
              SizedBox(width: r.scale(12)),
              Text(
                _formatCount(balance),
                style: TextStyle(
                  fontSize: r.scale(34),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ],
          ),
          SizedBox(height: r.scale(18)),
          Row(
            children: [
              Expanded(
                child: _WalletMetric(
                  value: _formatCount(lifetimeEarned),
                  label: 'Lifetime earned',
                ),
              ),
              SizedBox(width: r.scale(24)),
              Expanded(
                child: _WalletMetric(
                  value: _formatCount(totalSpent),
                  label: 'Total spent',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletMetric extends StatelessWidget {
  const _WalletMetric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final lineColor = AppColors.borderOf(context).withValues(alpha: 0.9);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Two short segments with a gap (not one full-width line).
        Container(
          height: 1,
          width: double.infinity,
          color: lineColor,
        ),
        SizedBox(height: r.scale(12)),
        Text(
          value,
          style: TextStyle(
            fontSize: r.scale(22),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.1,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        SizedBox(height: r.scale(4)),
        Text(
          label,
          style: TextStyle(
            fontSize: r.scale(12),
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondaryOf(context),
          ),
        ),
      ],
    );
  }
}

class _FilterLink extends StatelessWidget {
  const _FilterLink({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.scale(4), vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: r.scale(13),
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? AppColors.primaryDark
                : AppColors.textSecondaryOf(context),
          ),
        ),
      ),
    );
  }
}

class _FilterDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      '·',
      style: TextStyle(
        color: AppColors.textSecondaryOf(context).withValues(alpha: 0.5),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.items, required this.isDark});

  final List<CoinHistoryItem> items;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final card = isDark ? AppColors.darkCard : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _HistoryRow(item: items[i]),
            if (i < items.length - 1)
              Divider(
                height: 1,
                indent: r.scale(70),
                endIndent: r.scale(16),
                color: AppColors.borderOf(context).withValues(alpha: 0.7),
              ),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  final CoinHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final isDark = AppColors.isDark(context);
    final credit = item.isCredit;
    final amountColor =
        credit ? _CoinHistoryViewState._mintIconFg : AppColors.error;

    final (icon, bg, fg) = switch (item.source) {
      CoinHistorySource.referral => (
          Icons.person_add_alt_1_rounded,
          _CoinHistoryViewState._mintIconBg,
          _CoinHistoryViewState._mintIconFg,
        ),
      CoinHistorySource.steps => (
          Icons.directions_walk_rounded,
          const Color(0xFFFFF0D6),
          const Color(0xFFE67E00),
        ),
      CoinHistorySource.giftShop => (
          Icons.card_giftcard_rounded,
          const Color(0xFFFFECEC),
          AppColors.error,
        ),
      CoinHistorySource.other => (
          Icons.monetization_on_outlined,
          AppColors.surfaceOf(context),
          AppColors.textSecondaryOf(context),
        ),
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.scale(16),
        r.scale(14),
        r.scale(16),
        r.scale(14),
      ),
      child: Row(
        children: [
          Container(
            width: r.scale(44),
            height: r.scale(44),
            decoration: BoxDecoration(
              color: isDark ? fg.withValues(alpha: 0.16) : bg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: fg, size: r.scale(20)),
          ),
          SizedBox(width: r.scale(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: r.scale(14.5),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                SizedBox(height: r.scale(2)),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: r.scale(12.5),
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${credit ? '+' : ''}${item.amount}',
            style: TextStyle(
              fontSize: r.scale(15),
              fontWeight: FontWeight.w800,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTrail extends StatelessWidget {
  const _EmptyTrail({
    required this.filter,
    required this.isDark,
    required this.onInvite,
    required this.onSteps,
    required this.onShop,
  });

  final _HistoryFilter filter;
  final bool isDark;
  final VoidCallback onInvite;
  final VoidCallback onSteps;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final card = isDark ? AppColors.darkCard : Colors.white;
    final muted = AppColors.textSecondaryOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);

    final title = switch (filter) {
      _HistoryFilter.all => 'Your coin trail starts here',
      _HistoryFilter.earned => 'No earnings yet',
      _HistoryFilter.spent => 'No gifts unlocked yet',
    };
    final body = switch (filter) {
      _HistoryFilter.all =>
        'When you claim steps, earn from invites, or unlock a gift, every move shows up here.',
      _HistoryFilter.earned =>
        'Claim daily steps or invite friends — earnings land in this list.',
      _HistoryFilter.spent =>
        'Browse Gift Shop and unlock any gift you like with your balance.',
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        r.scale(20),
        r.scale(28),
        r.scale(20),
        r.scale(22),
      ),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: r.scale(64),
            height: r.scale(64),
            decoration: BoxDecoration(
              color: isDark
                  ? _CoinHistoryViewState._mintIconFg.withValues(alpha: 0.16)
                  : _CoinHistoryViewState._softGreenFill,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              filter == _HistoryFilter.spent
                  ? Icons.card_giftcard_rounded
                  : Icons.receipt_long_rounded,
              size: r.scale(28),
              color: _CoinHistoryViewState._mintIconFg,
            ),
          ),
          SizedBox(height: r.scale(16)),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.scale(16),
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: textPrimary,
            ),
          ),
          SizedBox(height: r.scale(8)),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.scale(13.5),
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: muted,
            ),
          ),
          SizedBox(height: r.scale(18)),
          if (filter == _HistoryFilter.spent)
            TextButton(
              onPressed: onShop,
              style: TextButton.styleFrom(
                foregroundColor: _CoinHistoryViewState._mintIconFg,
                backgroundColor: _CoinHistoryViewState._softGreenFill,
                padding: EdgeInsets.symmetric(
                  horizontal: r.scale(16),
                  vertical: r.scale(10),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Browse Gift Shop',
                style: TextStyle(
                  fontSize: r.scale(13),
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: onInvite,
                  style: TextButton.styleFrom(
                    foregroundColor: _CoinHistoryViewState._mintIconFg,
                    backgroundColor: _CoinHistoryViewState._softGreenFill,
                    padding: EdgeInsets.symmetric(
                      horizontal: r.scale(14),
                      vertical: r.scale(10),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Invite friends',
                    style: TextStyle(
                      fontSize: r.scale(13),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: r.scale(8)),
                TextButton(
                  onPressed: onSteps,
                  style: TextButton.styleFrom(
                    foregroundColor: textPrimary,
                    padding: EdgeInsets.symmetric(
                      horizontal: r.scale(12),
                      vertical: r.scale(10),
                    ),
                  ),
                  child: Text(
                    'Earn steps',
                    style: TextStyle(
                      fontSize: r.scale(13),
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

String _formatCount(int value) {
  return value.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
}
