import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Lottery-style celebration when the user claims coins.
class CoinClaimLotteryDialog extends StatefulWidget {
  const CoinClaimLotteryDialog({super.key, required this.coins});

  final int coins;

  static const moneyBagAsset = 'assets/image/Money Bag.json';
  static const _barrier = Colors.black54;

  /// Dim status + nav bars to match the dialog barrier so top/bottom
  /// don't stay the bright page color while the middle is darkened.
  static SystemUiOverlayStyle _dimmedOverlayStyle(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final pageBg =
        isDark ? AppColors.darkBackground : AppColors.lightPageBackground;
    final dimmed = Color.alphaBlend(_barrier, pageBg);
    return SystemUiOverlayStyle(
      statusBarColor: dimmed,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: dimmed,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    );
  }

  static Future<void> show({required int coins}) {
    if (coins <= 0) return Future.value();
    final brightness = Get.theme.brightness;
    final dimmedOverlay = _dimmedOverlayStyle(brightness);
    SystemChrome.setSystemUIOverlayStyle(dimmedOverlay);
    return Get.dialog<void>(
      AnnotatedRegion<SystemUiOverlayStyle>(
        value: dimmedOverlay,
        child: CoinClaimLotteryDialog(coins: coins),
      ),
      barrierDismissible: false,
      barrierColor: _barrier,
      useSafeArea: false,
    ).whenComplete(() {
      AppTheme.applySystemUiOverlay(Get.theme.brightness);
    });
  }

  @override
  State<CoinClaimLotteryDialog> createState() => _CoinClaimLotteryDialogState();
}

class _CoinClaimLotteryDialogState extends State<CoinClaimLotteryDialog>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFE6A800);
  static const _goldDark = Color(0xFF9A6700);

  late final AnimationController _entryController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  final _random = math.Random();
  int _displayCoins = 0;
  bool _revealed = false;
  Timer? _spinTimer;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.2, 1, curve: Curves.easeOut),
    );

    _entryController.forward();
    _startLotterySpin();
  }

  void _startLotterySpin() {
    var ticks = 0;
    const totalTicks = 18;
    _spinTimer = Timer.periodic(const Duration(milliseconds: 70), (timer) {
      ticks++;
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (ticks >= totalTicks) {
          _displayCoins = widget.coins;
          _revealed = true;
          timer.cancel();
          HapticFeedback.heavyImpact();
        } else {
          final jitter = 5 + _random.nextInt(math.max(20, widget.coins * 2));
          _displayCoins = jitter;
          if (ticks % 3 == 0) HapticFeedback.selectionClick();
        }
      });
    });
  }

  @override
  void dispose() {
    _spinTimer?.cancel();
    _entryController.dispose();
    super.dispose();
  }

  void _dismiss() => Get.back<void>();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 320,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _revealed ? 'You won!' : 'Drawing…',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _revealed ? AppColors.primary : _goldDark,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: Lottie.asset(
                        CoinClaimLotteryDialog.moneyBagAsset,
                        fit: BoxFit.contain,
                        repeat: true,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Earned amount shown under the money-bag Lottie
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: TextStyle(
                        fontSize: _revealed ? 42 : 34,
                        fontWeight: FontWeight.w900,
                        color: _goldDark,
                        height: 1,
                        letterSpacing: -1,
                      ),
                      child: Text('+$_displayCoins'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _revealed
                          ? 'coins added to your wallet'
                          : 'Spinning your reward…',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _revealed
                            ? _gold.withValues(alpha: 0.95)
                            : AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _revealed ? _dismiss : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor:
                              AppColors.primary.withValues(alpha: 0.35),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          _revealed ? 'Collect' : 'Please wait…',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
