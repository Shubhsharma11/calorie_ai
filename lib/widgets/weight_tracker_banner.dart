import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../controllers/settings_controller.dart';
import '../controllers/tracker_controller.dart';
import '../controllers/user_controller.dart';
import '../core/app_coach_marks.dart';
import '../core/responsive.dart';
import '../core/weight_chart_data.dart';
import '../models/goal_type.dart';
import '../models/weight_entry.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'weight_tracker/weight_log_sheet.dart';

/// Compact weight and recent-trend summary for the Home screen.
class WeightTrackerBanner extends StatelessWidget {
  const WeightTrackerBanner({super.key, this.coachKey});

  /// Optional coach-mark anchor. Must be on this card, not a parent wrapper.
  final GlobalKey? coachKey;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<TrackerController>()) {
      const empty = SizedBox(height: 0);
      if (coachKey == null) return empty;
      return AppCoachMarks.target(key: coachKey!, child: empty);
    }

    final tracker = Get.find<TrackerController>();
    final user = Get.find<UserController>();
    final settings = Get.isRegistered<SettingsController>()
        ? Get.find<SettingsController>()
        : null;

    final banner = Obx(() {
      tracker.weightRevision.value;
      user.calorieGoalRevision.value;
      final useMetricUnits = settings?.useMetricUnits.value ?? true;
      final entries = tracker.recentWeightEntries;
      final currentKg = tracker.currentWeight.value;
      final trend = _WeightTrend.fromEntries(entries);
      final goalKg = user.user.goalWeightKg;
      final goalType = user.user.pinnedGoalType ?? user.user.goal;

      final card = _WeightTrackerCard(
        currentKg: currentKg,
        goalKg: goalKg,
        entries: entries,
        trend: trend,
        goal: goalType,
        useMetricUnits: useMetricUnits,
        onAddWeight: () {
          // Use the banner's build context (not a nested InkWell route) so
          // opening the sheet cannot race with card navigation.
          if (!context.mounted) return;
          showWeightLogSheet(
            context,
            initialWeight: tracker.currentWeight.value,
          );
        },
      );
      if (coachKey == null) return card;
      // Key on the visible card so spotlight/tip match real bounds.
      return AppCoachMarks.target(key: coachKey!, child: card);
    });

    return banner;
  }
}

class _WeightTrackerCard extends StatelessWidget {
  const _WeightTrackerCard({
    required this.currentKg,
    required this.goalKg,
    required this.entries,
    required this.trend,
    required this.goal,
    required this.useMetricUnits,
    required this.onAddWeight,
  });

  final double currentKg;
  final double goalKg;
  final List<WeightEntry> entries;
  final _WeightTrend trend;
  final GoalType? goal;
  final bool useMetricUnits;
  final VoidCallback onAddWeight;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final currentDisplay = WeightChartData.toDisplayWeight(
      currentKg,
      useMetricUnits,
    );
    final unit = WeightChartData.weightUnitLabel(useMetricUnits);
    final latestEntry = entries.isEmpty ? null : entries.last;
    final remainingKg = (goalKg - currentKg).abs();
    final inferredGoal = _inferGoalType(currentKg, goalKg);
    // If the stored goal type is stale/mismatched with the actual
    // goal-vs-current direction, prefer the inferred type.
    final effectiveGoal = goal == null || goal == inferredGoal
        ? (goal ?? inferredGoal)
        : inferredGoal;
    final atGoal = remainingKg < 0.05 ||
        (effectiveGoal == GoalType.loseWeight && currentKg <= goalKg + 0.05) ||
        (effectiveGoal == GoalType.gainWeight && currentKg >= goalKg - 0.05);
    final isOnTrack = trend.isOnTrackFor(effectiveGoal);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              r.scale(18),
              r.scale(14),
              r.scale(10),
              0,
            ),
            child: Row(
              children: [
                Container(
                  width: r.scale(45),
                  height: r.scale(45),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(r.scale(5)),
                    child: SvgPicture.asset(
                      'assets/image/gym.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(width: r.scale(11)),
                Expanded(
                  child: Text(
                    'Weight Progress',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: r.scale(17),
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: onAddWeight,
                  tooltip: 'Add weight',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.18),
                    foregroundColor: AppColors.primary,
                    shape: const CircleBorder(),
                  ),
                  icon: Icon(Icons.add_rounded, size: r.scale(22)),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Get.toNamed(AppRoutes.weightTracker),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  r.scale(18),
                  r.scale(8),
                  r.scale(18),
                  r.scale(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 300;
                        return narrow
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: currentDisplay
                                              .toStringAsFixed(1),
                                          style: TextStyle(
                                            fontSize: r.scale(36),
                                            fontWeight: FontWeight.w800,
                                            height: 1,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        TextSpan(
                                          text: ' $unit',
                                          style: TextStyle(
                                            fontSize: r.scale(16),
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: r.scale(8)),
                                  _TrendPill(
                                    trend: trend,
                                    useMetricUnits: useMetricUnits,
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Flexible(
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: currentDisplay
                                                .toStringAsFixed(1),
                                            style: TextStyle(
                                              fontSize: r.scale(36),
                                              fontWeight: FontWeight.w800,
                                              height: 1,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          TextSpan(
                                            text: ' $unit',
                                            style: TextStyle(
                                              fontSize: r.scale(16),
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: r.scale(10)),
                                  Flexible(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: _TrendPill(
                                        trend: trend,
                                        useMetricUnits: useMetricUnits,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                      },
                    ),
                    SizedBox(height: r.scale(16)),
                    SizedBox(
                      height: r.scale(105),
                      width: double.infinity,
                      child: _WeightSparkline(entries: entries),
                    ),
                    SizedBox(height: r.scale(8)),
                    Row(
                      children: List.generate(7, (index) {
                        final date = DateTime.now().subtract(
                          Duration(days: 6 - index),
                        );
                        return Expanded(
                          child: Text(
                            _weekdayLabel(date.weekday),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: r.scale(9),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: r.scale(14)),
                    Divider(height: 1, color: AppColors.border),
                    SizedBox(height: r.scale(13)),
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Goal ',
                                  style: TextStyle(
                                    fontSize: r.scale(12),
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                TextSpan(
                                  text: WeightChartData.formatWeight(
                                    goalKg,
                                    useMetricUnits,
                                  ),
                                  style: TextStyle(
                                    fontSize: r.scale(13),
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.left,
                          ),
                        ),
                        SizedBox(width: r.scale(10)),
                        Expanded(
                          child: Text(
                            _remainingGoalLabel(
                              goal: effectiveGoal,
                              currentKg: currentKg,
                              goalKg: goalKg,
                              useMetricUnits: useMetricUnits,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: r.scale(12),
                              fontWeight: FontWeight.w800,
                              color: atGoal
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: r.scale(13)),
                    Divider(height: 1, color: AppColors.border),
                    SizedBox(height: r.scale(12)),
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              atGoal || isOnTrack
                                  ? Icons.check_circle_rounded
                                  : _goalMotivationIcon(effectiveGoal),
                              size: r.scale(17),
                              color: atGoal || isOnTrack
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            SizedBox(width: r.scale(6)),
                            Flexible(
                              child: Text(
                                _goalMotivationText(
                                  goal: effectiveGoal,
                                  isOnTrack: isOnTrack,
                                  trend: trend,
                                  currentKg: currentKg,
                                  goalKg: goalKg,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: r.scale(11),
                                  fontWeight: FontWeight.w700,
                                  color: atGoal || isOnTrack
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: r.scale(4)),
                        Text(
                          latestEntry == null
                              ? 'Log your weight to begin'
                              : _lastLoggedLabel(latestEntry.date),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: r.scale(10.5),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _WeightTrendType { losing, gaining, maintaining, unavailable }

class _TrendPill extends StatelessWidget {
  const _TrendPill({required this.trend, required this.useMetricUnits});

  final _WeightTrend trend;
  final bool useMetricUnits;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final color = AppColors.primary;
    final label = trend.weeklyLabel(useMetricUnits);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(10),
        vertical: r.scale(7),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(trend.icon, size: r.scale(14), color: color),
          SizedBox(width: r.scale(4)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.scale(11),
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightSparkline extends StatelessWidget {
  const _WeightSparkline({required this.entries});

  final List<WeightEntry> entries;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final startDate = today.subtract(const Duration(days: 6));
    final recent = _recentWeekEntries(entries);

    if (recent.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Add another check-in to see your weekly trend',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: context.responsive.scale(11),
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return CustomPaint(
      painter: _WeightSparklinePainter(entries: recent, startDate: startDate),
      size: Size.infinite,
    );
  }
}

class _WeightSparklinePainter extends CustomPainter {
  const _WeightSparklinePainter({
    required this.entries,
    required this.startDate,
  });

  final List<WeightEntry> entries;
  final DateTime startDate;

  @override
  void paint(Canvas canvas, Size size) {
    final color = AppColors.primary;
    final values = entries.map((entry) => entry.kg).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs() < 0.1 ? 1.0 : maxValue - minValue;
    const verticalPadding = 8.0;
    final chartHeight = size.height - verticalPadding * 2;
    final points = List.generate(entries.length, (index) {
      final entryDate = _dateOnly(entries[index].date);
      final dayOffset = entryDate.difference(startDate).inDays.clamp(0, 6);
      final x = size.width * (dayOffset + 0.5) / 7;
      final normalized = (entries[index].kg - minValue) / range;
      final y = verticalPadding + chartHeight * (1 - normalized);
      return Offset(x, y);
    });

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final middleX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        middleX,
        previous.dy,
        middleX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.01)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    final dotFill = Paint()..color = AppColors.card;
    final dotBorder = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final point in points) {
      canvas
        ..drawCircle(point, 3.5, dotFill)
        ..drawCircle(point, 3.5, dotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightSparklinePainter oldDelegate) {
    if (oldDelegate.startDate != startDate ||
        oldDelegate.entries.length != entries.length) {
      return true;
    }
    for (var i = 0; i < entries.length; i++) {
      if (oldDelegate.entries[i].date != entries[i].date ||
          oldDelegate.entries[i].kg != entries[i].kg) {
        return true;
      }
    }
    return false;
  }
}

class _WeightTrend {
  const _WeightTrend({required this.type, required this.changeKg});

  static const _stableThresholdKg = 0.05;

  final _WeightTrendType type;
  final double changeKg;

  factory _WeightTrend.fromEntries(List<WeightEntry> entries) {
    final recent = _recentWeekEntries(entries);
    if (recent.length < 2) {
      return const _WeightTrend(
        type: _WeightTrendType.unavailable,
        changeKg: 0,
      );
    }

    final changeKg = recent.last.kg - recent.first.kg;
    final type = changeKg.abs() <= _stableThresholdKg
        ? _WeightTrendType.maintaining
        : changeKg < 0
        ? _WeightTrendType.losing
        : _WeightTrendType.gaining;

    return _WeightTrend(type: type, changeKg: changeKg);
  }

  IconData get icon => switch (type) {
    _WeightTrendType.losing => Icons.arrow_downward_rounded,
    _WeightTrendType.gaining => Icons.arrow_upward_rounded,
    _WeightTrendType.maintaining => Icons.east_rounded,
    _WeightTrendType.unavailable => Icons.remove_rounded,
  };

  String weeklyLabel(bool useMetricUnits) {
    if (type == _WeightTrendType.unavailable) {
      return 'No weekly trend yet';
    }
    if (type == _WeightTrendType.maintaining) {
      return 'Stable this week';
    }

    final amount = WeightChartData.toDisplayWeight(
      changeKg.abs(),
      useMetricUnits,
    ).toStringAsFixed(1);
    final unit = WeightChartData.weightUnitLabel(useMetricUnits);
    return type == _WeightTrendType.losing
        ? 'Losing $amount $unit'
        : 'Gaining $amount $unit';
  }

  bool isOnTrackFor(GoalType? goal) {
    if (goal == null || type == _WeightTrendType.unavailable) return false;
    return switch (goal) {
      GoalType.loseWeight => type == _WeightTrendType.losing,
      GoalType.gainWeight => type == _WeightTrendType.gaining,
      GoalType.maintainWeight => type == _WeightTrendType.maintaining,
    };
  }
}

List<WeightEntry> _recentWeekEntries(List<WeightEntry> entries) {
  final today = _dateOnly(DateTime.now());
  final startDate = today.subtract(const Duration(days: 6));
  final entriesByDate = <DateTime, WeightEntry>{};

  for (final entry in entries) {
    final date = _dateOnly(entry.date);
    if (date.isBefore(startDate) || date.isAfter(today)) continue;
    entriesByDate[date] = entry;
  }

  final recent = entriesByDate.values.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return recent;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _weekdayLabel(int weekday) =>
    const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'][weekday - 1];

String _lastLoggedLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final logged = DateTime(date.year, date.month, date.day);
  final days = today.difference(logged).inDays;
  if (days <= 0) return 'Last logged today';
  if (days == 1) return 'Last logged yesterday';
  return 'Last logged $days days ago';
}

IconData _goalMotivationIcon(GoalType? goal) {
  return switch (goal) {
    GoalType.loseWeight => Icons.trending_down_rounded,
    GoalType.gainWeight => Icons.trending_up_rounded,
    GoalType.maintainWeight => Icons.balance_rounded,
    null => Icons.schedule_rounded,
  };
}

GoalType _inferGoalType(double currentKg, double goalKg) {
  final delta = goalKg - currentKg;
  if (delta.abs() < 0.05) return GoalType.maintainWeight;
  if (delta < 0) return GoalType.loseWeight;
  return GoalType.gainWeight;
}

String _remainingAmountLabel(double remainingKg, bool useMetricUnits) {
  final unit = WeightChartData.weightUnitLabel(useMetricUnits);
  final amount = WeightChartData.toDisplayWeight(
    remainingKg,
    useMetricUnits,
  ).toStringAsFixed(1);
  return '$amount $unit';
}

/// Short label next to the goal weight, e.g. "5.0 kg to lose".
String _remainingGoalLabel({
  required GoalType goal,
  required double currentKg,
  required double goalKg,
  required bool useMetricUnits,
}) {
  final remainingKg = (goalKg - currentKg).abs();
  final amount = _remainingAmountLabel(remainingKg, useMetricUnits);

  if (goal == GoalType.maintainWeight) {
    if (remainingKg < 0.05) return 'On target';
    return '$amount off target';
  }

  if (goal == GoalType.loseWeight && currentKg <= goalKg + 0.05) {
    return 'On target';
  }
  if (goal == GoalType.gainWeight && currentKg >= goalKg - 0.05) {
    return 'On target';
  }

  return switch (goal) {
    GoalType.loseWeight => '$amount to lose',
    GoalType.gainWeight => '$amount to gain',
    GoalType.maintainWeight => 'On target',
  };
}

String _goalMotivationText({
  required GoalType? goal,
  required bool isOnTrack,
  required _WeightTrend trend,
  required double currentKg,
  required double goalKg,
}) {
  final remainingKg = (goalKg - currentKg).abs();
  final atGoal = remainingKg < 0.05;
  final effectiveGoal = goal ?? _inferGoalType(currentKg, goalKg);

  if (atGoal ||
      (effectiveGoal == GoalType.loseWeight && currentKg <= goalKg + 0.05) ||
      (effectiveGoal == GoalType.gainWeight && currentKg >= goalKg - 0.05)) {
    return switch (effectiveGoal) {
      GoalType.maintainWeight => switch (trend.type) {
        _WeightTrendType.maintaining =>
          'You’re holding your maintenance weight',
        _WeightTrendType.losing =>
          'Stay steady so you don’t keep losing',
        _WeightTrendType.gaining =>
          'Stay steady so you don’t keep gaining',
        _WeightTrendType.unavailable =>
          'You’re at your maintenance goal',
      },
      GoalType.loseWeight => switch (trend.type) {
        _WeightTrendType.maintaining => 'You’re holding your new weight',
        _WeightTrendType.gaining => 'Keep the weight off now that you’re there',
        _WeightTrendType.losing => 'You’re at goal — keep it steady',
        _WeightTrendType.unavailable => 'You hit your weight-loss goal',
      },
      GoalType.gainWeight => switch (trend.type) {
        _WeightTrendType.maintaining => 'You’re holding your new weight',
        _WeightTrendType.losing => 'Keep the weight on now that you’re there',
        _WeightTrendType.gaining => 'You’re at goal — keep it steady',
        _WeightTrendType.unavailable => 'You hit your weight-gain goal',
      },
    };
  }

  if (trend.type == _WeightTrendType.unavailable) {
    return switch (effectiveGoal) {
      GoalType.loseWeight => 'Keep logging to track your weight loss',
      GoalType.gainWeight => 'Keep logging to track your weight gain',
      GoalType.maintainWeight => 'Log weekly to stay on maintenance',
    };
  }

  if (trend.type == _WeightTrendType.maintaining) {
    return switch (effectiveGoal) {
      GoalType.loseWeight => 'Weight is holding — stay on your loss plan',
      GoalType.gainWeight => 'Weight is holding — stay on your gain plan',
      GoalType.maintainWeight => 'You’re maintaining your goal weight',
    };
  }

  if (isOnTrack) {
    return switch (effectiveGoal) {
      GoalType.loseWeight => 'You’re losing this week — keep it up',
      GoalType.gainWeight => 'You’re gaining this week — keep it up',
      GoalType.maintainWeight => 'You’re maintaining your goal weight',
    };
  }

  return switch (effectiveGoal) {
    GoalType.loseWeight => 'You’re gaining this week — stay on your loss plan',
    GoalType.gainWeight => 'You’re losing this week — stay on your gain plan',
    GoalType.maintainWeight => trend.type == _WeightTrendType.losing
        ? 'You’re dropping below maintenance'
        : 'You’re moving above maintenance',
  };
}
