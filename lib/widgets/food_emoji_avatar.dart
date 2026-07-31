import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Food thumbnail: network image when [imageUrl] is set, otherwise emoji.
class FoodEmojiAvatar extends StatelessWidget {
  const FoodEmojiAvatar({
    super.key,
    required this.emoji,
    this.imageUrl,
    this.size = 48,
    this.fontSize,
    this.backgroundColor,
  });

  final String emoji;
  final String? imageUrl;
  final double size;
  final double? fontSize;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.22);
    final url = imageUrl?.trim();
    final hasImage = url != null && url.isNotEmpty;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.surface,
          borderRadius: radius,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: hasImage
              ? Image.network(
                  url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, _, _) => _EmojiFallback(
                    emoji: emoji,
                    size: size,
                    fontSize: fontSize,
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: SizedBox(
                        width: size * 0.35,
                        height: size * 0.35,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary.withValues(alpha: 0.5),
                        ),
                      ),
                    );
                  },
                )
              : _EmojiFallback(
                  emoji: emoji,
                  size: size,
                  fontSize: fontSize,
                ),
        ),
      ),
    );
  }
}

class _EmojiFallback extends StatelessWidget {
  const _EmojiFallback({
    required this.emoji,
    required this.size,
    this.fontSize,
  });

  final String emoji;
  final double size;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final emojiSize = fontSize ?? size * 0.52;
    return Center(
      child: Text(
        emoji,
        style: TextStyle(
          fontSize: emojiSize,
          height: 1,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
