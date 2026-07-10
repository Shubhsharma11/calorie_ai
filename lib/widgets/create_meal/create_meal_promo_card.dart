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
    final useStackedLayout = r.isCompact || r.width < 400;

    final textBlock = Column(
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
    );

    return Material(
      color: _cardTint,
      borderRadius: BorderRadius.circular(r.scale(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.scale(20)),
        child: Padding(
          padding: EdgeInsets.all(r.scale(18)),
          child: useStackedLayout
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    textBlock,
                    SizedBox(height: r.scale(8)),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: _CreateMealIllustration(),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: textBlock),
                    SizedBox(width: r.scale(8)),
                    const _CreateMealIllustration(),
                  ],
                ),
        ),
      ),
    );
  }
}

class _CreateMealIllustration extends StatelessWidget {
  const _CreateMealIllustration();

  static const _chefLottie = 'assets/image/chef.json';

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final size = r.isCompact
        ? r.scale(88)
        : r.scale(128, tablet: 140);

    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        _chefLottie,
        width: size,
        height: size,
        fit: BoxFit.contain,
        repeat: true,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.restaurant_rounded,
          size: r.scale(48),
          color: AppColors.primary,
        ),
      ),
    );
  }
}
