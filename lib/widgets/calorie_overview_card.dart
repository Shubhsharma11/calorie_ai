import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/goal_progress_message.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';
import 'finish_icon.dart';
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

/// Unified calorie summary card for the home screen — ring + message + stat chips.
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
    required this.onAddFood,
    required this.onViewSummary,
    this.onCaloriesBurn,
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
  final VoidCallback onAddFood;
  final VoidCallback onViewSummary;
  final VoidCallback? onCaloriesBurn;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final message = GoalProgressMessage.forIntake(
      consumed: eaten,
      goal: goal,
      progressPercent: progressPercent,
    );
    final accentColor = message.isOverGoal
        ? AppColors.warning
        : AppColors.primary;
    final cta = _resolveCta();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : r.width;
        final cardPadding = r.scale(18, tablet: 22);
        final contentWidth = math.max(0.0, availableWidth - cardPadding * 2);
        final gap = r.scale(12, tablet: 18, desktop: 24);
        const minPanelWidth = 148.0;
        final maxRing = r.scale(156, tablet: 172, desktop: 184);
        final ringSize = math
            .min(maxRing, contentWidth - minPanelWidth - gap)
            .clamp(108.0, maxRing);
        final compact = contentWidth < 340;

        final ring = _AnimatedRing(
          eaten: eaten,
          goal: goal,
          progress: progress,
          isOverGoal: isOverGoal,
          caloriesOver: caloriesOver,
          size: ringSize,
          compact: compact,
        );

        final panel = _MessagePanel(
          message: message,
          accentColor: accentColor,
          eaten: eaten,
          progressPercent: progressPercent,
          isOverGoal: isOverGoal,
          cta: cta,
          compact: compact,
        );

        return Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ring,
                    SizedBox(width: gap),
                    Expanded(child: panel),
                  ],
                ),
                SizedBox(height: r.scale(24)),
                Row(
                  children: [
                    _StatTile(
                      label: isOverGoal ? 'Over goal' : 'Goal',
                      value: isOverGoal ? caloriesOver : goal,
                      accent: isOverGoal
                          ? AppColors.warning
                          : AppColors.primary,
                      iconWidget: FinishIcon(size: r.scale(32)),
                      valueColor: isOverGoal ? AppColors.warning : null,
                      onTap: onAddFood,
                      showChevron: true,
                    ),
                    SizedBox(width: r.scale(10)),
                    _StatTile(
                      label: 'Burned',
                      value: burned,
                      accent: const Color(0xFFFF9500),
                      iconWidget: TrainingIcon(size: r.scale(40)),
                      onTap: onCaloriesBurn,
                      showChevron: onCaloriesBurn != null,
                    ),
                  ],
                ),
                if (burned > 0) ...[
                  SizedBox(height: r.scale(8)),
                  Text(
                    netOver
                        ? 'Incl. activity · ${_formatKcal(netCaloriesOver)} over'
                        : 'Incl. activity · ${_formatKcal(netRemaining)} remaining',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: r.scale(12),
                      fontWeight: FontWeight.w600,
                      color: netOver
                          ? AppColors.warning
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  _CtaConfig _resolveCta() {
    if (eaten == 0) {
      return _CtaConfig(label: 'Add your first meal', action: onAddFood);
    }
    if (isOverGoal || progressPercent >= 100) {
      return _CtaConfig(
        label: 'View summary',
        action: onViewSummary,
        isEmphasized: false,
      );
    }
    return _CtaConfig(
      label: 'Log a meal',
      action: onAddFood,
      secondaryLabel: 'View today',
      secondaryAction: onViewSummary,
    );
  }
}

class _CtaConfig {
  const _CtaConfig({
    required this.label,
    required this.action,
    this.secondaryLabel,
    this.secondaryAction,
    this.isEmphasized = true,
  });

  final String label;
  final VoidCallback action;
  final String? secondaryLabel;
  final VoidCallback? secondaryAction;
  final bool isEmphasized;
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.message,
    required this.accentColor,
    required this.eaten,
    required this.progressPercent,
    required this.isOverGoal,
    required this.cta,
    required this.compact,
  });

  final GoalProgressMessage message;
  final Color accentColor;
  final int eaten;
  final int progressPercent;
  final bool isOverGoal;
  final _CtaConfig cta;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(compact ? 8 : 10),
            vertical: r.scale(compact ? 4 : 5),
          ),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _statusLabel,
            style: TextStyle(
              fontSize: r.scale(compact ? 10 : 11),
              fontWeight: FontWeight.w600,
              color: accentColor,
              letterSpacing: 0.2,
            ),
          ),
        ),
        SizedBox(height: r.scale(compact ? 8 : 12)),
        Text(
          message.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: r.scale(compact ? 15 : 18, tablet: 19),
            fontWeight: FontWeight.w700,
            color: message.isOverGoal
                ? AppColors.warning
                : AppColors.textPrimary,
            height: 1.25,
            letterSpacing: -0.3,
          ),
        ),
        SizedBox(height: r.scale(compact ? 4 : 6)),
        Text(
          message.subtitle,
          maxLines: compact ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: r.scale(compact ? 12 : 13),
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        SizedBox(height: r.scale(compact ? 12 : 16)),
        _PanelActionButton(
          label: cta.label,
          onPressed: cta.action,
          accentColor: accentColor,
          compact: compact,
          emphasized: cta.isEmphasized,
        ),
        if (cta.secondaryLabel != null && cta.secondaryAction != null) ...[
          SizedBox(height: r.scale(8)),
          _PanelTextLink(
            label: cta.secondaryLabel!,
            onPressed: cta.secondaryAction!,
            accentColor: accentColor,
            compact: compact,
          ),
        ],
      ],
    );
  }

  String get _statusLabel {
    if (eaten == 0) return 'Today\'s intake';
    if (isOverGoal) return 'Over daily goal';
    if (progressPercent >= 100) return 'Goal reached';
    return 'Today\'s progress';
  }
}

class _PanelActionButton extends StatelessWidget {
  const _PanelActionButton({
    required this.label,
    required this.onPressed,
    required this.accentColor,
    required this.compact,
    required this.emphasized,
  });

  final String label;
  final VoidCallback onPressed;
  final Color accentColor;
  final bool compact;
  final bool emphasized;

  IconData get _icon {
    final lower = label.toLowerCase();
    if (lower.contains('summary') || lower.contains('today')) {
      return Icons.bar_chart_rounded;
    }
    if (lower.contains('meal') || lower.contains('food')) {
      return Icons.add_rounded;
    }
    return Icons.arrow_forward_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final fontSize = r.scale(compact ? 12 : 13);
    final iconSize = r.scale(compact ? 15 : 16);
    final radius = BorderRadius.circular(12);
    final padding = EdgeInsets.symmetric(
      horizontal: r.scale(compact ? 12 : 14),
      vertical: r.scale(compact ? 9 : 10),
    );

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _icon,
          size: iconSize,
          color: emphasized ? AppColors.onPrimary : accentColor,
        ),
        SizedBox(width: r.scale(6)),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: emphasized ? AppColors.onPrimary : accentColor,
              letterSpacing: 0.1,
            ),
          ),
        ),
        SizedBox(width: r.scale(4)),
        Icon(
          Icons.chevron_right_rounded,
          size: r.scale(compact ? 16 : 18),
          color: emphasized
              ? AppColors.onPrimary.withValues(alpha: 0.9)
              : accentColor.withValues(alpha: 0.75),
        ),
      ],
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: emphasized ? accentColor : accentColor.withValues(alpha: 0.1),
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: emphasized
                  ? null
                  : Border.all(color: accentColor.withValues(alpha: 0.28)),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class _PanelTextLink extends StatelessWidget {
  const _PanelTextLink({
    required this.label,
    required this.onPressed,
    required this.accentColor,
    required this.compact,
  });

  final String label;
  final VoidCallback onPressed;
  final Color accentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(2),
            vertical: r.scale(2),
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: r.scale(compact ? 12 : 13),
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: r.scale(compact ? 16 : 18),
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedRing extends StatelessWidget {
  const _AnimatedRing({
    required this.eaten,
    required this.goal,
    required this.progress,
    required this.isOverGoal,
    required this.caloriesOver,
    required this.size,
    required this.compact,
  });

  final int eaten;
  final int goal;
  final double progress;
  final bool isOverGoal;
  final int caloriesOver;
  final double size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final ringColor = isOverGoal ? AppColors.warning : AppColors.primary;
    final target = isOverGoal
        ? 1.0
        : (goal > 0 ? progress.clamp(0.0, 1.0) : 0.0);
    final goalLabel = isOverGoal
        ? '${_formatKcal(caloriesOver)} over goal'
        : 'of ${_formatKcal(goal)} kcal';
    final strokeWidth = compact
        ? r.scale(9, tablet: 10, desktop: 11)
        : r.scale(11, tablet: 12, desktop: 13);

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return CustomPaint(
            painter: _RingPainter(
              progress: value,
              color: ringColor,
              trackColor: AppColors.surface,
              strokeWidth: strokeWidth,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatKcal(eaten),
                      style: TextStyle(
                        fontSize: r.scale(compact ? 24 : 32, tablet: 34),
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: -1.2,
                        color: isOverGoal
                            ? AppColors.warning
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(height: r.scale(2)),
                  Text(
                    'kcal',
                    style: TextStyle(
                      fontSize: r.scale(compact ? 10 : 12),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: r.scale(compact ? 4 : 6)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.scale(4)),
                    child: Text(
                      goalLabel,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r.scale(compact ? 9 : 11),
                        color: isOverGoal
                            ? AppColors.warning
                            : AppColors.textSecondary,
                        fontWeight: isOverGoal
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
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
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = 2 * math.pi * progress;
    final progressPaint = Paint()
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

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.iconWidget,
    this.valueColor,
    this.onTap,
    this.showChevron = false,
  });

  final String label;
  final int value;
  final Widget iconWidget;
  final Color accent;
  final Color? valueColor;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final chevronSize = r.scale(16);
    final valueStyle = TextStyle(
      fontSize: r.scale(13),
      fontWeight: FontWeight.w700,
      color: valueColor ?? AppColors.textPrimary,
      height: 1.2,
      letterSpacing: -0.2,
    );
    final unitStyle = TextStyle(
      fontSize: r.scale(11),
      fontWeight: FontWeight.w600,
      color: valueColor ?? AppColors.textSecondary,
    );

    final tile = Container(
      padding: EdgeInsets.symmetric(
        vertical: r.scale(11),
        horizontal: r.scale(8),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: r.scale(40),
            height: r.scale(40),
            child: Center(child: iconWidget),
          ),
          SizedBox(width: r.scale(6)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    style: valueStyle,
                    children: [
                      TextSpan(text: '${_formatKcal(value)} '),
                      TextSpan(text: 'kcal', style: unitStyle),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: r.scale(2)),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.scale(10),
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: chevronSize,
            height: chevronSize,
            child: showChevron && onTap != null
                ? Icon(
                    Icons.chevron_right_rounded,
                    size: chevronSize,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  )
                : null,
          ),
        ],
      ),
    );

    return Expanded(
      child: onTap == null
          ? tile
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: tile,
              ),
            ),
    );
  }
}
