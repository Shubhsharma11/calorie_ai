import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/media_url.dart';
import '../theme/app_colors.dart';
import 'app_network_image.dart';

/// Food thumbnail: local bytes or network image when set, otherwise emoji.
class FoodEmojiAvatar extends StatelessWidget {
  const FoodEmojiAvatar({
    super.key,
    required this.emoji,
    this.imageUrl,
    this.imageBytes,
    this.size = 48,
    this.fontSize,
    this.backgroundColor,
    this.onTap,
  });

  final String emoji;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final double size;
  final double? fontSize;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.22);
    final url = MediaUrl.resolve(imageUrl);
    final bytes = imageBytes;
    final hasBytes = bytes != null && bytes.isNotEmpty;
    final hasNetwork = url != null && url.isNotEmpty;

    final Widget photo;
    if (hasBytes) {
      photo = Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, _) => _EmojiFallback(
          emoji: emoji,
          size: size,
          fontSize: fontSize,
        ),
      );
    } else if (hasNetwork) {
      photo = AppNetworkImage(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, _) {
          debugPrint('FoodEmojiAvatar failed for $url: $error');
          return _EmojiFallback(
            emoji: emoji,
            size: size,
            fontSize: fontSize,
          );
        },
        placeholder: Center(
          child: SizedBox(
            width: size * 0.35,
            height: size * 0.35,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    } else {
      photo = _EmojiFallback(
        emoji: emoji,
        size: size,
        fontSize: fontSize,
      );
    }

    final avatar = SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.surface,
          borderRadius: radius,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: photo,
        ),
      ),
    );

    if (onTap == null) return avatar;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: avatar,
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
