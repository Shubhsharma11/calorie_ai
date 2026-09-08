import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/buddy_assets.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';
import '../widgets/responsive_page.dart';

/// Streak merch gifts — selecting a gift swaps Buddy to that outfit.
class BuddyGiftsView extends StatefulWidget {
  const BuddyGiftsView({super.key});

  @override
  State<BuddyGiftsView> createState() => _BuddyGiftsViewState();
}

class _BuddyGiftsViewState extends State<BuddyGiftsView> {
  static const _gifts = <_StreakGift>[
    _StreakGift(
      title: 'Shaker',
      requirement: '7 days',
      image: 'assets/image/buddy/gift_shaker.png',
      pose: BuddyGiftPose.shaker,
      locked: false,
    ),
    _StreakGift(
      title: 'T-Shirt',
      requirement: '30 days',
      image: 'assets/image/buddy/gift_tshirt.png',
      pose: BuddyGiftPose.tshirt,
      locked: true,
    ),
    _StreakGift(
      title: 'Cap',
      requirement: '60 days',
      image: 'assets/image/buddy/gift_cap.png',
      pose: BuddyGiftPose.cap,
      locked: true,
    ),
    _StreakGift(
      title: 'Bottle',
      requirement: '14 days',
      image: 'assets/image/buddy/gift_bottle.png',
      pose: BuddyGiftPose.bottle,
      locked: true,
    ),
    _StreakGift(
      title: 'Stickers',
      requirement: '3 days',
      image: 'assets/image/buddy/gift_stickers.png',
      pose: BuddyGiftPose.stickers,
      locked: true,
    ),
    _StreakGift(
      title: 'Hoodie',
      requirement: '100 days',
      image: 'assets/image/buddy/gift_hoodie.png',
      pose: BuddyGiftPose.hoodie,
      locked: true,
    ),
  ];

  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _gifts.indexWhere((g) => !g.locked);
    if (_selectedIndex < 0) _selectedIndex = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final gender = Get.find<UserController>().user.gender;
      for (final gift in _gifts) {
        precacheImage(
          AssetImage(BuddyAssets.giftPose(gender, gift.pose)),
          context,
        );
        precacheImage(AssetImage(gift.image), context);
      }
    });
  }

  _StreakGift get _selected => _gifts[_selectedIndex];

  void _selectGift(int index) {
    setState(() => _selectedIndex = index);
    final gift = _gifts[index];
    if (gift.locked) {
      Get.snackbar(
        'Still locked',
        'Keep logging — unlock after ${gift.requirement}.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    AppColors.syncFromContext(context);
    final unlocked = _gifts.where((g) => !g.locked).length;

    return GetBuilder<UserController>(
      builder: (userCtrl) {
        final gender = userCtrl.user.gender;
        final buddyAsset =
            BuddyAssets.giftPose(gender, _selected.pose);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                const _GiftsHeader(),
                Expanded(
                  child: ResponsivePage(
                    scrollable: true,
                    padding: EdgeInsets.fromLTRB(
                      r.pagePadding.left,
                      r.scale(8),
                      r.pagePadding.right,
                      r.pagePadding.bottom + r.scale(28),
                    ),
                    child: Column(
                      children: [
                        _BuddyHero(
                          asset: buddyAsset,
                          label: _selected.title,
                        ),
                        SizedBox(height: r.scale(18)),
                        Text(
                          'Keep your streak to unlock achievements',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: r.scale(20, tablet: 22),
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.25,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: r.scale(14)),
                        _ProgressPill(
                          unlocked: unlocked,
                          total: _gifts.length,
                        ),
                        SizedBox(height: r.scale(28)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'STREAK ACHIEVEMENTS',
                            style: TextStyle(
                              fontSize: r.scale(12),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        SizedBox(height: r.scale(12)),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const columns = 3;
                            final gap = r.scale(10);
                            final cardWidth = (constraints.maxWidth -
                                    gap * (columns - 1)) /
                                columns;
                            return Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: [
                                for (var i = 0; i < _gifts.length; i++)
                                  SizedBox(
                                    width: cardWidth,
                                    child: _GiftCard(
                                      gift: _gifts[i],
                                      selected: i == _selectedIndex,
                                      onTap: () => _selectGift(i),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
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
}

class _GiftsHeader extends StatelessWidget {
  const _GiftsHeader();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.scale(12),
        r.scale(4),
        r.scale(12),
        r.scale(4),
      ),
      child: SizedBox(
        height: r.scale(44),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: AppColors.card,
                shape: const CircleBorder(),
                elevation: 0,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Get.back<void>(),
                  child: SizedBox(
                    width: r.scale(40),
                    height: r.scale(40),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: r.scale(28),
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            Text(
              'Achievements',
              style: TextStyle(
                fontSize: r.scale(17),
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Buddy floats on the page — soft glow + ground shadow, no box frame.
class _BuddyHero extends StatelessWidget {
  const _BuddyHero({
    required this.asset,
    required this.label,
  });

  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final height = r.scale(200, tablet: 240);
    final isDark = AppColors.isDark(context);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: height * 0.08,
            child: Container(
              width: height * 0.92,
              height: height * 0.72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(
                      alpha: isDark ? 0.18 : 0.14,
                    ),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: height * 0.02,
            child: Container(
              width: height * 0.42,
              height: height * 0.06,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDark ? 0.35 : 0.12,
                    ),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final fade = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              );
              final scale = Tween<double>(begin: 0.92, end: 1).animate(fade);
              return FadeTransition(
                opacity: fade,
                child: ScaleTransition(scale: scale, child: child),
              );
            },
            child: Image.asset(
              asset,
              key: ValueKey(asset),
              height: height * 0.94,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              semanticLabel: 'Buddy with $label',
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({
    required this.unlocked,
    required this.total,
  });

  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(16),
        vertical: r.scale(10),
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: r.scale(18),
            color: AppColors.primary,
          ),
          SizedBox(width: r.scale(8)),
          Text(
            '$unlocked of $total unlocked',
            style: TextStyle(
              fontSize: r.scale(13),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakGift {
  const _StreakGift({
    required this.title,
    required this.requirement,
    required this.image,
    required this.pose,
    required this.locked,
  });

  final String title;
  final String requirement;
  final String image;
  final BuddyGiftPose pose;
  final bool locked;
}

class _GiftCard extends StatelessWidget {
  const _GiftCard({
    required this.gift,
    required this.selected,
    required this.onTap,
  });

  final _StreakGift gift;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final radius = r.scale(16);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: selected ? 0.08 : 0.05,
                ),
                blurRadius: selected ? 16 : 12,
                offset: const Offset(0, 4),
              ),
            ],  
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              r.scale(8),
              r.scale(12),
              r.scale(8),
              r.scale(10),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: r.scale(56),
                  width: r.scale(56),
                  child: Opacity(
                    opacity: gift.locked && !selected ? 0.72 : 1,
                    child: Image.asset(
                      gift.image,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                SizedBox(height: r.scale(8)),
                Text(
                  gift.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.scale(13),
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.15,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: r.scale(3)),
                Text(
                  gift.requirement,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.scale(11),
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: r.scale(6)),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    gift.locked
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded,
                    size: r.scale(14),
                    color: gift.locked
                        ? AppColors.textSecondary
                        : AppColors.primary,
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
