import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../core/responsive.dart';
import '../theme/app_colors.dart';

class MacroNutritionData {
  const MacroNutritionData({
    required this.label,
    required this.currentG,
    required this.goalG,
    required this.progress,
    required this.color,
    required this.emoji,
    this.lottieAsset,
    this.lottieScale = 1.15,
    this.lottieFit = BoxFit.contain,
    this.lottieAlignment = Alignment.center,
  });

  final String label;
  final int currentG;
  final int goalG;
  final double progress;
  final Color color;
  final String emoji;
  final String? lottieAsset;
  final double lottieScale;
  final BoxFit lottieFit;
  final Alignment lottieAlignment;
}

/// Unified macro card with three circular progress rings (Carbs, Fat, Protein).
class MacroNutritionCard extends StatelessWidget {
  const MacroNutritionCard({
    super.key,
    required this.macros,
  });

  final List<MacroNutritionData> macros;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: r.scale(20),
        horizontal: r.scale(12),
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < macros.length; i++) ...[
            if (i > 0) SizedBox(width: r.scale(4)),
            Expanded(child: _MacroColumn(data: macros[i])),
          ],
        ],
      ),
    );
  }
}

class _MacroColumn extends StatelessWidget {
  const _MacroColumn({required this.data});

  final MacroNutritionData data;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final ringSize = r.scale(64, tablet: 72, desktop: 80);
    final strokeWidth = r.scale(6);
    final innerSize = ringSize - strokeWidth * 2 - r.scale(4);
    final percent = (data.progress * 100).round().clamp(0, 999);

    return Column(
      children: [
        SizedBox(
          width: ringSize,
          height: ringSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: ringSize,
                height: ringSize,
                child: CircularProgressIndicator(
                  value: data.progress.clamp(0.0, 1.0),
                  strokeWidth: strokeWidth,
                  backgroundColor: AppColors.surface,
                  color: data.color,
                ),
              ),
              if (data.lottieAsset != null)
                ClipOval(
                  child: SizedBox(
                    width: innerSize,
                    height: innerSize,
                    child: ColoredBox(
                      color: AppColors.card,
                      child: Transform.scale(
                        scale: data.lottieScale,
                        alignment: data.lottieAlignment,
                        child: Lottie.asset(
                          data.lottieAsset!,
                          width: innerSize,
                          height: innerSize,
                          fit: data.lottieFit,
                          repeat: true,
                          errorBuilder: (_, __, ___) => Text(
                            data.emoji,
                            style: TextStyle(fontSize: r.scale(24)),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Text(
                  data.emoji,
                  style: TextStyle(fontSize: r.scale(24)),
                ),
            ],
          ),
        ),
        SizedBox(height: r.scale(8)),
        Text(
          data.label,
          style: TextStyle(
            fontSize: r.scale(13),
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: r.scale(2)),
        Text(
          '${data.currentG} / ${data.goalG}g',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          '$percent%',
          style: TextStyle(
            fontSize: r.scale(12),
            fontWeight: FontWeight.w600,
            color: data.color,
          ),
        ),
      ],
    );
  }
}
