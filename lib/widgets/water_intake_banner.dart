import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/food_controller.dart';
import '../controllers/tracker_controller.dart';
import '../controllers/settings_controller.dart';
import '../core/app_coach_marks.dart';
import '../core/responsive.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

/// Compact water intake row for the Home screen summary area.
class WaterIntakeBanner extends StatelessWidget {
  const WaterIntakeBanner({super.key, this.coachKey});

  /// Optional coach-mark anchor for the home tour.
  final GlobalKey? coachKey;

  static const _waterBlue = Color(0xFF4AA3DF);
  static const _maxGlassesShown = 8;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    if (!Get.isRegistered<TrackerController>()) {
      const empty = SizedBox.shrink();
      if (coachKey == null) return empty;
      return AppCoachMarks.target(key: coachKey!, child: empty);
    }
    final tracker = Get.find<TrackerController>();
    final food = Get.isRegistered<FoodController>()
        ? Get.find<FoodController>()
        : null;

    return Obx(() {
    
      food?.selectedLogDate.value;
      final viewingToday = food?.isViewingToday ?? true;
      final viewDate = food?.selectedLogDate.value;
      final waterMl = viewDate == null
          ? tracker.waterMl
          : tracker.waterForDate(viewDate);
    final settings = Get.isRegistered<SettingsController>()
    ? Get.find<SettingsController>()
    : null;

final goalMl = settings?.waterGoalMl.value ??
    TrackerController.waterGoalMl;
      
      final glasses = (waterMl / TrackerController.mlPerGlass).floor();
      final goalGlasses = goalMl > 0
          ? (goalMl / TrackerController.mlPerGlass).round().clamp(1, 100)
          : 8;
      final isComplete = waterMl >= goalMl;
      final overGlasses = glasses > goalGlasses ? glasses - goalGlasses : 0;
      final remainingGlasses =
          (goalGlasses - glasses).clamp(0, goalGlasses);
      final _ = tracker.waterRevision.value;
      final color = isComplete ? AppColors.primary : _waterBlue;
      final dayWord = viewingToday ? 'today' : 'this day';
     final headerText = isComplete
    ? 'Goal reached'
    : glasses == 0
        ? 'Stay hydrated'
        : glasses == 1
            ? '1 glass $dayWord'
            : '$glasses glasses $dayWord';
      final status = overGlasses > 0
          ? '+$overGlasses extra'
          : isComplete
              ? 'Goal done'
              : glasses > 0
                  ? '$remainingGlasses left'
                  : 'Add a glass';

      final shownGoal = goalGlasses.clamp(1, _maxGlassesShown);
      final filledShown = glasses.clamp(0, shownGoal);

      final card = Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(r.scale(14)),
          child: Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Get.toNamed(AppRoutes.waterTracker),
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.water_drop_rounded,
                              color: color,
                              size: r.scale(20),
                            ),
                            SizedBox(width: r.scale(7)),
                            Expanded(
                              child: Text(
                                'Water Intake',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: r.scale(14),
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                headerText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontSize: r.scale(13),
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.45),
                            ),
                          ],
                        ),
                        SizedBox(height: r.scale(10)),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: r.scale(10),
                            vertical: r.scale(10),
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final statusGap = r.scale(8);
                              final minGlassesWidth = r.scale(36);
                              final statusMaxWidth = (constraints.maxWidth -
                                      statusGap -
                                      minGlassesWidth)
                                  .clamp(0.0, r.scale(88));
                              return Row(
                                children: [
                                  Expanded(
                                    child: _AdaptiveGlassesRow(
                                      count: shownGoal,
                                      filled: filledShown,
                                      color: color,
                                      maxHeight: r.scale(26),
                                    ),
                                  ),
                                  if (statusMaxWidth > 0) ...[
                                    SizedBox(width: statusGap),
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: statusMaxWidth,
                                      ),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: r.scale(8),
                                          vertical: r.scale(4),
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.card
                                              .withValues(alpha: 0.85),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          status,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          softWrap: false,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: r.scale(11),
                                            fontWeight: FontWeight.w700,
                                            color: isComplete ||
                                                    overGlasses > 0
                                                ? color
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: r.scale(10)),
              Tooltip(
                message: 'Add 1 glass',
                child: Material(
                  color: color,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      tracker.addWater(date: DateTime.now());
                    },
                    child: SizedBox(
                      width: r.scale(40),
                      height: r.scale(40),
                      child: Icon(
                        Icons.add_rounded,
                        size: r.scale(22),
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      if (coachKey == null) return card;
      return AppCoachMarks.target(key: coachKey!, child: card);
    });
  }
}

/// Glasses that shrink to the leftover width so the status chip never overflows.
class _AdaptiveGlassesRow extends StatelessWidget {
  const _AdaptiveGlassesRow({
    required this.count,
    required this.filled,
    required this.color,
    required this.maxHeight,
  });

  final int count;
  final int filled;
  final Color color;
  final double maxHeight;

  static const _aspect = 0.62;
  static const _minGap = 2.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = count.clamp(1, 100);
        final available = constraints.maxWidth;
        if (!available.isFinite || available <= 0) {
          return const SizedBox.shrink();
        }

        final maxW = maxHeight * _aspect;
        final idealGap = (maxHeight * 0.23).clamp(3.0, 6.0);

        var glassW = maxW;
        var gap = n > 1 ? idealGap : 0.0;
        final idealTotal = n * glassW + (n - 1) * gap;

        if (idealTotal > available) {
          final gapAtFullSize =
              n > 1 ? (available - n * maxW) / (n - 1) : 0.0;
          if (gapAtFullSize >= _minGap) {
            gap = gapAtFullSize;
          } else {
            gap = n > 1 ? _minGap : 0.0;
            glassW = ((available - (n - 1) * gap) / n).clamp(0.0, maxW);
          }
        }

        final glassH = glassW / _aspect;

        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < n; i++) ...[
                if (i > 0) SizedBox(width: gap),
                _GlassCup(
                  filled: i < filled,
                  color: color,
                  height: glassH,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Tumbler glass that animates only when its fill state changes.
class _GlassCup extends StatefulWidget {
  const _GlassCup({
    required this.filled,
    required this.color,
    required this.height,
  });

  final bool filled;
  final Color color;
  final double height;

  @override
  State<_GlassCup> createState() => _GlassCupState();
}

class _GlassCupState extends State<_GlassCup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.filled ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant _GlassCup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filled == widget.filled) return;
    if (widget.filled) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final size = Size(widget.height * 0.62, widget.height);
        return SizedBox(
          width: size.width,
          height: size.height,
          child: CustomPaint(
            size: size,
            painter: _GlassCupPainter(
              fillAmount: Curves.easeOutCubic.transform(_controller.value),
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}

class _GlassCupPainter extends CustomPainter {
  _GlassCupPainter({
    required this.fillAmount,
    required this.color,
  });

  final double fillAmount;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final topInset = w * 0.08;
    final bottomInset = w * 0.22;

    final glassPath = Path()
      ..moveTo(topInset, h * 0.08)
      ..lineTo(w - topInset, h * 0.08)
      ..lineTo(w - bottomInset, h * 0.92)
      ..lineTo(bottomInset, h * 0.92)
      ..close();

    canvas.drawPath(
      glassPath,
      Paint()
        ..color = color.withValues(alpha: 0.06)
        ..style = PaintingStyle.fill,
    );

    if (fillAmount > 0) {
      final fillTop = h * (0.92 - 0.72 * fillAmount);
      final t = ((fillTop - h * 0.08) / (h * 0.84)).clamp(0.0, 1.0);
      final left = topInset + (bottomInset - topInset) * t;
      final right = w - left;

      final liquid = Path()
        ..moveTo(left, fillTop)
        ..lineTo(right, fillTop)
        ..lineTo(w - bottomInset, h * 0.92)
        ..lineTo(bottomInset, h * 0.92)
        ..close();

      canvas.save();
      canvas.clipPath(glassPath);
      canvas.drawPath(
        liquid,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.55),
              color.withValues(alpha: 0.95),
            ],
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );
      canvas.restore();
    }

    canvas.drawPath(
      glassPath,
      Paint()
        ..color = color.withValues(alpha: fillAmount > 0.5 ? 0.95 : 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_GlassCupPainter old) =>
      old.fillAmount != fillAmount || old.color != color;
}
