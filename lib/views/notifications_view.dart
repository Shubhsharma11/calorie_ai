import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/settings_controller.dart';
import '../controllers/streak_controller.dart';
import '../controllers/tracker_controller.dart';
import '../core/streak_calculator.dart';
import '../core/responsive.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/responsive_page.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final Set<String> _readIds = {};
  final Set<String> _dismissedIds = {};

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsController>();
    final r = context.responsive;

    return Scaffold(
      appBar: AppAppBar(
        title: 'Notifications',
        actions: [
          IconButton(
            onPressed: () => Get.toNamed(AppRoutes.settings),
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: ResponsivePage(
        scrollable: true,
        child: Obx(() {
            final notifications = _buildNotifications(
              settings,
            ).where((item) => !_dismissedIds.contains(item.id)).toList();
            final priority = notifications
                .where((item) => item.priority)
                .take(2)
                .toList();
            final today = notifications
                .where((item) => !item.priority && !item.achievement)
                .toList();
            final achievements = notifications
                .where((item) => item.achievement)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: r.scale(8)),
                _GreetingBanner(),
                SizedBox(height: r.scale(22)),
                _SectionHeader(
                  title: 'Priority',
                  count: priority.length,
                  actionLabel: 'View all',
                  onActionTap: () {},
                ),
                SizedBox(height: r.scale(10)),
                for (final item in priority) ...[
                  _PriorityNotificationCard(
                    item: item,
                    read: _readIds.contains(item.id),
                    onTap: () => _openNotification(item),
                    onClear: () => _clearNotification(item.id),
                  ),
                  SizedBox(height: r.scale(12)),
                ],
                if (today.isNotEmpty) ...[
                  SizedBox(height: r.scale(4)),
                  const _SectionHeader(title: 'Today'),
                  SizedBox(height: r.scale(10)),
                  for (final item in today) ...[
                    _PriorityNotificationCard(
                      item: item,
                      read: _readIds.contains(item.id),
                      onTap: () => _openNotification(item),
                      onClear: () => _clearNotification(item.id),
                    ),
                    SizedBox(height: r.scale(12)),
                  ],
                ],
                if (achievements.isNotEmpty) ...[
                  SizedBox(height: r.scale(22)),
                  const _SectionHeader(title: 'Achievements'),
                  SizedBox(height: r.scale(10)),
                  for (final item in achievements)
                    _AchievementCard(
                      item: item,
                      onTap: () => _openNotification(item),
                    ),
                ],
                if (notifications.isEmpty) const _EmptyNotifications(),
                SizedBox(height: r.scale(24)),
              ],
            );
          }),
        ),
    );
  }

  List<_NotificationItem> _buildNotifications(SettingsController settings) {
    final tracker = Get.isRegistered<TrackerController>()
        ? Get.find<TrackerController>()
        : null;
    final streak = Get.isRegistered<StreakController>()
        ? Get.find<StreakController>()
        : null;
    final items = <_NotificationItem>[];

    if (!settings.pushNotifications.value) {
      return const [
        _NotificationItem(
          id: 'notifications-paused',
          icon: Icons.notifications_off_rounded,
          title: 'Notifications paused',
          body: 'Turn notifications back on from settings.',
          timeLabel: 'Now',
          accentColor: Color(0xFFFF9500),
          backgroundColor: Color(0xFFFFF5E8),
          route: AppRoutes.settings,
          priority: true,
          actionLabel: 'Turn On',
        ),
      ];
    }

    if (tracker != null) {
      final waterDone = tracker.isWaterGoalComplete;
      items.add(
        _NotificationItem(
          id: 'water-goal',
          icon: Icons.water_drop_outlined,
          title: waterDone ? 'Water goal completed' : 'Water goal pending',
          body: waterDone
              ? 'Great work. You reached your hydration goal.'
              : 'You have logged ${tracker.waterMl} of ${TrackerController.waterGoalMl} ml today.',
          timeLabel: '2 min ago',
          accentColor: const Color(0xFFFF8A00),
          backgroundColor: const Color(0xFFFFF3E4),
          route: AppRoutes.waterTracker,
          priority: !waterDone,
          actionLabel: waterDone ? null : 'Log Water',
        ),
      );
    }

    if (settings.mealReminders.value) {
      items.add(
        _NotificationItem(
          id: 'meal-reminder',
          icon: Icons.restaurant_rounded,
          title: 'Meal reminder',
          body:
              'Breakfast is planned for ${settings.formatTime(context, settings.breakfastReminder.value)}.',
          timeLabel: '10 min ago',
          accentColor: AppColors.primary,
          backgroundColor: const Color(0xFFEFFBF3),
          route: AppRoutes.addFood,
          priority: true,
          actionLabel: 'View Meal Plan',
        ),
      );
    }

    if (settings.waterReminders.value) {
      items.add(
        _NotificationItem(
          id: 'hydration-reminder',
          icon: Icons.water_drop_rounded,
          title: 'Hydration reminder',
          body:
              'Drink water ${settings.waterIntervalSummary.toLowerCase()} to stay hydrated.',
          timeLabel: '28 min ago',
          accentColor: const Color(0xFF18A0FB),
          backgroundColor: const Color(0xFFE8F6FF),
          route: AppRoutes.waterTracker,
        ),
      );
    }

    if (settings.goalProgressAlerts.value) {
      items.add(
        const _NotificationItem(
          id: 'meal-plan-ready',
          icon: Icons.assignment_rounded,
          title: 'Meal plan ready',
          body: 'Your personalized meal plan is ready.',
          timeLabel: '1 h ago',
          accentColor: Color(0xFF8B5CF6),
          backgroundColor: Color(0xFFF2EDFF),
          route: AppRoutes.dailySummary,
        ),
      );
    }

    if (settings.streakReminders.value) {
      items.add(
        const _NotificationItem(
          id: 'wellness-tip',
          icon: Icons.favorite_rounded,
          title: 'Daily wellness tip',
          body: 'A short walk after meals helps digestion.',
          timeLabel: '3 h ago',
          accentColor: Color(0xFFFF4F8B),
          backgroundColor: Color(0xFFFFEDF4),
        ),
      );
    }

    if (streak != null) {
      final stats = streak.stats;
      final achievedDays =
          StreakMilestones.reachedBy(stats.currentStreak) ??
          stats.longestStreak;
      if (achievedDays > 0) {
        items.add(
          _NotificationItem(
            id: 'streak-achievement',
            icon: Icons.workspace_premium_rounded,
            title: achievedDays >= 3
                ? '$achievedDays Day Streak!'
                : 'Streak Started!',
            body: stats.hasLoggedToday
                ? 'You logged today and kept your streak going.'
                : streak.statusMessage,
            timeLabel: stats.hasLoggedToday ? 'Today' : 'Streak',
            accentColor: AppColors.primary,
            backgroundColor: const Color(0xFFEFFBF3),
            route: AppRoutes.streak,
            achievement: true,
            streakDays: achievedDays,
          ),
        );
      }
    }

    return items;
  }

  void _openNotification(_NotificationItem item) {
    setState(() => _readIds.add(item.id));
    if (item.route != null) {
      Get.toNamed(item.route!);
    }
  }

  void _clearNotification(String id) {
    setState(() => _dismissedIds.add(id));
  }
}

class _GreetingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.eco_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greetingTitle(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Let us stay on track with your health goals today.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.notifications_active_rounded,
            color: AppColors.primary.withValues(alpha: 0.35),
            size: 54,
          ),
        ],
      ),
    );
  }

  String _greetingTitle() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning!';
    if (hour < 17) return 'Good afternoon!';
    if (hour < 21) return 'Good evening!';
    return 'Good night!';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.count,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final int? count;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary.withValues(alpha: 0.95),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (actionLabel != null)
          TextButton.icon(
            onPressed: onActionTap,
            label: Text(actionLabel!),
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            iconAlignment: IconAlignment.end,
          ),
      ],
    );
  }
}

class _PriorityNotificationCard extends StatelessWidget {
  const _PriorityNotificationCard({
    required this.item,
    required this.read,
    required this.onTap,
    required this.onClear,
  });

  final _NotificationItem item;
  final bool read;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cardColor = _notificationCardColor(context, item);

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: item.accentColor.withValues(alpha: 0.16)),
          ),
          child: Row(
            children: [
              _LargeNotificationIcon(item: item),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _NotificationTitle(item.title)),
                        Text(
                          item.timeLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (!read) ...[
                          const SizedBox(width: 8),
                          const _UnreadDot(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (item.actionLabel != null) ...[
                      const SizedBox(height: 10),
                      _ActionPill(
                        label: item.actionLabel!,
                        color: item.accentColor,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textSecondary,
                ),
                onSelected: (value) {
                  if (value == 'clear') onClear();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'clear',
                    child: Text('Clear notification'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.item, required this.onTap});

  final _NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = _notificationCardColor(context, item);

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              _LargeNotificationIcon(item: item),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NotificationTitle(item.title),
                    const SizedBox(height: 6),
                    Text(
                      item.body,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StreakDaysBadge(days: item.streakDays ?? 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakDaysBadge extends StatelessWidget {
  const _StreakDaysBadge({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              color: AppColors.primary,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$days',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const Text(
                    'Days',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeNotificationIcon extends StatelessWidget {
  const _LargeNotificationIcon({required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: item.accentColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(item.icon, color: item.accentColor, size: 28),
    );
  }
}

class _NotificationTitle extends StatelessWidget {
  const _NotificationTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
      ),
    );
  }
}

Color _notificationCardColor(BuildContext context, _NotificationItem item) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (isDark) {
    return Color.alphaBlend(
      item.accentColor.withValues(alpha: 0.12),
      AppColors.card,
    );
  }

  return Color.alphaBlend(
    item.accentColor.withValues(alpha: 0.08),
    AppColors.card,
  );
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 56,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'No notifications here',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'New updates will appear on this page.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.accentColor,
    required this.backgroundColor,
    this.route,
    this.priority = false,
    this.achievement = false,
    this.actionLabel,
    this.streakDays,
  });

  final String id;
  final IconData icon;
  final String title;
  final String body;
  final String timeLabel;
  final Color accentColor;
  final Color backgroundColor;
  final String? route;
  final bool priority;
  final bool achievement;
  final String? actionLabel;
  final int? streakDays;
}
