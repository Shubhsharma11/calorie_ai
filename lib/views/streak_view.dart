import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/food_controller.dart';
import '../controllers/streak_controller.dart';
import '../core/responsive.dart';
import '../core/streak_calculator.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/fire_icon.dart';
import '../widgets/primary_button.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/responsive_page.dart';

class StreakView extends GetView<StreakController> {
  const StreakView({super.key});

  static const _streakOrange = Color(0xFFFF9800);
  static const _streakDeep = Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppAppBar(title: 'Streak'),
      body: RefreshIndicator(
        color: _streakOrange,
        onRefresh: () async {
          if (Get.isRegistered<FoodController>()) {
            await Get.find<FoodController>().refreshMealsFromApi();
          }
          await controller.refreshFromApi();
        },
        child: ResponsivePage(
          scrollable: true,
          child: Obx(() {
            final _ = controller.revision.value;
            final stats = controller.stats;
            final isLoading = controller.isLoadingApi.value;
            final apiError = controller.apiErrorMessage.value;
            final weekDays = stats.recentDays.length >= 7
                ? stats.recentDays.sublist(stats.recentDays.length - 7)
                : stats.recentDays;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isLoading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: const LinearProgressIndicator(
                      minHeight: 2,
                      color: _streakOrange,
                      backgroundColor: Color(0x33FF9800),
                    ),
                  ),
                  SizedBox(height: r.scale(12)),
                ],
                if (apiError != null) ...[
                  _InlineNotice(
                    message: apiError,
                    icon: Icons.cloud_off_rounded,
                  ),
                  SizedBox(height: r.scale(12)),
                ],
                _StreakHeroCard(
                  streak: stats.currentStreak,
                  isAtRisk: stats.isAtRisk,
                  streakBroken: stats.streakBroken,
                  hasLoggedToday: stats.hasLoggedToday,
                  statusMessage: controller.statusMessage,
                ),
                SizedBox(height: r.scale(16)),
                _ThisWeekCard(days: weekDays),
                SizedBox(height: r.scale(16)),
                _StatsRow(
                  current: stats.currentStreak,
                  longest: stats.longestStreak,
                  hasLoggedToday: stats.hasLoggedToday,
                ),
                SizedBox(height: r.scale(16)),
                _NextMilestoneCard(currentStreak: stats.currentStreak),
                SizedBox(height: r.scale(20)),
                _SectionTitle(title: 'Last 30 days'),
                SizedBox(height: r.scale(10)),
                _StreakCalendar(days: stats.recentDays),
                SizedBox(height: r.scale(10)),
                const _CalendarLegend(),
                if (stats.isAtRisk || stats.currentStreak == 0) ...[
                  SizedBox(height: r.scale(20)),
                  PrimaryButton(
                    label: stats.currentStreak == 0
                        ? (stats.streakBroken
                            ? 'Log a meal to restart'
                            : 'Log your first meal')
                        : 'Log a meal · keep your streak',
                    onPressed: () => Get.toNamed(AppRoutes.addFood),
                  ),
                ],
                SizedBox(height: r.scale(24)),
                _SectionTitle(title: 'Milestones'),
                SizedBox(height: r.scale(10)),
                _MilestonesSection(currentStreak: stats.currentStreak),
                SizedBox(height: r.scale(16)),
                const _HowItWorksCard(),
                SizedBox(
                  height: MediaQuery.viewPaddingOf(context).bottom +
                      r.scale(20),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ─── Shared bits ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Text(
      title,
      style: TextStyle(
        fontSize: r.scale(17),
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.child,
    this.padding,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Container(
      padding: padding ?? EdgeInsets.all(r.scale(16)),
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────────

class _StreakHeroCard extends StatelessWidget {
  const _StreakHeroCard({
    required this.streak,
    required this.isAtRisk,
    required this.streakBroken,
    required this.hasLoggedToday,
    required this.statusMessage,
  });

  final int streak;
  final bool isAtRisk;
  final bool streakBroken;
  final bool hasLoggedToday;
  final String statusMessage;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final active = streak > 0;
    final status = _statusChip();

    return _CardShell(
      padding: EdgeInsets.fromLTRB(
        r.scale(20),
        r.scale(22),
        r.scale(20),
        r.scale(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: status.bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(status.icon, size: 14, color: status.fg),
                const SizedBox(width: 6),
                Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: status.fg,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.scale(18)),
          Container(
            width: r.scale(88),
            height: r.scale(88),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: active
                    ? [
                        StreakView._streakOrange.withValues(alpha: 0.28),
                        StreakView._streakOrange.withValues(alpha: 0.06),
                      ]
                    : [
                        AppColors.surface,
                        AppColors.surface.withValues(alpha: 0.4),
                      ],
              ),
            ),
            child: Center(
              child: active
                  ? FireIcon(size: r.scale(48))
                  : Icon(
                      Icons.local_fire_department_outlined,
                      size: r.scale(44),
                      color: AppColors.textSecondary,
                    ),
            ),
          ),
          SizedBox(height: r.scale(8)),
          Text(
            '$streak',
            style: TextStyle(
              fontSize: r.scale(56),
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: -1.5,
              color: active
                  ? StreakView._streakDeep
                  : AppColors.textPrimary,
            ),
          ),
          SizedBox(height: r.scale(4)),
          Text(
            streak == 1 ? 'day streak' : 'days streak',
            style: TextStyle(
              fontSize: r.scale(16),
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: r.scale(14)),
          Text(
            statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.scale(14),
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  ({String label, IconData icon, Color bg, Color fg}) _statusChip() {
    if (hasLoggedToday && streak > 0) {
      return (
        label: 'Streak secured',
        icon: Icons.check_circle_rounded,
        bg: AppColors.primary.withValues(alpha: 0.14),
        fg: AppColors.primaryDark,
      );
    }
    if (isAtRisk) {
      return (
        label: 'At risk — log today',
        icon: Icons.warning_amber_rounded,
        bg: StreakView._streakOrange.withValues(alpha: 0.16),
        fg: StreakView._streakDeep,
      );
    }
    if (streakBroken) {
      return (
        label: 'Streak broken',
        icon: Icons.heart_broken_rounded,
        bg: AppColors.error.withValues(alpha: 0.1),
        fg: AppColors.error,
      );
    }
    return (
      label: 'Start logging',
      icon: Icons.flag_rounded,
      bg: AppColors.surface,
      fg: AppColors.textSecondary,
    );
  }
}

// ─── This week ───────────────────────────────────────────────────────────────

class _ThisWeekCard extends StatelessWidget {
  const _ThisWeekCard({required this.days});

  final List<StreakDay> days;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'This week',
                style: TextStyle(
                  fontSize: r.scale(16),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                _weekSummary,
                style: TextStyle(
                  fontSize: r.scale(12),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: r.scale(14)),
          if (days.isEmpty)
            Text(
              'No recent days yet',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            )
          else
            Row(
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) SizedBox(width: r.scale(6)),
                  Expanded(child: _WeekDayDot(day: days[i])),
                ],
              ],
            ),
        ],
      ),
    );
  }

  String get _weekSummary {
    if (days.isEmpty) return '';
    final logged = days.where((d) => d.logged).length;
    return '$logged of ${days.length} logged';
  }
}

class _WeekDayDot extends StatelessWidget {
  const _WeekDayDot({required this.day});

  final StreakDay day;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final label = DateFormat('E').format(day.date).substring(0, 1);
    final Color fill;
    final Color border;
    final Widget? center;

    if (day.partOfCurrentStreak || day.logged) {
      fill = StreakView._streakOrange;
      border = StreakView._streakOrange;
      center = Icon(
        Icons.check_rounded,
        size: r.scale(16),
        color: Colors.white,
      );
    } else if (day.isMissed) {
      fill = AppColors.error.withValues(alpha: 0.08);
      border = AppColors.error.withValues(alpha: 0.35);
      center = Icon(
        Icons.close_rounded,
        size: r.scale(14),
        color: AppColors.error.withValues(alpha: 0.85),
      );
    } else if (day.isToday) {
      fill = StreakView._streakOrange.withValues(alpha: 0.1);
      border = StreakView._streakOrange;
      center = null;
    } else {
      fill = AppColors.surface;
      border = AppColors.border;
      center = null;
    }

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: r.scale(11),
            fontWeight: day.isToday ? FontWeight.w700 : FontWeight.w500,
            color: day.isToday
                ? StreakView._streakDeep
                : AppColors.textSecondary,
          ),
        ),
        SizedBox(height: r.scale(8)),
        AspectRatio(
          aspectRatio: 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(
                color: border,
                width: day.isToday && !day.logged ? 2 : 1,
              ),
            ),
            child: center == null ? null : Center(child: center),
          ),
        ),
      ],
    );
  }
}

// ─── Stats ───────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.current,
    required this.longest,
    required this.hasLoggedToday,
  });

  final int current;
  final int longest;
  final bool hasLoggedToday;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Row(
      children: [
        Expanded(
          child: _StatPill(
            icon: Icons.local_fire_department_rounded,
            iconColor: StreakView._streakOrange,
            value: '$current',
            label: 'Current',
          ),
        ),
        SizedBox(width: r.scale(10)),
        Expanded(
          child: _StatPill(
            icon: Icons.emoji_events_rounded,
            iconColor: const Color(0xFFFFB300),
            value: '$longest',
            label: 'Best',
          ),
        ),
        SizedBox(width: r.scale(10)),
        Expanded(
          child: _StatPill(
            icon: hasLoggedToday
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            iconColor: hasLoggedToday
                ? AppColors.primary
                : AppColors.textSecondary,
            value: hasLoggedToday ? 'Done' : 'Open',
            label: 'Today',
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return _CardShell(
      padding: EdgeInsets.symmetric(
        vertical: r.scale(14),
        horizontal: r.scale(8),
      ),
      child: Column(
        children: [
          Container(
            width: r.scale(34),
            height: r.scale(34),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: r.scale(18)),
          ),
          SizedBox(height: r.scale(8)),
          Text(
            value,
            style: TextStyle(
              fontSize: r.scale(18),
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: r.scale(2)),
          Text(
            label,
            style: TextStyle(
              fontSize: r.scale(11),
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Next milestone ──────────────────────────────────────────────────────────

class _NextMilestoneCard extends StatelessWidget {
  const _NextMilestoneCard({required this.currentStreak});

  final int currentStreak;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final next = _nextMilestone(currentStreak);
    final prev = StreakMilestones.reachedBy(currentStreak) ?? 0;

    if (next == null) {
      return _CardShell(
        child: Row(
          children: [
            Container(
              width: r.scale(40),
              height: r.scale(40),
              decoration: BoxDecoration(
                color: StreakView._streakOrange.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.workspace_premium_rounded,
                color: StreakView._streakOrange,
                size: r.scale(22),
              ),
            ),
            SizedBox(width: r.scale(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All milestones unlocked',
                    style: TextStyle(
                      fontSize: r.scale(15),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: r.scale(2)),
                  Text(
                    '100-day legend — keep the fire going.',
                    style: TextStyle(
                      fontSize: r.scale(12),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final span = (next - prev).clamp(1, next);
    final progress = ((currentStreak - prev) / span).clamp(0.0, 1.0);
    final remaining = next - currentStreak;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: r.scale(40),
                height: r.scale(40),
                decoration: BoxDecoration(
                  color: StreakView._streakOrange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.flag_rounded,
                  color: StreakView._streakOrange,
                  size: r.scale(22),
                ),
              ),
              SizedBox(width: r.scale(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next milestone',
                      style: TextStyle(
                        fontSize: r.scale(12),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: r.scale(2)),
                    Text(
                      '$next-day streak',
                      style: TextStyle(
                        fontSize: r.scale(16),
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                remaining == 1 ? '1 day left' : '$remaining days left',
                style: TextStyle(
                  fontSize: r.scale(12),
                  fontWeight: FontWeight.w700,
                  color: StreakView._streakDeep,
                ),
              ),
            ],
          ),
          SizedBox(height: r.scale(14)),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: r.scale(8),
              backgroundColor: StreakView._streakOrange.withValues(alpha: 0.12),
              color: StreakView._streakOrange,
            ),
          ),
          SizedBox(height: r.scale(8)),
          Text(
            '$currentStreak / $next days',
            style: TextStyle(
              fontSize: r.scale(12),
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Calendar ────────────────────────────────────────────────────────────────

class _StreakCalendar extends StatelessWidget {
  const _StreakCalendar({required this.days});

  final List<StreakDay> days;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    const columns = 7;

    return _CardShell(
      padding: EdgeInsets.all(r.scale(14)),
      child: Column(
        children: [
          for (var row = 0; row < (days.length / columns).ceil(); row++)
            Padding(
              padding: EdgeInsets.only(
                bottom: row < (days.length / columns).ceil() - 1
                    ? r.scale(8)
                    : 0,
              ),
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
    final Color fill;
    final Color border;
    final double borderWidth;

    if (d.partOfCurrentStreak) {
      fill = StreakView._streakOrange.withValues(alpha: 0.16);
      border = StreakView._streakOrange.withValues(alpha: 0.45);
      borderWidth = 1;
    } else if (d.logged) {
      fill = AppColors.primary.withValues(alpha: 0.12);
      border = AppColors.primary.withValues(alpha: 0.35);
      borderWidth = 1;
    } else if (d.isMissed) {
      fill = AppColors.error.withValues(alpha: 0.06);
      border = AppColors.error.withValues(alpha: 0.28);
      borderWidth = 1;
    } else if (d.isToday) {
      fill = AppColors.surface;
      border = AppColors.textPrimary;
      borderWidth = 1.5;
    } else {
      fill = AppColors.surface;
      border = AppColors.border;
      borderWidth = 1;
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
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border, width: borderWidth),
              ),
              child: Center(child: _DayStatusIcon(day: d)),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            DateFormat('d').format(d.date),
            style: TextStyle(
              fontSize: 9,
              fontWeight: d.isToday ? FontWeight.w700 : FontWeight.w500,
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

class _DayStatusIcon extends StatelessWidget {
  const _DayStatusIcon({required this.day});

  final StreakDay day;

  @override
  Widget build(BuildContext context) {
    if (day.partOfCurrentStreak) {
      return const FireIcon(size: 13);
    }
    if (day.logged) {
      return const Icon(
        Icons.restaurant_rounded,
        size: 12,
        color: AppColors.primary,
      );
    }
    if (day.isMissed) {
      return Icon(
        Icons.close_rounded,
        size: 11,
        color: AppColors.error.withValues(alpha: 0.8),
      );
    }
    return const SizedBox.shrink();
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: const [
        _LegendItem(
          icon: FireIcon(size: 12),
          label: 'Current streak',
        ),
        _LegendItem(
          icon: Icon(
            Icons.restaurant_rounded,
            size: 12,
            color: AppColors.primary,
          ),
          label: 'Logged',
        ),
        _LegendItem(
          icon: Icon(
            Icons.close_rounded,
            size: 11,
            color: AppColors.error,
          ),
          label: 'Missed',
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.icon,
    required this.label,
  });

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ─── Milestones ──────────────────────────────────────────────────────────────

class _MilestonesSection extends StatelessWidget {
  const _MilestonesSection({required this.currentStreak});

  final int currentStreak;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Column(
      children: StreakMilestones.values.map((milestone) {
        final reached = currentStreak >= milestone;
        final isNext =
            !reached && _nextMilestone(currentStreak) == milestone;

        return Padding(
          padding: EdgeInsets.only(bottom: r.scale(8)),
          child: _CardShell(
            padding: EdgeInsets.symmetric(
              horizontal: r.scale(14),
              vertical: r.scale(12),
            ),
            color: reached
                ? StreakView._streakOrange.withValues(alpha: 0.08)
                : AppColors.card,
            child: Row(
              children: [
                Container(
                  width: r.scale(40),
                  height: r.scale(40),
                  decoration: BoxDecoration(
                    color: reached
                        ? StreakView._streakOrange.withValues(alpha: 0.18)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    reached
                        ? Icons.check_circle_rounded
                        : isNext
                            ? Icons.local_fire_department_rounded
                            : Icons.lock_outline_rounded,
                    size: r.scale(20),
                    color: reached || isNext
                        ? StreakView._streakOrange
                        : AppColors.textSecondary,
                  ),
                ),
                SizedBox(width: r.scale(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$milestone-day streak',
                        style: TextStyle(
                          fontSize: r.scale(15),
                          fontWeight: FontWeight.w700,
                          color: reached || isNext
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: r.scale(2)),
                      Text(
                        _subtitle(milestone, reached: reached, isNext: isNext),
                        style: TextStyle(
                          fontSize: r.scale(12),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (reached)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: StreakView._streakOrange.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Earned',
                      style: TextStyle(
                        fontSize: r.scale(11),
                        fontWeight: FontWeight.w700,
                        color: StreakView._streakDeep,
                      ),
                    ),
                  )
                else if (isNext)
                  Text(
                    '${milestone - currentStreak} left',
                    style: TextStyle(
                      fontSize: r.scale(12),
                      fontWeight: FontWeight.w700,
                      color: StreakView._streakOrange,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _subtitle(int days, {required bool reached, required bool isNext}) {
    if (reached) return 'Unlocked — nice consistency';
    if (isNext) return 'Your next badge is close';
    return switch (days) {
      3 => 'Build the habit',
      7 => 'A full week of logging',
      14 => 'Two weeks strong',
      30 => 'One month dedication',
      60 => 'Rare consistency',
      100 => 'Legendary',
      _ => 'Keep logging daily',
    };
  }
}

// ─── How it works ────────────────────────────────────────────────────────────

int? _nextMilestone(int currentStreak) {
  for (final milestone in StreakMilestones.values) {
    if (milestone > currentStreak) return milestone;
  }
  return null;
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How streaks work',
            style: TextStyle(
              fontSize: r.scale(15),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: r.scale(12)),
          const _HowStep(
            number: '1',
            text: 'Log at least one meal every day.',
          ),
          SizedBox(height: r.scale(10)),
          const _HowStep(
            number: '2',
            text: 'Miss a day and your streak resets to zero.',
          ),
          SizedBox(height: r.scale(10)),
          const _HowStep(
            number: '3',
            text: 'Hit milestones at 3, 7, 14, 30, 60, and 100 days.',
          ),
        ],
      ),
    );
  }
}

class _HowStep extends StatelessWidget {
  const _HowStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: r.scale(22),
          height: r.scale(22),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: StreakView._streakOrange.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            number,
            style: TextStyle(
              fontSize: r.scale(12),
              fontWeight: FontWeight.w800,
              color: StreakView._streakDeep,
            ),
          ),
        ),
        SizedBox(width: r.scale(10)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: r.scale(13),
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
