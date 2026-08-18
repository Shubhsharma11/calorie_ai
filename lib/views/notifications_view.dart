import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/notifications_controller.dart';
import '../core/responsive.dart';
import '../models/notification_model.dart';
import '../models/notification_type.dart';
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
  late final NotificationsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<NotificationsController>()
        ? Get.find<NotificationsController>()
        : Get.put(NotificationsController(), permanent: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadNotifications(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    AppColors.syncFromContext(context);

    return Scaffold(
      appBar: AppAppBar(
        title: 'Notifications',
        
          
        
      ),
      body: ResponsivePage(
        scrollable: false,
        child: Obx(() {
          final items = _controller.notifications.toList();
          final isLoading = _controller.isLoading.value;
          final error = _controller.errorMessage.value;
          final unread = items.where((item) => !item.isRead).toList();

final earlier = items
    .where(
      (item) =>
          item.isRead &&
          item.type != NotificationType.goalAchieved,
    )
    .toList();

final achievements = items
    .where(
      (item) =>
          item.isRead &&
          item.type == NotificationType.goalAchieved,
    )
    .toList();
          

          if (isLoading && items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () => _controller.loadNotifications(force: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: r.scale(6)),
                if (error != null && items.isEmpty) ...[
                  _ErrorState(
                    message: error,
                    onRetry: () => _controller.loadNotifications(force: true),
                  ),
                ]  else ...[
  if (items.isNotEmpty) ...[
    ..._buildDateGroupedNotifications(items, r),
  ],
                 
                  if (items.isEmpty) const _EmptyNotifications(),
                ],
                SizedBox(
                  height:
                      MediaQuery.viewPaddingOf(context).bottom + r.scale(24),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
  List<Widget> _buildDateGroupedNotifications(
  List<NotificationModel> items,
  Responsive r,
) {
  final grouped = <DateTime, List<NotificationModel>>{};

  for (final item in items) {
    if (item.createdAt == null) continue;

    final createdAt = item.createdAt!;

    final date = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    );

    grouped.putIfAbsent(date, () => []).add(item);
  }

  final dates = grouped.keys.toList()
    ..sort((a, b) => b.compareTo(a));

  final widgets = <Widget>[];

  for (final date in dates) {
    widgets.add(
      _DateHeader(date: date),
    );

    for (final item in grouped[date]!) {
      widgets.add(
        _SwipeNotificationCard(
          item: item,
          onTap: () => _openNotification(item),
          onRemove: () => _removeNotification(item),
        ),
      );

      widgets.add(
        SizedBox(height: r.scale(6)),
      );
    }
  }

  return widgets;
}

  Future<void> _openNotification(NotificationModel item) async {
    await _controller.openNotification(item);
    final route = item.route;
    if (route.isNotEmpty && route != AppRoutes.notifications) {
      Get.toNamed(route);
    }
  }

  void _removeNotification(NotificationModel item) {
    final removed = _controller.dismissNotification(item);
    if (removed == null) return;
    Get.closeAllSnackbars();
    Get.showSnackbar(
      GetSnackBar(
        messageText: const Text(
          'Notification removed',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        duration: const Duration(seconds: 3),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1E1F23),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        borderRadius: 12,
        mainButton: TextButton(
          onPressed: () => _controller.restoreDismissedNotification(removed),
          child: const Text(
            'UNDO',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeNotificationCard extends StatelessWidget {
  const _SwipeNotificationCard({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  final NotificationModel item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final keyId = item.id ?? item.messageId ?? item.createdAt?.toIso8601String();
    return Dismissible(
      key: ValueKey('notif-$keyId-${item.title}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        color: AppColors.error.withValues(alpha: 0.08),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 22,
            ),
          ],
        ),
      ),
      child: _NotificationCard(
        item: item,
        onTap: onTap,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.count,
  });

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.date,
  });

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('MMM d, yyyy').format(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 7,
          ),
          decoration: BoxDecoration(
  color: Colors.transparent,
  borderRadius: BorderRadius.circular(10),
  border: Border.all(
    color: AppColors.primary.withValues(alpha: 0.65),
    width: 1,
  ),
),
          child: Text(
            dateText,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onTap,
  });

  final NotificationModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(item.type);
    final isUnread = !item.isRead;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
         padding: const EdgeInsets.symmetric(
  horizontal: 12,
  vertical: 12,
),
          decoration: BoxDecoration(
  color: Colors.transparent,
  borderRadius: BorderRadius.circular(14),
  border: Border.all(
    color: AppColors.border.withValues(alpha: 0.55),
    width: 1.2,
  ),
),
          
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _NotificationLeading(
                visual: visual,
                isUnread: isUnread,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: RichText(
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: item.title?.trim().isNotEmpty == true
                                      ? item.title!
                                      : 'Notification',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isUnread
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    height: 1.28,
                                  ),
                                ),
                                TextSpan(
                                  text: item.body?.trim().isNotEmpty == true
                                      ? ' ${item.body!}'
                                      : ' Tap to open.',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                    height: 1.28,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(item.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime? createdAt) {
    if (createdAt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24 && now.day == createdAt.day) {
      return '${diff.inHours} h ago';
    }
    if (diff.inDays < 7) return DateFormat.E().format(createdAt);
    return DateFormat.MMMd().format(createdAt);
  }

}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
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

class _NotificationLeading extends StatelessWidget {
  const _NotificationLeading({
    required this.visual,
    required this.isUnread,
  });

  final _NotificationVisual visual;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: visual.accent.withValues(alpha: isUnread ? 0.13 : 0.09),
        shape: BoxShape.circle,
      ),
      child: Icon(visual.icon, color: visual.accent, size: 20),
    );
  }
}

class _NotificationVisual {
  const _NotificationVisual(this.icon, this.accent);

  final IconData icon;
  final Color accent;
}
_NotificationVisual _visualFor(NotificationType type) {
  switch (type) {
    // Meal notifications
    case NotificationType.mealReminder:
  return const _NotificationVisual(
    Icons.restaurant_menu_rounded,
    AppColors.primary,
  );

case NotificationType.breakfastReminder:
  return const _NotificationVisual(
    Icons.wb_sunny_rounded,
    AppColors.primary,
  );

case NotificationType.lunchReminder:
  return const _NotificationVisual(
    Icons.wb_sunny_outlined,
    AppColors.primary,
  );

case NotificationType.dinnerReminder:
  return const _NotificationVisual(
    Icons.nightlight_round,
    AppColors.primary,
  );

    // Water
    case NotificationType.waterReminder:
      return const _NotificationVisual(
        Icons.water_drop_rounded,
        AppColors.primary,
      );

    // Workout
    case NotificationType.workoutReminder:
      return const _NotificationVisual(
        Icons.fitness_center_rounded,
        AppColors.primary,
      );

    // Streak / Goal
    case NotificationType.dailyStreakReminder:
    case NotificationType.goalAchieved:
      return const _NotificationVisual(
        Icons.emoji_events_rounded,
        AppColors.primary,
      );

    // Weekly report
    case NotificationType.weeklyReport:
      return const _NotificationVisual(
        Icons.bar_chart_rounded,
        AppColors.primary,
      );

    // Weight
    case NotificationType.weightReminder:
      return const _NotificationVisual(
        Icons.monitor_weight_rounded,
        AppColors.primary,
      );

    // AI tips
    case NotificationType.aiNutritionTips:
      return const _NotificationVisual(
        Icons.auto_awesome_rounded,
        AppColors.primary,
      );

    // Motivation
    case NotificationType.motivational:
      return const _NotificationVisual(
        Icons.favorite_rounded,
        AppColors.primary,
      );

    // Unknown
    case NotificationType.unknown:
      return const _NotificationVisual(
        Icons.notifications_rounded,
        AppColors.primary,
      );
  }
}
