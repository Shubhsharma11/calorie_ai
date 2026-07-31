import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../controllers/daily_summary_controller.dart';
import '../controllers/food_controller.dart';
import '../controllers/main_controller.dart';
import '../controllers/tracker_controller.dart';
import '../controllers/user_controller.dart';
import '../core/dashboard_actions.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/past_date_banner.dart';
import '../widgets/rotating_motivation_text.dart';

class DailySummaryView extends GetView<DailySummaryController> {
  const DailySummaryView({super.key});

  static const _blue = Color(0xFF007AFF);
  static const _orange = Color(0xFFFF9500);

  static const _headlineMessages = [
    "You're doing great!",
    'Stay focused and healthy!',
    'Keep moving toward your goal.',
    'Every meal counts — keep it up!',
  ];

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final food = Get.find<FoodController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppAppBar(
        title: 'Daily Summary',
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
            tooltip: 'View another day',
            onPressed: () => DashboardActions.openCalendar(context),
          ),
        ],
      ),
      body: Obx(() {
        food.entriesRevision.value;
        food.selectedLogDate.value;
        Get.find<TrackerController>().waterRevision.value;
        Get.find<TrackerController>().activityRevision.value;
        Get.find<TrackerController>().weightRevision.value;
        if (Get.isRegistered<UserController>()) {
          Get.find<UserController>().calorieGoalRevision.value;
        }

        final viewingToday = controller.isViewingToday;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            r.scale(16),
            r.scale(8),
            r.scale(16),
            MediaQuery.paddingOf(context).bottom + r.scale(24),
          ),
          children: [
            if (!viewingToday) ...[
              PastDateBanner(
                dateLabel: controller.dateLabel,
                message: 'Showing this day\'s summary. Tap Today to go back.',
                onBackToToday: controller.backToToday,
              ),
              SizedBox(height: r.scale(14)),
            ],
            _MotivationBanner(),
            SizedBox(height: r.scale(20)),
            _TodayOverviewCard(
              onViewDetails: () {
                Get.find<MainController>().changeTab(1);
                Get.back();
              },
            ),
            SizedBox(height: r.scale(20)),
            _AchievementsSection(),
            SizedBox(height: r.scale(20)),
            _SmartInsightsSection(),
          ],
        );
      }),
    );
  }
}

class _MotivationBanner extends GetView<DailySummaryController> {
  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final viewingToday = controller.isViewingToday;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: r.scale(56),
            height: r.scale(56),
            child: Lottie.asset(
              'assets/image/Trophy.json',
              fit: BoxFit.contain,
              repeat: true,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.emoji_events_rounded,
                color: const Color(0xFFFFB800),
                size: r.scale(32),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (viewingToday)
                  RotatingMotivationText(
                    messages: DailySummaryView._headlineMessages,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  )
                else
                  Text(
                    controller.motivationTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  controller.motivationSubtitle,
                  style: TextStyle(
                    fontSize: 13,
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
}

class _TodayOverviewCard extends GetView<DailySummaryController> {
  const _TodayOverviewCard({required this.onViewDetails});

  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${controller.dayPossessive} Overview',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: onViewDetails,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View Details >'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _OverviewRow(
            color: AppColors.primary,
            label: 'Calories Goal',
            value: '${controller.calorieGoal} kcal',
          ),
          const SizedBox(height: 10),
          _OverviewRow(
            color: DailySummaryView._blue,
            label: 'Consumed',
            value: '${controller.consumed} kcal',
          ),
          const SizedBox(height: 10),
          _OverviewRow(
            color: DailySummaryView._orange,
            label: 'Remaining',
            value: '${controller.remaining} kcal',
          ),
        ],
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}

class _AchievementsSection extends GetView<DailySummaryController> {
  @override
  Widget build(BuildContext context) {
    final achievements = controller.unlockedAchievements;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Achievements',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => Get.snackbar(
                'Achievements',
                achievements.isEmpty
                    ? 'Complete goals to unlock achievements.'
                    : 'You have ${achievements.length} unlocked!',
              ),
              child: const Text('See All >'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: achievements.isEmpty
              ? _AchievementChip(
                  icon: Icons.emoji_events_outlined,
                  color: AppColors.textSecondary,
                  title: 'No achievements yet',
                  subtitle: 'Keep logging to unlock',
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: achievements.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final item = achievements[index];
                    return _AchievementChip(
                      icon: item.icon,
                      color: item.color,
                      title: item.title,
                      subtitle: item.subtitle,
                      onTap: () {
                        if (item.openFoodTab) {
                          Get.find<MainController>().changeTab(1);
                          Get.back();
                          return;
                        }
                        if (item.route != null) {
                          Get.toNamed(item.route!);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AchievementChip extends StatelessWidget {
  const _AchievementChip({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmartInsightsSection extends GetView<DailySummaryController> {
  @override
  Widget build(BuildContext context) {
    final insights = controller.smartInsights;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Smart Insights',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (insights.isEmpty)
          _InsightTile(
            icon: Icons.lightbulb_outline_rounded,
            iconColor: AppColors.primary,
            text: 'Keep logging meals and water to unlock ',
            bold: 'personal insights',
            suffix: controller.isViewingToday
                ? ' for today.'
                : ' for this day.',
            onTap: () {
              Get.find<MainController>().changeTab(1);
              Get.back();
            },
          )
        else
          ...insights.map(
            (insight) => _InsightTile(
              icon: insight.icon,
              iconColor: insight.iconColor,
              text: insight.text,
              bold: insight.bold,
              suffix: insight.suffix,
              onTap: () {
                if (insight.openFoodTab) {
                  Get.find<MainController>().changeTab(1);
                  Get.back();
                  return;
                }
                if (insight.openAnalyticsTab) {
                  Get.find<MainController>().changeTab(3);
                  Get.back();
                  return;
                }
                if (insight.route != null) {
                  Get.toNamed(insight.route!);
                }
              },
            ),
          ),
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.bold,
    required this.suffix,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final String bold;
  final String suffix;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(text: text),
                        TextSpan(
                          text: bold,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: suffix),
                      ],
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
