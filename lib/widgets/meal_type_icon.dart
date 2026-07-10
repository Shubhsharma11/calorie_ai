import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/meal_type_icons.dart';
import '../theme/app_colors.dart';

/// Meal-type artwork — SVG when available, otherwise a tinted icon tile.
class MealTypeIcon extends StatelessWidget {
  const MealTypeIcon({
    super.key,
    required this.meal,
    this.size = 36,
  });

  final String meal;
  final double size;

  @override
  Widget build(BuildContext context) {
    final svgAsset = MealTypeIcons.svgAssetFor(meal);
    if (svgAsset != null) {
      return SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset(svgAsset, fit: BoxFit.contain),
      );
    }

    final iconSize = size * 20 / 36;
    final radius = size * 10 / 36;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.selectionFill,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        MealTypeIcons.iconFor(meal),
        color: AppColors.primary,
        size: iconSize,
      ),
    );
  }
}
