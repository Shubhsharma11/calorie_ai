import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../core/app_coach_marks.dart';
import '../core/goal_progress_message.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';
import 'finish_icon.dart';
import 'macro_nutrition_card.dart';
import 'training_icon.dart';

/// Formats an integer with thousands separators (e.g. 1370 -> 1,370).
String _formatKcal(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}$buffer';
}

/// Home calorie card: progress header, ring + goal/burned, macros, meal CTA.
class CalorieOverviewCard extends StatelessWidget {
  const CalorieOverviewCard({
    super.key,
    required this.eaten,
    required this.goal,
    required this.burned,
    required this.progress,
    required this.isOverGoal,
    required this.caloriesOver,
    required this.progressPercent,
    required this.netOver,
    required this.netRemaining,
    required this.netCaloriesOver,
    required this.macros,
    required this.onAddFood,
    required this.onViewSummary,
    this.onCaloriesBurn,
    this.showcaseKey,
    this.addFoodShowcaseKey,
  });

  final int eaten;
  final int goal;
  final int burned;
  final double progress;
  final bool isOverGoal;
  final int caloriesOver;
  final int progressPercent;
  final bool netOver;
  final int netRemaining;
  final int netCaloriesOver;
  final List<MacroNutritionData> macros;
  final VoidCallback onAddFood;
  final VoidCallback onViewSummary;
  final VoidCallback? onCaloriesBurn;
  final GlobalKey? showcaseKey;
  final GlobalKey? addFoodShowcaseKey;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : r.width;
        final cardPadding = r.scale(18, tablet: 22);
        final contentWidth = math.max(0.0, availableWidth - cardPadding * 2);
        final gap = r.scale(28, tablet: 32);
        final ringSize = math
            .min(r.scale(136, tablet: 152), contentWidth * 0.42)
            .clamp(122.0, 152.0);
        final cta = _resolveCta();
        final accentColor =
            isOverGoal ? AppColors.warning : AppColors.primary;
        final ringValue = netOver ? netCaloriesOver : netRemaining;
        final ringLabel = netOver ? 'Over' : 'Remaining';
        // Food logged fills the ring (same idea as MFP's orange arc).
        final foodProgress =
            goal <= 0 ? 0.0 : (eaten / goal).clamp(0.0, 1.0);

        return Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Coach highlight: card top through macros only (not meal CTA).
              _wrapCoachTarget(
                key: showcaseKey,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    cardPadding,
                    cardPadding,
                    cardPadding,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TodayIntakeHeader(
                        eaten: eaten,
                        goal: goal,
                        progressPercent: progressPercent,
                        isOverGoal: isOverGoal,
                        onViewSummary: onViewSummary,
                      ),
                      SizedBox(height: r.scale(18)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _AnimatedRing(
                            value: ringValue,
                            label: ringLabel,
                            progress: foodProgress,
                            isOver: netOver,
                            size: ringSize,
                          ),
                          SizedBox(width: gap),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: r.scale(10)),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SideStatRow(
                                    label: 'Goal',
                                    value: goal,
                                    accent: AppColors.primary,
                                    icon: FinishIcon(
                                      size: r.scale(24),
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(height: r.scale(14)),
                                  _SideStatRow(
                                    label: 'Food',
                                    value: eaten,
                                    accent: const Color(0xFF007AFF),
                                    icon: Icon(
                                      Icons.restaurant_rounded,
                                      size: r.scale(24),
                                      color: const Color(0xFF007AFF),
                                    ),
                                  ),
                                  SizedBox(height: r.scale(14)),
                                  _SideStatRow(
                                    label: 'Exercise',
                                    value: burned,
                                    accent: const Color(0xFFFF9500),
                                    icon: TrainingIcon(
                                      size: r.scale(24),
                                      color: const Color(0xFFFF9500),
                                    ),
                                    onTap: onCaloriesBurn,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: r.scale(14)),
                      Padding(
                        // Align with macros box inner content (Carbs / Fat / Protein).
                        padding: EdgeInsets.symmetric(horizontal: r.scale(10)),
                        child: Text(
                          'Remaining = Goal − Food + Exercise',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: r.scale(12.5),
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      if (macros.isNotEmpty) ...[
                        SizedBox(height: r.scale(15)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: r.scale(10),
                            vertical: r.scale(16),
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.7),
                            ),
                          ),
                          child: Row(
                            children: [
                              for (var i = 0; i < macros.length; i++) ...[
                                if (i > 0) SizedBox(width: r.scale(6)),
                                Expanded(
                                  child: _InlineMacroColumn(data: macros[i]),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  cardPadding,
                  r.scale(14),
                  cardPadding,
                  cardPadding,
                ),
                child: _MealActionButton(
                  coachKey: addFoodShowcaseKey,
                  label: cta.label,
                  onPressed: cta.action,
                  accentColor: accentColor,
                  emphasized: cta.isEmphasized,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _wrapCoachTarget({required GlobalKey? key, required Widget child}) {
    if (key == null) return child;
    return AppCoachMarks.target(key: key, child: child);
  }

  _MealCta _resolveCta() {
    if (eaten == 0) {
      return _MealCta(
        label: 'Add your first meal',
        action: onAddFood,
      );
    }
    if (isOverGoal || progressPercent >= 100) {
      return _MealCta(
        label: 'View summary',
        action: onViewSummary,
        isEmphasized: false,
      );
    }
    return _MealCta(
      label: 'Log a meal',
      action: onAddFood,
    );
  }
}

class _MealCta {
  const _MealCta({
    required this.label,
    required this.action,
    this.isEmphasized = true,
  });

  final String label;
  final VoidCallback action;
  final bool isEmphasized;
}

class _TodayIntakeHeader extends StatelessWidget {
  const _TodayIntakeHeader({
    required this.eaten,
    required this.goal,
    required this.progressPercent,
    required this.isOverGoal,
    required this.onViewSummary,
  });

  final int eaten;
  final int goal;
  final int progressPercent;
  final bool isOverGoal;
  final VoidCallback onViewSummary;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final message = GoalProgressMessage.forIntake(
      consumed: eaten,
      goal: goal,
      progressPercent: progressPercent,
    );
    final accentColor =
        message.isOverGoal ? AppColors.warning : AppColors.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r.scale(10),
                  vertical: r.scale(4),
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                    fontSize: r.scale(11),
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              SizedBox(height: r.scale(8)),
              Text(
                message.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: r.scale(17, tablet: 18),
                  fontWeight: FontWeight.w700,
                  color: message.isOverGoal
                      ? AppColors.warning
                      : AppColors.textPrimary,
                  height: 1.25,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: r.scale(8)),
        IconButton(
          onPressed: onViewSummary,
          tooltip: 'View today',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: r.scale(36),
            minHeight: r.scale(36),
          ),
          icon: Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
            size: r.scale(26),
          ),
        ),
      ],
    );
  }

  String get _statusLabel {
    if (eaten == 0) return "Today's intake";
    if (isOverGoal) return 'Over daily goal';
    if (progressPercent >= 100) return 'Goal reached';
    return "Today's progress";
  }
}

class _MealActionButton extends StatelessWidget {
  const _MealActionButton({
    required this.label,
    required this.onPressed,
    required this.accentColor,
    required this.emphasized,
    this.coachKey,
  });

  /// Must match [AppCoachMarks] add-food step radius.
  static const double highlightRadius = 16;

  final String label;
  final VoidCallback onPressed;
  final Color accentColor;
  final bool emphasized;
  final GlobalKey? coachKey;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final radius = BorderRadius.circular(highlightRadius);

    // Clip to the painted rounded shape so the coach hole matches exactly
    // (no white card showing in the rectangular corners).
    Widget button = SizedBox(
      width: double.infinity,
      height: r.scale(48),
      child: Material(
        color: emphasized ? accentColor : Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: emphasized
                  ? null
                  : Border.all(
                      color: accentColor.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
              color: emphasized ? null : accentColor.withValues(alpha: 0.08),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    label.toLowerCase().contains('summary')
                        ? Icons.bar_chart_rounded
                        : Icons.add_rounded,
                    size: r.scale(20),
                    color: emphasized ? AppColors.onPrimary : accentColor,
                  ),
                  SizedBox(width: r.scale(8)),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: r.scale(15),
                      fontWeight: FontWeight.w700,
                      color: emphasized ? AppColors.onPrimary : accentColor,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (coachKey == null) return button;
    return AppCoachMarks.target(key: coachKey!, child: button);
  }
}

class _AnimatedRing extends StatelessWidget {
  const _AnimatedRing({
    required this.value,
    required this.label,
    required this.progress,
    required this.isOver,
    required this.size,
  });

  final int value;
  final String label;
  final double progress;
  final bool isOver;
  final double size;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final ringColor = isOver ? AppColors.warning : AppColors.primary;
    final target = progress.clamp(0.0, 1.0);
    final strokeWidth = r.scale(11, tablet: 12);

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) {
          return CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              progress: animated,
              color: ringColor,
              trackColor: AppColors.surface,
              strokeWidth: strokeWidth,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: r.scale(18)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formatKcal(value),
                        style: TextStyle(
                          fontSize: r.scale(28, tablet: 30),
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          letterSpacing: -0.8,
                          color: isOver
                              ? AppColors.warning
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(height: r.scale(3)),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: r.scale(13),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -math.pi / 2;

    final trackPaint = Paint()
      ..isAntiAlias = true
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = 2 * math.pi * progress;
    final progressPaint = Paint()
      ..isAntiAlias = true
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + 2 * math.pi,
        colors: [color.withValues(alpha: 0.65), color],
        stops: const [0.0, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

/// Flat goal / food / exercise row — clean list, no nested cards.
class _SideStatRow extends StatelessWidget {
  const _SideStatRow({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
    this.onTap,
  });

  final String label;
  final int value;
  final Color accent;
  final Widget icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    final row = Row(
      children: [
        SizedBox(
          width: r.scale(26),
          child: icon,
        ),
        SizedBox(width: r.scale(10)),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: r.scale(13),
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  color: accent,
                ),
              ),
              SizedBox(height: r.scale(2)),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _formatKcal(value),
                      style: TextStyle(
                        fontSize: r.scale(18),
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: -0.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: ' kcal',
                      style: TextStyle(
                        fontSize: r.scale(13),
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (onTap != null)
          Icon(
            Icons.chevron_right_rounded,
            size: r.scale(18),
            color: AppColors.textSecondary.withValues(alpha: 0.45),
          ),
      ],
    );

    if (onTap == null) return row;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: r.scale(2)),
          child: row,
        ),
      ),
    );
  }
}

class _InlineMacroColumn extends StatelessWidget {
  const _InlineMacroColumn({required this.data});

  final MacroNutritionData data;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final ringSize = r.scale(60, tablet: 66);
    final strokeWidth = r.scale(5.5);
    final innerSize = ringSize - strokeWidth * 2 - r.scale(4);

    return Column(
      mainAxisSize: MainAxisSize.min,
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
                          errorBuilder: (_, _, _) => Text(
                            data.emoji,
                            style: TextStyle(fontSize: r.scale(22)),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Text(
                  data.emoji,
                  style: TextStyle(fontSize: r.scale(22)),
                ),
            ],
          ),
        ),
        SizedBox(height: r.scale(8)),
        Text(
          data.label,
          style: TextStyle(
            fontSize: r.scale(13),
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: r.scale(3)),
        Text(
          '${data.currentG}/${data.goalG}g',
          style: TextStyle(
            fontSize: r.scale(12),
            fontWeight: FontWeight.w500,
            height: 1.1,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
