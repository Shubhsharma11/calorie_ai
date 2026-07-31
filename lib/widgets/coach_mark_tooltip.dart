import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Compact coach tip — short copy, intrinsic height, polished card chrome.
class CoachMarkBubble extends StatelessWidget {
  const CoachMarkBubble({
    super.key,
    required this.title,
    required this.description,
    required this.stepIndex,
    required this.stepCount,
    required this.isLast,
    required this.onSkip,
    required this.onNext,
  });

  final String title;
  final String description;
  final int stepIndex;
  final int stepCount;
  final bool isLast;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final card = isDark ? AppColors.darkCard : Colors.white;
    final primary = AppColors.primary;
    final onSurface = AppColors.textPrimaryOf(context);
    final muted = AppColors.textSecondaryOf(context);
    final compact = MediaQuery.sizeOf(context).width < 360;
    final padH = compact ? 12.0 : 16.0;
    final padV = compact ? 13.0 : 15.0;
    final titleSize = compact ? 16.0 : 17.5;
    final bodySize = compact ? 13.5 : 14.5;

    return Material(
      color: card,
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.55 : 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: primary.withValues(alpha: isDark ? 0.45 : 0.22),
          width: 1.4,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QUICK TIP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: primary,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          height: 1.15,
                          color: onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) {
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.35),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    '${stepIndex + 1}/$stepCount',
                    key: ValueKey(stepIndex),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: primary.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SmoothProgressBar(
              progress: (stepIndex + 1) / stepCount,
              color: primary,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: bodySize,
                height: 1.35,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                color: onSurface.withValues(alpha: isDark ? 0.92 : 0.88),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (!isLast)
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onSkip();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: muted,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      compact ? 'Skip' : 'Skip for now',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onNext();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 16 : 20,
                      vertical: 11,
                    ),
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      isLast
                          ? (compact ? 'Start' : "I'm ready")
                          : (compact ? 'Next' : 'Continue'),
                      key: ValueKey('${isLast}_$compact'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: -0.15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmoothProgressBar extends StatelessWidget {
  const _SmoothProgressBar({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 4.5,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                ColoredBox(
                  color: color.withValues(alpha: 0.12),
                  child: const SizedBox.expand(),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 520),
                  curve: const Cubic(0.33, 0.00, 0.20, 1.00),
                  width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
