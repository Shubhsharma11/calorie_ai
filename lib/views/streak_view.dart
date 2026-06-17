import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/streak_controller.dart';
import '../core/responsive.dart';
import '../core/streak_calculator.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_page.dart';

class StreakView extends GetView<StreakController> {
  const StreakView({super.key});

  static const _streakOrange = Color(0xFFFF9800);

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      appBar: AppBar(title: const Text('Your Streak')),
      body: ResponsivePage(
        scrollable: true,
        child: Obx(() {
          final _ = controller.revision.value;
          final stats = controller.stats;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StreakHero(
                streak: stats.currentStreak,
                isAtRisk: stats.isAtRisk,
              ),
              SizedBox(height: r.scale(16)),
              Text(
                controller.statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              SizedBox(height: r.scale(24)),
              Row(
                children: [
                  _StatTile(
                    icon: Icons.local_fire_department_rounded,
                    color: _streakOrange,
                    value: '${stats.currentStreak}',
                    label: 'Current Streak',
                  ),
                  SizedBox(width: r.scale(10)),
                  _StatTile(
                    icon: Icons.emoji_events_rounded,
                    color: AppColors.primary,
                    value: '${stats.longestStreak}',
                    label: 'Longest Streak',
                  ),
                  SizedBox(width: r.scale(10)),
                  _StatTile(
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF2196F3),
                    value: stats.hasLoggedToday ? 'Yes' : 'No',
                    label: 'Logged Today',
                  ),
                ],
              ),
              SizedBox(height: r.scale(28)),
              Text(
                'Last 30 Days',
                style: TextStyle(
                  fontSize: r.scale(18),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: r.scale(12)),
              _StreakCalendar(days: stats.recentDays),
              SizedBox(height: r.scale(12)),
              _CalendarLegend(),
              if (stats.isAtRisk || stats.currentStreak == 0) ...[
                SizedBox(height: r.scale(24)),
                PrimaryButton(
                  label: stats.currentStreak == 0
                      ? 'Log your first meal'
                      : 'Log a meal to save streak',
                  onPressed: () => Get.toNamed(AppRoutes.addFood),
                ),
              ],
              SizedBox(height: r.scale(16)),
              _MilestonesSection(currentStreak: stats.currentStreak),
            ],
          );
        }),
      ),
    );
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({
    required this.streak,
    required this.isAtRisk,
  });

  final int streak;
  final bool isAtRisk;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(vertical: r.scale(28)),
      decoration: BoxDecoration(
        color: StreakView._streakOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAtRisk
              ? StreakView._streakOrange.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: r.scale(56),
            color: streak > 0
                ? StreakView._streakOrange
                : AppColors.textSecondary,
          ),
          SizedBox(height: r.scale(8)),
          Text(
            '$streak',
            style: TextStyle(
              fontSize: r.scale(52),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            streak == 1 ? 'Day Streak' : 'Day Streak',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          if (isAtRisk) ...[
            const SizedBox(height: 8),
            Text(
              'At risk — log today!',
              style: TextStyle(
                color: StreakView._streakOrange,
                fontWeight: FontWeight.w600,
                fontSize: r.scale(13),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: r.scale(14),
          horizontal: r.scale(8),
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: r.scale(22)),
            SizedBox(height: r.scale(6)),
            Text(
              value,
              style: TextStyle(
                fontSize: r.scale(18),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakCalendar extends StatelessWidget {
  const _StreakCalendar({required this.days});

  final List<StreakDay> days;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    const columns = 7;

    return Container(
      padding: EdgeInsets.all(r.scale(14)),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var row = 0; row < (days.length / columns).ceil(); row++)
            Padding(
              padding: EdgeInsets.only(bottom: row < 3 ? r.scale(8) : 0),
              child: Row(
                children: [
                  for (var col = 0; col < columns; col++)
                    Expanded(
                      child: _DayCell(
                        day: row * columns + col < days.length
                            ? days[row * columns + col]
                            : null,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({this.day});

  final StreakDay? day;

  @override
  Widget build(BuildContext context) {
    if (day == null) return const SizedBox.shrink();

    final d = day!;
    Color fill;
    Color border;

    if (d.partOfCurrentStreak) {
      fill = StreakView._streakOrange;
      border = StreakView._streakOrange;
    } else if (d.logged) {
      fill = AppColors.primary.withValues(alpha: 0.35);
      border = AppColors.primary;
    } else {
      fill = AppColors.surface;
      border = AppColors.border;
    }

    if (d.isToday) {
      border = AppColors.textPrimary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: border, width: d.isToday ? 1.5 : 1),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            DateFormat('d').format(d.date),
            style: TextStyle(
              fontSize: 9,
              fontWeight: d.isToday ? FontWeight.w700 : FontWeight.normal,
              color: d.isToday
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: StreakView._streakOrange, label: 'Current streak'),
        SizedBox(width: 16),
        _LegendDot(
          color: AppColors.primary,
          label: 'Logged',
          faded: true,
        ),
        SizedBox(width: 16),
        _LegendDot(color: AppColors.surface, label: 'Missed', bordered: true),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    this.faded = false,
    this.bordered = false,
  });

  final Color color;
  final String label;
  final bool faded;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: faded ? color.withValues(alpha: 0.35) : color,
            borderRadius: BorderRadius.circular(3),
            border: bordered ? Border.all(color: AppColors.border) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _MilestonesSection extends StatelessWidget {
  const _MilestonesSection({required this.currentStreak});

  final int currentStreak;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Milestones',
          style: TextStyle(
            fontSize: r.scale(18),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: r.scale(12)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: StreakMilestones.values.map((milestone) {
            final reached = currentStreak >= milestone;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: reached
                    ? StreakView._streakOrange.withValues(alpha: 0.12)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: reached
                      ? StreakView._streakOrange.withValues(alpha: 0.4)
                      : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    reached
                        ? Icons.check_circle_rounded
                        : Icons.lock_outline_rounded,
                    size: 16,
                    color: reached
                        ? StreakView._streakOrange
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$milestone days',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: reached ? FontWeight.w600 : FontWeight.normal,
                      color: reached
                          ? StreakView._streakOrange
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
