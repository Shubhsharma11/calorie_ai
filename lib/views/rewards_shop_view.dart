import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/rewards_controller.dart';
import '../controllers/tracker_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/coin_claim_lottery_dialog.dart';
import '../widgets/steps_claim_banner.dart';

/// Gift shop grid: unlock products, then see them in My gifts.
class RewardsShopView extends StatelessWidget {
  const RewardsShopView({super.key});

  /// Flip to `true` when gift shipping / unlocks go live.
  static const _shopLive = false;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    if (!Get.isRegistered<RewardsController>()) {
      Get.put(RewardsController(), permanent: true);
    }
    final rewards = Get.find<RewardsController>();

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppAppBar(
        title: 'Gift Shop',
        actions: [
          Padding(
            padding: EdgeInsets.only(right: r.scale(12)),
            child: const CoinBalanceChip(
              onTap: StepsClaimBanner.openCoinHistory,
            ),
          ),
        ],
      ),
      body: _shopLive
          ? _RewardsShopBody(rewards: rewards)
          : const _GiftShopComingSoon(),
    );
  }
}

/// Same shop look as live, with a teaser grid locked behind Coming Soon.
class _GiftShopComingSoon extends StatelessWidget {
  const _GiftShopComingSoon();

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final isDark = AppColors.isDark(context);
    final card = isDark ? AppColors.darkCard : Colors.white;
    final muted = AppColors.textSecondaryOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final catalog = RewardsController.catalog;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              r.scale(16),
              r.scale(8),
              r.scale(16),
              r.scale(8),
            ),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                r.scale(18),
                r.scale(18),
                r.scale(18),
                r.scale(16),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [
                          Color(0xFF1A2E22),
                          Color(0xFF243528),
                          Color(0xFF1C1C1E),
                        ]
                      : const [
                          Color(0xFFE8F8EE),
                          Color(0xFFF4FAF6),
                          Color(0xFFFFF8E8),
                        ],
                ),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(
                      alpha: isDark ? 0.12 : 0.1,
                    ),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: r.scale(10),
                                vertical: r.scale(4),
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'COMING SOON',
                                style: TextStyle(
                                  fontSize: r.scale(10),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(height: r.scale(8)),
                            Text(
                              'Gifts are on the way',
                              style: TextStyle(
                                fontSize: r.scale(18),
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                                letterSpacing: -0.3,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: r.scale(10)),
                      SvgPicture.asset(
                        'assets/image/giftbox.svg',
                        width: r.scale(72),
                        height: r.scale(72),
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                  SizedBox(height: r.scale(12)),
                  Text(
                    'Sneak peek below — unlock hoodies, bottles, and more with '
                    'coins once the shop goes live.',
                    style: TextStyle(
                      fontSize: r.scale(13.5),
                      fontWeight: FontWeight.w500,
                      color: muted,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: r.scale(14)),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(r.scale(12)),
                    decoration: BoxDecoration(
                      color: card.withValues(alpha: isDark ? 0.55 : 0.85),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.borderOf(context).withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.monetization_on_rounded,
                          color: const Color(0xFFE6A800),
                          size: r.scale(22),
                        ),
                        SizedBox(width: r.scale(10)),
                        Expanded(
                          child: Text(
                            'Keep collecting coins on Home — your balance stays ready.',
                            style: TextStyle(
                              fontSize: r.scale(12.5),
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              r.scale(20),
              r.scale(10),
              r.scale(20),
              r.scale(10),
            ),
            child: Row(
              children: [
                Text(
                  'Preview gifts',
                  style: TextStyle(
                    fontSize: r.scale(16),
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                SizedBox(width: r.scale(8)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.scale(8),
                    vertical: r.scale(3),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Locked',
                    style: TextStyle(
                      fontSize: r.scale(11),
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            r.scale(16),
            0,
            r.scale(16),
            r.scale(28),
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: r.scale(14),
              crossAxisSpacing: r.scale(14),
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = catalog[index];
                return _ComingSoonProductCard(item: item);
              },
              childCount: catalog.length,
            ),
          ),
        ),
      ],
    );
  }
}

/// Teaser product card — looks like the shop, but not unlockable yet.
class _ComingSoonProductCard extends StatelessWidget {
  const _ComingSoonProductCard({required this.item});

  final RewardShopItem item;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final isDark = AppColors.isDark(context);
    final card = isDark ? AppColors.darkCard : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        r.scale(12),
        r.scale(14),
        r.scale(12),
        r.scale(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: 0.55,
                  child: Center(
                    child: item.imageAsset != null
                        ? Image.asset(
                            item.imageAsset!,
                            fit: BoxFit.contain,
                            height: r.scale(88),
                          )
                        : Icon(
                            item.icon,
                            size: r.scale(56),
                            color: item.accent,
                          ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: r.scale(28),
                    height: r.scale(28),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF3A3A3C)
                          : const Color(0xFFF0F0F3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: r.scale(14),
                      color: isDark
                          ? const Color(0xFF98989F)
                          : const Color(0xFF6C6C70),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.scale(8)),
          Text(
            item.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.scale(13),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryOf(context),
              height: 1.2,
            ),
          ),
          SizedBox(height: r.scale(4)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.monetization_on_rounded,
                size: r.scale(14),
                color: const Color(0xFFE6A800).withValues(alpha: 0.7),
              ),
              SizedBox(width: r.scale(3)),
              Text(
                '${item.cost}',
                style: TextStyle(
                  fontSize: r.scale(12),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
          SizedBox(height: r.scale(10)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: r.scale(9)),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF3A3A3C)
                  : const Color(0xFFF0F0F3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Coming soon',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: r.scale(12),
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFF98989F)
                    : const Color(0xFF6C6C70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardsShopBody extends StatelessWidget {
  const _RewardsShopBody({required this.rewards});

  final RewardsController rewards;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Obx(() {
        if (Get.isRegistered<TrackerController>()) {
          Get.find<TrackerController>().activityRevision.value;
        }
        final balance = rewards.balance.value;
        final pending = rewards.pendingCoins;
        final canClaim = rewards.canClaimToday;
        final claimed = rewards.hasClaimedToday;
        final claiming = rewards.isClaiming.value;
        final unlocked = rewards.unlockedIds.toSet();
        final unlocking = rewards.unlockingId.value;
        final owned = rewards.ownedItems;
        // Touch reactive maps so Obx rebuilds on unlock / shipping updates.
        rewards.unlockedAtById.length;
        rewards.shippingByItemId.length;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  r.scale(20),
                  r.scale(8),
                  r.scale(20),
                  r.scale(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (canClaim || claiming) ...[
                      _ClaimBanner(
                        pending: pending,
                        canClaim: canClaim,
                        claimed: claimed,
                        claiming: claiming,
                        onClaim: () async {
                          HapticFeedback.mediumImpact();
                          final claimedAmount = rewards.pendingCoins;
                          final ok = await rewards.claimDailyStepReward();
                          if (ok) {
                            await CoinClaimLotteryDialog.show(
                              coins: claimedAmount,
                            );
                          }
                        },
                      ),
                      SizedBox(height: r.scale(18)),
                    ],
                    if (owned.isNotEmpty) ...[
                      Text(
                        'My gifts',
                        style: TextStyle(
                          fontSize: r.scale(16),
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                      SizedBox(height: r.scale(10)),
                      SizedBox(
                        height: r.scale(96),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: owned.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(width: r.scale(10)),
                          itemBuilder: (context, index) {
                            final item = owned[index];
                            final stage = rewards.deliveryStage(item.id);
                            final hasAddress = rewards.hasShipping(item.id);
                            return _MyGiftChip(
                              item: item,
                              stage: stage,
                              needsAddress: !hasAddress,
                              onTap: () => _showDeliveryTrackingSheet(
                                context,
                                rewards: rewards,
                                item: item,
                                stage: stage,
                                unlockedAt: rewards.unlockedAt(item.id),
                                eta: rewards.estimatedDelivery(item.id),
                                shipping: rewards.shippingFor(item.id),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: r.scale(20)),
                    ],
                    Text(
                      'Products',
                      style: TextStyle(
                        fontSize: r.scale(16),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                    SizedBox(height: r.scale(10)),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                r.scale(16),
                0,
                r.scale(16),
                r.scale(28),
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: r.scale(14),
                  crossAxisSpacing: r.scale(14),
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = RewardsController.catalog[index];
                    final isOwned = unlocked.contains(item.id);
                    final canAfford = balance >= item.cost;
                    final locked = !isOwned && !canAfford;
                    return _GiftProductCard(
                      item: item,
                      owned: isOwned,
                      locked: locked,
                      unlocking: unlocking == item.id,
                      onOwnedTap: isOwned
                          ? () => _showDeliveryTrackingSheet(
                                context,
                                rewards: rewards,
                                item: item,
                                stage: rewards.deliveryStage(item.id),
                                unlockedAt: rewards.unlockedAt(item.id),
                                eta: rewards.estimatedDelivery(item.id),
                                shipping: rewards.shippingFor(item.id),
                              )
                          : null,
                      onUnlock: () async {
                        HapticFeedback.selectionClick();
                        final shipping = await _showShippingCheckoutSheet(
                          context,
                          rewards: rewards,
                          item: item,
                        );
                        if (shipping == null || !context.mounted) return;
                        final error = await rewards.unlockItem(
                          item.id,
                          shipping: shipping,
                        );
                        if (!context.mounted) return;
                        if (error == null) {
                          await _showUnlockedSheet(
                            context,
                            item,
                            shipping: shipping,
                            rewards: rewards,
                          );
                        } else {
                          AppSnackbar.error(error, title: 'Can’t unlock');
                        }
                      },
                    );
                  },
                  childCount: RewardsController.catalog.length,
                ),
              ),
            ),
          ],
        );
    });
  }
}

Future<GiftShippingAddress?> _showShippingCheckoutSheet(
  BuildContext context, {
  required RewardsController rewards,
  required RewardShopItem item,
  GiftShippingAddress? initial,
  String confirmLabel = 'Place order',
  bool showOrderSummary = true,
}) {
  final prefill = initial ?? rewards.checkoutPrefill();
  return showModalBottomSheet<GiftShippingAddress>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _ShippingCheckoutSheet(
      item: item,
      prefill: prefill,
      confirmLabel: confirmLabel,
      showHandle: true,
      showOrderSummary: showOrderSummary,
      balance: rewards.balance.value,
      onSubmit: (address) => Navigator.of(ctx).pop(address),
    ),
  );
}

class _ShippingCheckoutSheet extends StatefulWidget {
  const _ShippingCheckoutSheet({
    super.key,
    required this.item,
    required this.prefill,
    required this.confirmLabel,
    required this.onSubmit,
    this.onCancel,
    this.showHandle = true,
    this.showOrderSummary = false,
    this.balance,
  });

  final RewardShopItem item;
  final GiftShippingAddress prefill;
  final String confirmLabel;
  final ValueChanged<GiftShippingAddress> onSubmit;
  final VoidCallback? onCancel;
  final bool showHandle;
  final bool showOrderSummary;
  final int? balance;

  @override
  State<_ShippingCheckoutSheet> createState() => _ShippingCheckoutSheetState();
}

class _ShippingCheckoutSheetState extends State<_ShippingCheckoutSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _lineCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _pinCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.prefill.fullName);
    _phoneCtrl = TextEditingController(text: widget.prefill.phone);
    _lineCtrl = TextEditingController(text: widget.prefill.line1);
    _cityCtrl = TextEditingController(text: widget.prefill.city);
    _pinCtrl = TextEditingController(text: widget.prefill.pincode);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _lineCtrl.dispose();
    _cityCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final address = GiftShippingAddress(
      fullName: _nameCtrl.text,
      phone: _phoneCtrl.text,
      line1: _lineCtrl.text,
      city: _cityCtrl.text,
      pincode: _pinCtrl.text,
    );
    final error = address.validate();
    if (error != null) {
      AppSnackbar.error(error, title: 'Check details');
      return;
    }
    widget.onSubmit(address);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final item = widget.item;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            r.scale(20),
            r.scale(widget.showHandle ? 12 : 4),
            r.scale(20),
            r.scale(20),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showHandle) ...[
                  Center(
                    child: Container(
                      width: r.scale(40),
                      height: r.scale(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  SizedBox(height: r.scale(16)),
                ],
                Row(
                  children: [
                    if (widget.onCancel != null) ...[
                      IconButton(
                        onPressed: widget.onCancel,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: r.scale(36),
                          minHeight: r.scale(36),
                        ),
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: r.scale(18),
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                      SizedBox(width: r.scale(4)),
                    ],
                    if (item.imageAsset != null)
                      Image.asset(
                        item.imageAsset!,
                        height: r.scale(44),
                        fit: BoxFit.contain,
                      )
                    else
                      Icon(item.icon, color: item.accent, size: 36),
                    SizedBox(width: r.scale(10)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery details',
                            style: TextStyle(
                              fontSize: r.scale(18),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                          Text(
                            'Where should we send ${item.name}?',
                            style: TextStyle(
                              fontSize: r.scale(12.5),
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.scale(16)),
                if (widget.showOrderSummary) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(r.scale(12)),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: r.scale(13.5),
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1C1C1E),
                                ),
                              ),
                            ),
                            RewardCoinIcon(size: r.scale(14)),
                            SizedBox(width: r.scale(4)),
                            Text(
                              '${item.cost}',
                              style: TextStyle(
                                fontSize: r.scale(13.5),
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1C1C1E),
                              ),
                            ),
                          ],
                        ),
                        if (widget.balance != null) ...[
                          SizedBox(height: r.scale(6)),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Balance after order',
                                  style: TextStyle(
                                    fontSize: r.scale(12),
                                    color: const Color(0xFF8E8E93),
                                  ),
                                ),
                              ),
                              Text(
                                '${widget.balance! - item.cost}',
                                style: TextStyle(
                                  fontSize: r.scale(12.5),
                                  fontWeight: FontWeight.w700,
                                  color: widget.balance! >= item.cost
                                      ? const Color(0xFF1B8F3A)
                                      : const Color(0xFFFF3B30),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: r.scale(14)),
                ],
                _ShippingField(
                  controller: _nameCtrl,
                  label: 'Full name',
                  hint: 'Receiver’s name',
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    final name = (v ?? '').trim();
                    if (name.length < 2) return 'Enter full name';
                    if (!RegExp(r'^[A-Za-z][A-Za-z .]{1,48}$').hasMatch(name)) {
                      return 'Use letters only';
                    }
                    return null;
                  },
                ),
                SizedBox(height: r.scale(10)),
                _ShippingField(
                  controller: _phoneCtrl,
                  label: 'Phone number',
                  hint: '10-digit mobile',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (v) {
                    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    if (digits.length != 10) {
                      return 'Enter a 10-digit phone number';
                    }
                    return null;
                  },
                ),
                SizedBox(height: r.scale(10)),
                _ShippingField(
                  controller: _lineCtrl,
                  label: 'Address',
                  hint: 'House / street / landmark',
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  validator: (v) {
                    if ((v ?? '').trim().length < 8) {
                      return 'Enter a complete address';
                    }
                    return null;
                  },
                ),
                SizedBox(height: r.scale(10)),
                Row(
                  children: [
                    Expanded(
                      child: _ShippingField(
                        controller: _cityCtrl,
                        label: 'City',
                        hint: 'City',
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) {
                          final city = (v ?? '').trim();
                          if (city.length < 2 ||
                              !RegExp(r'^[A-Za-z][A-Za-z .]{1,40}$')
                                  .hasMatch(city)) {
                            return 'Valid city';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(width: r.scale(10)),
                    Expanded(
                      child: _ShippingField(
                        controller: _pinCtrl,
                        label: 'PIN code',
                        hint: '6 digits',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: (v) {
                          if (!RegExp(r'^\d{6}$').hasMatch((v ?? '').trim())) {
                            return '6 digits';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.scale(8)),
                Text(
                  'We’ll ship to this address. You can change it from My gifts until it’s out for delivery.',
                  style: TextStyle(
                    fontSize: r.scale(11.5),
                    color: const Color(0xFF8E8E93),
                    height: 1.35,
                  ),
                ),
                SizedBox(height: r.scale(16)),
                SizedBox(
                  width: double.infinity,
                  height: r.scale(50),
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      widget.confirmLabel,
                      style: TextStyle(
                        fontSize: r.scale(15),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShippingField extends StatelessWidget {
  const _ShippingField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.validator,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: r.scale(12),
            fontWeight: FontWeight.w700,
            color: const Color(0xFF636366),
          ),
        ),
        SizedBox(height: r.scale(6)),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          textCapitalization: textCapitalization,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF2F2F7),
            contentPadding: EdgeInsets.symmetric(
              horizontal: r.scale(14),
              vertical: r.scale(12),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          style: TextStyle(
            fontSize: r.scale(14),
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1C1C1E),
          ),
        ),
      ],
    );
  }
}

Future<void> _showUnlockedSheet(
  BuildContext context,
  RewardShopItem item, {
  required GiftShippingAddress shipping,
  required RewardsController rewards,
}) async {
  final r = context.responsive;
  final orderId = rewards.orderId(item.id);
  final eta = rewards.estimatedDelivery(item.id);
  final dateFmt = DateFormat('d MMM');

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            r.scale(20),
            r.scale(12),
            r.scale(20),
            r.scale(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: r.scale(40),
                height: r.scale(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              SizedBox(height: r.scale(16)),
              if (item.imageAsset != null)
                Image.asset(
                  item.imageAsset!,
                  height: r.scale(88),
                  fit: BoxFit.contain,
                )
              else
                Icon(item.icon, size: r.scale(64), color: item.accent),
              SizedBox(height: r.scale(12)),
              Text(
                'Order placed',
                style: TextStyle(
                  fontSize: r.scale(18),
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              SizedBox(height: r.scale(4)),
              Text(
                'Order ID $orderId',
                style: TextStyle(
                  fontSize: r.scale(12.5),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8E8E93),
                ),
              ),
              if (eta != null) ...[
                SizedBox(height: r.scale(4)),
                Text(
                  'Arriving by ${dateFmt.format(eta)}',
                  style: TextStyle(
                    fontSize: r.scale(13),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1B8F3A),
                  ),
                ),
              ],
              SizedBox(height: r.scale(12)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(r.scale(12)),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shipping.fullName,
                      style: TextStyle(
                        fontSize: r.scale(13),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                    SizedBox(height: r.scale(2)),
                    Text(
                      shipping.phoneDisplay,
                      style: TextStyle(
                        fontSize: r.scale(12.5),
                        color: const Color(0xFF636366),
                      ),
                    ),
                    SizedBox(height: r.scale(4)),
                    Text(
                      shipping.oneLine,
                      style: TextStyle(
                        fontSize: r.scale(12.5),
                        color: const Color(0xFF636366),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.scale(16)),
              SizedBox(
                width: double.infinity,
                height: r.scale(48),
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showDeliveryTrackingSheet(
                      context,
                      rewards: rewards,
                      item: item,
                      stage: rewards.deliveryStage(item.id),
                      unlockedAt: rewards.unlockedAt(item.id),
                      eta: rewards.estimatedDelivery(item.id),
                      shipping: rewards.shippingFor(item.id),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Track order',
                    style: TextStyle(
                      fontSize: r.scale(15),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _showDeliveryTrackingSheet(
  BuildContext context, {
  required RewardsController rewards,
  required RewardShopItem item,
  required GiftDeliveryStage stage,
  required DateTime? unlockedAt,
  required DateTime? eta,
  required GiftShippingAddress? shipping,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _GiftOrderSheet(
      rewards: rewards,
      item: item,
      stage: stage,
      unlockedAt: unlockedAt,
      eta: eta,
      shipping: shipping,
    ),
  );
}

class _GiftOrderSheet extends StatefulWidget {
  const _GiftOrderSheet({
    required this.rewards,
    required this.item,
    required this.stage,
    required this.unlockedAt,
    required this.eta,
    required this.shipping,
  });

  final RewardsController rewards;
  final RewardShopItem item;
  final GiftDeliveryStage stage;
  final DateTime? unlockedAt;
  final DateTime? eta;
  final GiftShippingAddress? shipping;

  @override
  State<_GiftOrderSheet> createState() => _GiftOrderSheetState();
}

class _GiftOrderSheetState extends State<_GiftOrderSheet> {
  late GiftDeliveryStage _stage = widget.stage;
  late DateTime? _eta = widget.eta;
  late GiftShippingAddress? _shipping = widget.shipping;
  bool _editingAddress = false;
  bool _saving = false;

  bool get _hasAddress => _shipping != null && _shipping!.isComplete;

  bool get _canChangeAddress =>
      _hasAddress && widget.rewards.canEditShipping(widget.item.id);

  Future<void> _saveAddress(GiftShippingAddress address) async {
    if (_saving) return;
    setState(() => _saving = true);
    final error = await widget.rewards.saveShippingForItem(
      widget.item.id,
      address,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      AppSnackbar.error(error, title: 'Address');
      return;
    }
    setState(() {
      _shipping = address;
      _stage = widget.rewards.deliveryStage(widget.item.id);
      _eta = widget.rewards.estimatedDelivery(widget.item.id);
      _editingAddress = false;
    });
    AppSnackbar.success('Delivery address updated.', title: 'Updated');
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final dateFmt = DateFormat('d MMM');
    final stages = GiftDeliveryStage.values;
    final item = widget.item;

    return SafeArea(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: _editingAddress
            ? _ShippingCheckoutSheet(
                key: ValueKey(
                  'edit-${_shipping?.fullName}-${_shipping?.phone}',
                ),
                item: item,
                prefill: _shipping ?? widget.rewards.checkoutPrefill(),
                confirmLabel: _hasAddress
                    ? (_saving ? 'Saving…' : 'Update address')
                    : (_saving ? 'Saving…' : 'Save & start shipping'),
                showHandle: true,
                showOrderSummary: false,
                onCancel: _saving
                    ? null
                    : () => setState(() => _editingAddress = false),
                onSubmit: _saveAddress,
              )
            : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  r.scale(20),
                  r.scale(12),
                  r.scale(20),
                  r.scale(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: r.scale(40),
                        height: r.scale(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E5EA),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    SizedBox(height: r.scale(16)),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: r.scale(56),
                            height: r.scale(56),
                            child: item.imageAsset != null
                                ? Image.asset(
                                    item.imageAsset!,
                                    fit: BoxFit.contain,
                                  )
                                : Icon(
                                    item.icon,
                                    color: item.accent,
                                    size: 32,
                                  ),
                          ),
                        ),
                        SizedBox(width: r.scale(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: r.scale(16),
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1C1C1E),
                                ),
                              ),
                              SizedBox(height: r.scale(2)),
                              Text(
                                'Order ID ${widget.rewards.orderId(item.id)}',
                                style: TextStyle(
                                  fontSize: r.scale(11.5),
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF8E8E93),
                                ),
                              ),
                              SizedBox(height: r.scale(4)),
                              Text(
                                _hasAddress
                                    ? _stage.shortLabel
                                    : 'Address needed',
                                style: TextStyle(
                                  fontSize: r.scale(13),
                                  fontWeight: FontWeight.w700,
                                  color: _hasAddress
                                      ? _stage.color
                                      : const Color(0xFFFF9500),
                                ),
                              ),
                              if (_eta != null &&
                                  _stage != GiftDeliveryStage.delivered) ...[
                                SizedBox(height: r.scale(2)),
                                Text(
                                  'Arriving by ${dateFmt.format(_eta!)}',
                                  style: TextStyle(
                                    fontSize: r.scale(12),
                                    color: const Color(0xFF8E8E93),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: r.scale(14)),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Delivering to',
                            style: TextStyle(
                              fontSize: r.scale(14),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                        ),
                        if (_canChangeAddress)
                          TextButton(
                            onPressed: () =>
                                setState(() => _editingAddress = true),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: EdgeInsets.symmetric(
                                horizontal: r.scale(8),
                                vertical: r.scale(4),
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Change',
                              style: TextStyle(
                                fontSize: r.scale(13),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: r.scale(8)),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(r.scale(12)),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(14),
                        border: _hasAddress
                            ? null
                            : Border.all(color: const Color(0xFFFFD60A)),
                      ),
                      child: _hasAddress
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      size: r.scale(18),
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: r.scale(8)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _shipping!.fullName,
                                            style: TextStyle(
                                              fontSize: r.scale(13.5),
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF1C1C1E),
                                            ),
                                          ),
                                          SizedBox(height: r.scale(2)),
                                          Text(
                                            _shipping!.phoneDisplay,
                                            style: TextStyle(
                                              fontSize: r.scale(12.5),
                                              color: const Color(0xFF636366),
                                            ),
                                          ),
                                          SizedBox(height: r.scale(4)),
                                          Text(
                                            _shipping!.oneLine,
                                            style: TextStyle(
                                              fontSize: r.scale(12.5),
                                              color: const Color(0xFF636366),
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (_stage ==
                                        GiftDeliveryStage.outForDelivery ||
                                    _stage == GiftDeliveryStage.delivered) ...[
                                  SizedBox(height: r.scale(8)),
                                  Text(
                                    _stage == GiftDeliveryStage.delivered
                                        ? 'Delivered to this address'
                                        : 'Address locked — gift is out for delivery',
                                    style: TextStyle(
                                      fontSize: r.scale(11.5),
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF8E8E93),
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add your name, phone, and address so we can ship this gift.',
                                  style: TextStyle(
                                    fontSize: r.scale(12.5),
                                    color: const Color(0xFF636366),
                                    height: 1.35,
                                  ),
                                ),
                                SizedBox(height: r.scale(10)),
                                SizedBox(
                                  width: double.infinity,
                                  height: r.scale(42),
                                  child: FilledButton(
                                    onPressed: () => setState(
                                      () => _editingAddress = true,
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'Add delivery address',
                                      style: TextStyle(
                                        fontSize: r.scale(13.5),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    SizedBox(height: r.scale(18)),
                    Text(
                      'Delivery updates',
                      style: TextStyle(
                        fontSize: r.scale(14),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                    SizedBox(height: r.scale(8)),
                    Text(
                      _hasAddress
                          ? _stage.detail
                          : 'Shipping starts after you add a delivery address.',
                      style: TextStyle(
                        fontSize: r.scale(13),
                        color: const Color(0xFF636366),
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: r.scale(12)),
                    ...List.generate(stages.length, (i) {
                      final s = stages[i];
                      final done =
                          _hasAddress && s.stepIndex <= _stage.stepIndex;
                      final current = _hasAddress && s == _stage;
                      final isLast = i == stages.length - 1;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: r.scale(28),
                            child: Column(
                              children: [
                                Container(
                                  width: r.scale(22),
                                  height: r.scale(22),
                                  decoration: BoxDecoration(
                                    color: done
                                        ? s.color
                                        : const Color(0xFFE5E5EA),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    done ? s.icon : Icons.circle,
                                    size: done ? r.scale(13) : r.scale(8),
                                    color: done
                                        ? Colors.white
                                        : const Color(0xFFAEAEB2),
                                  ),
                                ),
                                if (!isLast)
                                  Container(
                                    width: 2,
                                    height: r.scale(28),
                                    margin: EdgeInsets.symmetric(
                                      vertical: r.scale(3),
                                    ),
                                    color: _hasAddress &&
                                            s.stepIndex < _stage.stepIndex
                                        ? const Color(0xFF1B8F3A)
                                        : const Color(0xFFE5E5EA),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(width: r.scale(10)),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: isLast ? 0 : r.scale(4),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.shortLabel,
                                    style: TextStyle(
                                      fontSize: r.scale(13.5),
                                      fontWeight: current
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: done
                                          ? const Color(0xFF1C1C1E)
                                          : const Color(0xFFAEAEB2),
                                    ),
                                  ),
                                  if (current || done) ...[
                                    SizedBox(height: r.scale(2)),
                                    Text(
                                      () {
                                        final when = widget.rewards
                                            .stageDate(item.id, s);
                                        if (when == null) {
                                          return current
                                              ? 'Updated just now'
                                              : '';
                                        }
                                        if (done &&
                                            s.stepIndex < _stage.stepIndex) {
                                          return dateFmt.format(when);
                                        }
                                        if (current) {
                                          return 'Since ${dateFmt.format(when)}';
                                        }
                                        return 'Expected ${dateFmt.format(when)}';
                                      }(),
                                      style: TextStyle(
                                        fontSize: r.scale(11.5),
                                        color: const Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    SizedBox(height: r.scale(8)),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MyGiftChip extends StatelessWidget {
  const _MyGiftChip({
    required this.item,
    required this.stage,
    required this.needsAddress,
    required this.onTap,
  });

  final RewardShopItem item;
  final GiftDeliveryStage stage;
  final bool needsAddress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final statusColor =
        needsAddress ? const Color(0xFFFF9500) : stage.color;
    final statusLabel =
        needsAddress ? 'Add address' : stage.chipLabel;
    final statusIcon =
        needsAddress ? Icons.location_on_rounded : stage.icon;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: r.scale(176),
          padding: EdgeInsets.all(r.scale(10)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: needsAddress
                  ? const Color(0xFFFFE08A)
                  : const Color(0xFFD8F0E0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: r.scale(48),
                  height: r.scale(48),
                  child: item.imageAsset != null
                      ? Image.asset(item.imageAsset!, fit: BoxFit.contain)
                      : Icon(item.icon, color: item.accent),
                ),
              ),
              SizedBox(width: r.scale(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r.scale(12),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1C1C1E),
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: r.scale(4)),
                    Row(
                      children: [
                        Icon(
                          statusIcon,
                          size: r.scale(12),
                          color: statusColor,
                        ),
                        SizedBox(width: r.scale(3)),
                        Expanded(
                          child: Text(
                            statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: r.scale(10.5),
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClaimBanner extends StatelessWidget {
  const _ClaimBanner({
    required this.pending,
    required this.canClaim,
    required this.claimed,
    required this.claiming,
    required this.onClaim,
  });

  final int pending;
  final bool canClaim;
  final bool claimed;
  final bool claiming;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Container(
      padding: EdgeInsets.all(r.scale(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          RewardCoinIcon(size: r.scale(22)),
          SizedBox(width: r.scale(10)),
          Expanded(
            child: Text(
              claimed
                  ? 'Today’s coins are in your balance'
                  : canClaim
                      ? '+$pending coins ready to claim'
                      : 'Walk more to earn claimable coins',
              style: TextStyle(
                fontSize: r.scale(13),
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ),
          if (canClaim)
            TextButton(
              onPressed: claiming ? null : onClaim,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1B8F3A),
                backgroundColor: const Color(0xFFE8F8EE),
                padding: EdgeInsets.symmetric(
                  horizontal: r.scale(14),
                  vertical: r.scale(8),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: claiming
                  ? SizedBox(
                      width: r.scale(14),
                      height: r.scale(14),
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Claim',
                      style: TextStyle(
                        fontSize: r.scale(13),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

class _GiftProductCard extends StatelessWidget {
  const _GiftProductCard({
    required this.item,
    required this.owned,
    required this.locked,
    required this.unlocking,
    required this.onUnlock,
    this.onOwnedTap,
  });

  final RewardShopItem item;
  final bool owned;
  final bool locked;
  final bool unlocking;
  final VoidCallback onUnlock;
  final VoidCallback? onOwnedTap;

  static const _unlockBg = Color(0xFFE8F8EE);
  static const _unlockFg = Color(0xFF1B8F3A);
  static const _lockedBg = Color(0xFFF0F0F3);
  static const _lockedFg = Color(0xFF6C6C70);

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: owned
            ? Border.all(color: const Color(0xFFB7E4C7), width: 1.2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        r.scale(12),
        r.scale(14),
        r.scale(12),
        r.scale(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: item.imageAsset != null
                      ? Image.asset(
                          item.imageAsset!,
                          fit: BoxFit.contain,
                          height: r.scale(88),
                        )
                      : Icon(
                          item.icon,
                          size: r.scale(56),
                          color: item.accent,
                        ),
                ),
                if (owned)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: r.scale(8),
                        vertical: r.scale(4),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B8F3A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'IN MY GIFTS',
                        style: TextStyle(
                          fontSize: r.scale(9),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: r.scale(8)),
          Text(
            item.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.scale(13.5),
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
              height: 1.2,
            ),
          ),
          SizedBox(height: r.scale(6)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RewardCoinIcon(size: r.scale(15)),
              SizedBox(width: r.scale(4)),
              Text(
                '${item.cost} coins',
                style: TextStyle(
                  fontSize: r.scale(12.5),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
            ],
          ),
          SizedBox(height: r.scale(10)),
          SizedBox(
            width: double.infinity,
            height: r.scale(36),
            child: Material(
              color: owned
                  ? _unlockBg
                  : locked
                      ? _lockedBg
                      : _unlockBg,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: unlocking
                    ? null
                    : owned
                        ? onOwnedTap
                        : locked
                            ? null
                            : onUnlock,
                borderRadius: BorderRadius.circular(20),
                child: Center(
                  child: unlocking
                      ? SizedBox(
                          width: r.scale(16),
                          height: r.scale(16),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _unlockFg,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (locked) ...[
                              Icon(
                                Icons.lock_rounded,
                                size: r.scale(14),
                                color: _lockedFg,
                              ),
                              SizedBox(width: r.scale(5)),
                            ],
                            if (owned) ...[
                              Icon(
                                Icons.local_shipping_outlined,
                                size: r.scale(15),
                                color: _unlockFg,
                              ),
                              SizedBox(width: r.scale(4)),
                            ],
                            Text(
                              owned
                                  ? 'Track'
                                  : locked
                                      ? 'Unlock'
                                      : 'Unlock',
                              style: TextStyle(
                                fontSize: r.scale(13),
                                fontWeight: FontWeight.w800,
                                color: owned
                                    ? _unlockFg
                                    : locked
                                        ? _lockedFg
                                        : _unlockFg,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
