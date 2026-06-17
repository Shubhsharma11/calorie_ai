import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Centers a food emoji inside a consistent rounded container.
class FoodEmojiAvatar extends StatelessWidget {
  const FoodEmojiAvatar({
    super.key,
    required this.emoji,
    this.size = 48,
    this.fontSize,
    this.backgroundColor,
  });

  final String emoji;
  final double size;
  final double? fontSize;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final emojiSize = fontSize ?? size * 0.52;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.surface,
          borderRadius: BorderRadius.circular(size * 0.22),
        ),
        child: Center(
          child: Text(
            emoji,
            style: TextStyle(
              fontSize: emojiSize,
              height: 1,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
