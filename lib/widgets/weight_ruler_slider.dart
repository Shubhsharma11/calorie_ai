import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Ruler-style weight slider with tick marks and a green indicator.
class WeightRulerSlider extends StatelessWidget {
  const WeightRulerSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.enabled = true,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onHorizontalDragUpdate: enabled
              ? (details) => _updateFromPosition(
                    details.localPosition.dx,
                    constraints.maxWidth,
                  )
              : null,
          onTapDown: enabled
              ? (details) => _updateFromPosition(
                    details.localPosition.dx,
                    constraints.maxWidth,
                  )
              : null,
          child: CustomPaint(
            size: Size(constraints.maxWidth, 56),
            painter: _WeightRulerPainter(
              value: value.clamp(min, max),
              min: min,
              max: max,
            ),
          ),
        );
      },
    );
  }

  void _updateFromPosition(double dx, double width) {
    if (width <= 0 || max <= min) return;
    final ratio = (dx / width).clamp(0.0, 1.0);
    final raw = min + ratio * (max - min);
    final stepped = (raw * 2).round() / 2; // 0.5 kg steps
    onChanged(stepped.clamp(min, max));
  }
}

class _WeightRulerPainter extends CustomPainter {
  _WeightRulerPainter({
    required this.value,
    required this.min,
    required this.max,
  });

  final double value;
  final double min;
  final double max;

  @override
  void paint(Canvas canvas, Size size) {
    final baselineY = size.height - 18;
    final range = max - min;
    if (range <= 0) return;

    final baselinePaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(0, baselineY),
      Offset(size.width, baselineY),
      baselinePaint,
    );

    final tickPaint = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    final labelStyle = TextStyle(
      fontSize: 11,
      color: AppColors.textSecondary.withValues(alpha: 0.7),
    );

    final labelStep = range > 100 ? 20 : 10;
    final startLabel = (min / labelStep).floor() * labelStep;
    final endLabel = (max / labelStep).ceil() * labelStep;

    final nearestLabel = (value / labelStep).round() * labelStep;

    for (var tick = startLabel; tick <= endLabel; tick += 10) {
      if (tick < min - 5 || tick > max + 5) continue;
      final ratio = (tick - min) / range;
      final x = ratio.clamp(0.0, 1.0) * size.width;

      final isMajor = tick % 10 == 0;
      final tickHeight = isMajor ? 12.0 : 6.0;
      canvas.drawLine(
        Offset(x, baselineY - tickHeight),
        Offset(x, baselineY),
        tickPaint,
      );

      if (isMajor && tick % labelStep == 0) {
        final isActive = tick == nearestLabel;
        final tp = TextPainter(
          text: TextSpan(
            text: '$tick',
            style: labelStyle.copyWith(
              color: isActive
                  ? AppColors.primary
                  : AppColors.textSecondary.withValues(alpha: 0.7),
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, baselineY + 4));
      }
    }

    final valueRatio = ((value - min) / range).clamp(0.0, 1.0);
    final indicatorX = valueRatio * size.width;

    final indicatorPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(indicatorX, baselineY - 28),
      Offset(indicatorX, baselineY),
      indicatorPaint,
    );

    canvas.drawCircle(
      Offset(indicatorX, baselineY - 30),
      4,
      Paint()..color = AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(covariant _WeightRulerPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.min != min ||
      oldDelegate.max != max;
}
