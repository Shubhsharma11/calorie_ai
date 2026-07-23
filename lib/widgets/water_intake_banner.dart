import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/food_controller.dart';
import '../controllers/tracker_controller.dart';
import '../controllers/settings_controller.dart';
import '../core/responsive.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

/// Compact water intake row for the Home screen summary area.
class WaterIntakeBanner extends StatelessWidget {
  const WaterIntakeBanner({super.key});

  static const _waterBlue = Color(0xFF007AFF);
  static const _maxGlassesShown = 8;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    if (!Get.isRegistered<TrackerController>()) {
      return const SizedBox.shrink();
    }
    final tracker = Get.find<TrackerController>();
    final food = Get.isRegistered<FoodController>()
        ? Get.find<FoodController>()
        : null;

    return Obx(() {
      if (Get.isRegistered<SettingsController>()) {
        Get.find<SettingsController>().waterGoalMl.value;
      }
      food?.selectedLogDate.value;
      final viewingToday = food?.isViewingToday ?? true;
      final viewDate = food?.selectedLogDate.value;
      final waterMl = viewDate == null
          ? tracker.waterMl
          : tracker.waterForDate(viewDate);
      final goalMl = TrackerController.waterGoalMl;
      final glasses = (waterMl / TrackerController.mlPerGlass).round();
      final goalGlasses = goalMl > 0
          ? (goalMl / TrackerController.mlPerGlass).round().clamp(1, 100)
          : 8;
      final isComplete = waterMl >= goalMl;
      final overGlasses = glasses > goalGlasses ? glasses - goalGlasses : 0;
      final remainingGlasses =
          (goalGlasses - glasses).clamp(0, goalGlasses);
      final _ = tracker.waterByDate.length;
      final color = isComplete ? AppColors.primary : _waterBlue;
      final dayWord = viewingToday ? 'today' : 'this day';
      final headerText = overGlasses > 0
          ? 'Goal reached'
          : isComplete
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

      return Container(
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
                                style: TextStyle(
                                  fontSize: r.scale(14),
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              headerText,
                              style: TextStyle(
                                fontSize: r.scale(13),
                                fontWeight: FontWeight.w700,
                                color: color,
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
                          child: Row(
                            children: [
                              ...List.generate(shownGoal, (index) {
                                final filled = index < filledShown;
                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: r.scale(2),
                                    ),
                                    child: _GlassCup(
                                      filled: filled,
                                      color: color,
                                      height: r.scale(26),
                                    ),
                                  ),
                                );
                              }),
                              SizedBox(width: r.scale(8)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: r.scale(8),
                                  vertical: r.scale(4),
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.card.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: r.scale(11),
                                    fontWeight: FontWeight.w700,
                                    color: isComplete || overGlasses > 0
                                        ? color
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: r.scale(10)),
              IconButton.filled(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  tracker.addWater(date: viewDate);
                },
                tooltip: 'Add 1 glass',
                style: IconButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: Size(r.scale(40), r.scale(40)),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const CircleBorder(),
                ),
                icon: Icon(Icons.add_rounded, size: r.scale(22)),
              ),
            ],
          ),
        ),
      );
    });
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
        return CustomPaint(
          size: Size(widget.height * 0.7, widget.height),
          painter: _GlassCupPainter(
            fillAmount: Curves.easeOutCubic.transform(_controller.value),
            color: widget.color,
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
