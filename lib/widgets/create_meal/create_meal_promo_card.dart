import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/responsive.dart';
import '../../theme/app_colors.dart';

/// Promotional card for starting the create-meal flow on Add Food → My Meals.
class CreateMealPromoCard extends StatelessWidget {
  const CreateMealPromoCard({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  static const _cardTint = Color(0xFFF0F9F4);

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Material(
      color: _cardTint,
      borderRadius: BorderRadius.circular(r.scale(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.scale(20)),
        child: Padding(
          padding: EdgeInsets.all(r.scale(18)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth;
              final illustrationSize = (cardWidth * 0.3).clamp(80.0, 112.0);
              final useStackedLayout =
                  cardWidth < 300 || textScale > 1.12;

              final textBlock = _PromoTextBlock(
                onTap: onTap,
                illustrationSize: illustrationSize,
                reserveRightSpace: !useStackedLayout,
              );

              if (useStackedLayout) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    textBlock,
                    SizedBox(height: r.scale(4)),
                    Center(
                      child: _CreateMealIllustration(size: illustrationSize),
                    ),
                  ],
                );
              }

              return ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: illustrationSize * 0.9,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerRight,
                  children: [
                    textBlock,
                    Positioned(
                      right: -r.scale(2),
                      bottom: -r.scale(6),
                      child: _CreateMealIllustration(size: illustrationSize),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PromoTextBlock extends StatelessWidget {
  const _PromoTextBlock({
    required this.onTap,
    required this.illustrationSize,
    required this.reserveRightSpace,
  });

  final VoidCallback onTap;
  final double illustrationSize;
  final bool reserveRightSpace;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final rightInset =
        reserveRightSpace ? illustrationSize * 0.62 : 0.0;

    return Padding(
      padding: EdgeInsets.only(right: rightInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Meal',
            style: TextStyle(
              fontSize: r.scale(18),
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: r.scale(8)),
          Text(
            'Build a new meal by adding foods and save it for later.',
            style: TextStyle(
              fontSize: r.scale(13),
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: r.scale(16)),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: r.scale(18),
                  vertical: r.scale(12),
                ),
                minimumSize: Size(0, r.scale(44)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                'Create New Meal',
                style: TextStyle(
                  fontSize: r.scale(14),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateMealIllustration extends StatelessWidget {
  const _CreateMealIllustration({required this.size});

  final double size;

  static const _chefLottie = 'assets/image/chef.json';
  static const _lottieScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Transform.scale(
              scale: _lottieScale,
              child: Lottie.asset(
                _chefLottie,
                width: size,
                height: size,
                fit: BoxFit.contain,
                repeat: true,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.restaurant_rounded,
                  size: r.scale(40),
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
