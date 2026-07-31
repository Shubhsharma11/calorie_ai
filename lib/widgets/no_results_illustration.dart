import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_colors.dart';

/// Responsive “no search results” Lottie that scales down on small screens /
/// with the keyboard open so it never overflows.
class NoResultsIllustration extends StatelessWidget {
  const NoResultsIllustration({
    super.key,
    this.maxSize = 200,
    this.minSize = 88,
  });

  final double maxSize;
  final double minSize;

  static const asset = 'assets/image/No_Results.json';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widthBound = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : maxSize;
        final heightBound = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : maxSize;
        final size = math
            .min(maxSize, math.min(widthBound, heightBound))
            .clamp(minSize, maxSize);

        return SizedBox(
          width: size,
          height: size,
          child: Lottie.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            repeat: true,
            addRepaintBoundary: true,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.search_off_rounded,
              size: size * 0.45,
              color: AppColors.textSecondary,
            ),
          ),
        );
      },
    );
  }
}
