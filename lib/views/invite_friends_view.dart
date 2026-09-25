import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/referral_controller.dart';
import '../core/responsive.dart';
import '../models/referral_info.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';

/// Invite Friends — referral code, stats, join history, share CTA.
class InviteFriendsView extends StatelessWidget {
  const InviteFriendsView({super.key});

  static const _coinsPerFriend = 100;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);

    if (!Get.isRegistered<ReferralController>()) {
      Get.put(ReferralController());
    }
    final referral = Get.find<ReferralController>();

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: const AppAppBar.backOnly(),
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
      bottomNavigationBar: Obx(() {
        final ready = referral.hasCompletedFetch.value &&
            referral.info.value != null &&
            referral.errorMessage.value == null;
        if (!ready) return const SizedBox.shrink();

        final hasCode = referral.referralCode.isNotEmpty;
        final r = context.responsive;
        final isDark = AppColors.isDark(context);

        return Material(
          color: AppColors.backgroundOf(context),
          child: SafeArea(
            minimum: EdgeInsets.fromLTRB(
              r.scale(20),
              r.scale(10),
              r.scale(20),
              r.scale(12),
            ),
            child: SizedBox(
              width: double.infinity,
              height: r.scale(54),
              child: FilledButton(
                onPressed: hasCode
                    ? () {
                        HapticFeedback.lightImpact();
                        referral.shareReferral();
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : AppColors.primary,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.35,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.scale(28)),
                  ),
                  textStyle: TextStyle(
                    fontSize: r.scale(16),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('Invite friends'),
              ),
            ),
          ),
        );
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
    final line = AppColors.borderOf(context).withValues(alpha: 0.85);
    final codeFill = isDark ? AppColors.darkCard : AppColors.cardOf(context);

    return Obx(() {
      final code = referral.referralCode;
      final friends = referral.successfulReferralCount;
      final coins = referral.referralCoinsEarned;
      final hasCode = code.isNotEmpty;
      final joins =
          referral.info.value?.recentJoins ?? const <ReferralJoinEvent>[];
      final history = _historyPreview(joins, friends: friends, coins: coins);

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => referral.retryReferralInfo(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(
            r.scale(20),
            r.scale(2),
            r.scale(20),
            r.scale(28),
          ),
          children: [
            Text(
              'Invite friends',
              style: TextStyle(
                fontSize: r.scale(28),
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1.15,
                color: textPrimary,
              ),
            ),
            SizedBox(height: r.scale(8)),
            Text(
              'Earn ${InviteFriendsView._coinsPerFriend} coins for every '
              'friend who joins with your code.',
              style: TextStyle(
                fontSize: r.scale(14),
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
            SizedBox(height: r.scale(26)),
            Text(
              'Your referral code',
              style: TextStyle(
                fontSize: r.scale(13),
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
            SizedBox(height: r.scale(10)),
            Container(
              padding: EdgeInsets.fromLTRB(
                r.scale(16),
                r.scale(10),
                r.scale(10),
                r.scale(10),
              ),
              decoration: BoxDecoration(
                color: codeFill,
                borderRadius: BorderRadius.circular(r.scale(14)),
                border: Border.all(color: line),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowColor,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      hasCode ? code : '—',
                      style: TextStyle(
                        fontSize: r.scale(22),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  _CopyChip(
                    enabled: hasCode,
                    onCopy: referral.copyReferralCode,
                  ),
                ],
              ),
            ),
            SizedBox(height: r.scale(26)),
            Divider(height: 1, thickness: 1, color: line),
            Padding(
              padding: EdgeInsets.symmetric(vertical: r.scale(18)),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _StatBlock(
                        value: '$friends',
                        label: 'Friends joined',
                      ),
                    ),
                    VerticalDivider(width: 1, thickness: 1, color: line),
                    Expanded(
                      child: _StatBlock(
                        value: _formatCount(coins),
                        label: 'Coins earned',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: line),
            SizedBox(height: r.scale(22)),
            Row(
              children: [
                Text(
                  'Coin history',
                  style: TextStyle(
                    fontSize: r.scale(17),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: textPrimary,
                  ),
                ),
                const Spacer(),
                if (history.isNotEmpty)
                  GestureDetector(
                    onTap: () => Get.toNamed(AppRoutes.coinHistory),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: r.scale(4),
                        horizontal: r.scale(2),
                      ),
                      child: Text(
                        'View all',
                        style: TextStyle(
                          fontSize: r.scale(13),
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (history.isEmpty)
              _EmptyHistory(onInvite: hasCode ? referral.shareReferral : null)
            else ...[
              SizedBox(height: r.scale(4)),
              for (var i = 0; i < history.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: line),
                _HistoryRow(event: history[i]),
              ],
            ],
          ],
        ),
      );
    });
  }

  /// Join credits only — never voucher / spend rows.
  List<_HistoryDisplay> _historyPreview(
    List<ReferralJoinEvent> joins, {
    required int friends,
    required int coins,
  }) {
    if (joins.isNotEmpty) {
      return joins
          .take(5)
          .map(
            (e) => _HistoryDisplay(
              title: '${e.name} joined',
              when: _formatWhen(e.joinedAt),
              amount: e.coins,
            ),
          )
          .toList(growable: false);
    }

    if (friends <= 0 || coins <= 0) return const [];
    return [
      _HistoryDisplay(
        title: friends == 1 ? 'Friend joined' : '$friends friends joined',
        when: 'Referral rewards',
        amount: coins,
      ),
    ];
  }

  String _formatWhen(DateTime? at) {
    if (at == null) return 'Recently';
    final now = DateTime.now();
    final day = DateTime(at.year, at.month, at.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMM d').format(at);
  }

  String _formatCount(int value) => NumberFormat('#,###').format(value);
}

class _CopyChip extends StatefulWidget {
  const _CopyChip({required this.enabled, required this.onCopy});

  final bool enabled;
  final Future<void> Function() onCopy;

  @override
  State<_CopyChip> createState() => _CopyChipState();
}

class _CopyChipState extends State<_CopyChip> {
  bool _copied = false;

  Future<void> _handle() async {
    if (!widget.enabled || _copied) return;
    HapticFeedback.selectionClick();
    await widget.onCopy();
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final isDark = AppColors.isDark(context);
    final fill = _copied
        ? AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.14)
        : (isDark ? const Color(0xFF3A3A3C) : AppColors.surfaceOf(context));
    final labelColor = !widget.enabled
        ? AppColors.textSecondaryOf(context)
        : _copied
            ? AppColors.primaryDark
            : AppColors.textPrimaryOf(context);

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(r.scale(10)),
      child: InkWell(
        onTap: widget.enabled ? _handle : null,
        borderRadius: BorderRadius.circular(r.scale(10)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(14),
            vertical: r.scale(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_copied) ...[
                Icon(
                  Icons.check_rounded,
                  size: r.scale(16),
                  color: labelColor,
                ),
                SizedBox(width: r.scale(4)),
              ],
              Text(
                _copied ? 'Copied' : 'Copy',
                style: TextStyle(
                  fontSize: r.scale(14),
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({this.onInvite});

  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final secondary = AppColors.textSecondaryOf(context);

    return Padding(
      padding: EdgeInsets.only(top: r.scale(14)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          r.scale(16),
          r.scale(18),
          r.scale(16),
          r.scale(16),
        ),
        decoration: BoxDecoration(
          color: AppColors.isDark(context)
              ? AppColors.darkCard
              : AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(r.scale(14)),
          border: Border.all(
            color: AppColors.borderOf(context).withValues(alpha: 0.8),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: r.scale(28),
              color: secondary,
            ),
            SizedBox(height: r.scale(10)),
            Text(
              'No friends have joined yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: r.scale(14),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            SizedBox(height: r.scale(4)),
            Text(
              'Share your code and earn '
              '${InviteFriendsView._coinsPerFriend} coins for each friend.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: r.scale(12),
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: secondary,
              ),
            ),
            if (onInvite != null) ...[
              SizedBox(height: r.scale(12)),
              TextButton(
                onPressed: onInvite,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  padding: EdgeInsets.symmetric(horizontal: r.scale(12)),
                ),
                child: Text(
                  'Share code',
                  style: TextStyle(
                    fontSize: r.scale(13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryDisplay {
  const _HistoryDisplay({
    required this.title,
    required this.when,
    required this.amount,
  });

  final String title;
  final String when;
  final int amount;
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.scale(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: r.scale(28),
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.1,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          SizedBox(height: r.scale(4)),
          Text(
            label,
            style: TextStyle(
              fontSize: r.scale(13),
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.event});

  final _HistoryDisplay event;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.scale(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    fontSize: r.scale(15),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                SizedBox(height: r.scale(3)),
                Text(
                  event.when,
                  style: TextStyle(
                    fontSize: r.scale(12),
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${NumberFormat('#,###').format(event.amount)}',
            style: TextStyle(
              fontSize: r.scale(15),
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
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
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: AppColors.primary,
            ),
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
            Icon(
              Icons.wifi_off_rounded,
              size: r.scale(32),
              color: AppColors.textSecondaryOf(context),
            ),
            SizedBox(height: r.scale(12)),
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
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.scale(12)),
                ),
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
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
