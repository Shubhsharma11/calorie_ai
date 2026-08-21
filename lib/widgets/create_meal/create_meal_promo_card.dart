import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

import '../../core/responsive.dart';
import '../../theme/app_colors.dart';

/// Promotional card for starting the create-meal flow on Add Food → My Meals.
class CreateMealPromoCard extends StatelessWidget {
  const CreateMealPromoCard({
    super.key,
    required this.onTap,
    this.title = 'Create Meal',
    this.description = 'Build and save your favourite meal.',
    this.actionLabel = 'Create New Meal',
    this.illustrationAsset = 'assets/image/chef.json',
  });

  final VoidCallback onTap;
  final String title;
  final String description;
  final String actionLabel;
  final String illustrationAsset;

  static const _lightCardTint = Color(0xFFF0F9F4);

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final illustrationSize = r.scale(162, tablet: 184);
    final isDark = AppColors.isDark(context);
    final cardColor = isDark ? AppColors.darkHeaderWash : _lightCardTint;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(r.scale(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.scale(16)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r.scale(16)),
            border: Border.all(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.28)
                  : AppColors.border.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              r.scale(14),
              r.scale(12),
              r.scale(4),
              r.scale(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: r.scale(22),
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: r.scale(6)),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: r.scale(15),
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: r.scale(10)),
                      FilledButton(
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
                          actionLabel,
                          style: TextStyle(
                            fontSize: r.scale(14),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: r.scale(2)),
                Transform.translate(
                  offset: Offset(0, -r.scale(18)),
                  child: _CreateMealIllustration(
                    size: illustrationSize,
                    asset: illustrationAsset,
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

class _CreateMealIllustration extends StatelessWidget {
  const _CreateMealIllustration({
    required this.size,
    required this.asset,
  });

  final double size;
  final String asset;

  bool get _isLottie => asset.endsWith('.json');
  bool get _isSvg => asset.endsWith('.svg');

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: _isLottie
            ? Lottie.asset(
                asset,
                width: size,
                height: size,
                fit: BoxFit.contain,
                repeat: true,
                addRepaintBoundary: true,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.restaurant_rounded,
                  size: r.scale(32),
                  color: AppColors.primary,
                ),
              )
            : _isSvg
                ? SvgPicture.asset(
                    asset,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                    placeholderBuilder: (_) => Icon(
                      Icons.restaurant_rounded,
                      size: r.scale(32),
                      color: AppColors.primary,
                    ),
                  )
                : Image.asset(
                    asset,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.restaurant_rounded,
                      size: r.scale(32),
                      color: AppColors.primary,
                    ),
                  ),
      ),
    );
  }
}
