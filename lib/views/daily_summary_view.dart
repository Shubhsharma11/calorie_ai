import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/daily_summary_controller.dart';
import '../controllers/food_controller.dart';
import '../controllers/main_controller.dart';
import '../controllers/tracker_controller.dart';
import '../core/dashboard_actions.dart';
import '../core/responsive.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/rotating_motivation_text.dart';

class DailySummaryView extends GetView<DailySummaryController> {
  const DailySummaryView({super.key});

  static const _blue = Color(0xFF007AFF);
  static const _orange = Color(0xFFFF9500);
  static const _purple = Color(0xFF8B5CF6);

  static const _headlineMessages = [
    "You're doing great! 🎉",
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
            onPressed: () => DashboardActions.openCalendar(context),
          ),
        ],
      ),
      body: Obx(() {
        final _ = food.entriesRevision.value;
        Get.find<TrackerController>().waterGlasses;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            r.scale(16),
            0,
            r.scale(16),
            r.scale(24),
          ),
          children: [
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
            SizedBox(height: r.scale(20)),
            _WeeklyProgressSection(),
            SizedBox(height: r.scale(20)),
            _NextGoalCard(),
            SizedBox(height: r.scale(20)),
            _BottomStatsRow(),
          ],
        );
      }),
    );
  }
}

class _MotivationBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: Color(0xFFFFB800),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RotatingMotivationText(
                  messages: DailySummaryView._headlineMessages,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Keep moving toward your goal.',
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
    final percent = controller.progressPercent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
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
              const Expanded(
                child: Text(
                  "Today's Overview",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: onViewDetails,
                child: const Text('View Details >'),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
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
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: percent / 100,
                          strokeWidth: 8,
                          backgroundColor: AppColors.surface,
                          color: AppColors.primary,
                        ),
                        Text(
                          '$percent%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Goal Progress',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              backgroundColor: AppColors.surface,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "You're $percent% closer to your calorie goal today.",
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
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
                'You have ${controller.totalAchievements} total achievements!',
              ),
              child: const Text('See All >'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _AchievementChip(
                icon: Icons.water_drop_rounded,
                color: DailySummaryView._blue,
                title: 'Water Goal Completed',
                subtitle: controller.waterGoalCompleted
                    ? controller.waterMlOverGoal > 0
                        ? '+${controller.waterMlOverGoal} ml over goal'
                        : 'Great job!'
                    : '${controller.waterMlRemaining} ml left',
                onTap: () => Get.toNamed(AppRoutes.waterTracker),
              ),
              const SizedBox(width: 10),
              _AchievementChip(
                icon: Icons.restaurant_rounded,
                color: AppColors.primary,
                title: 'Logged All Meals Today',
                subtitle: controller.allMealsLogged ? 'Awesome!' : 'Keep logging',
                onTap: () {
                  Get.find<MainController>().changeTab(1);
                  Get.back();
                },
              ),
              const SizedBox(width: 10),
              _AchievementChip(
                icon: Icons.local_fire_department_rounded,
                color: DailySummaryView._orange,
                title: '${controller.loggingStreak}-Day Streak',
                subtitle: controller.streakSubtitle,
                onTap: () => Get.toNamed(AppRoutes.streak),
              ),
            ],
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
    final proteinGap = controller.proteinGap;
    final waterLeftMl = controller.waterMlRemaining;
    final weeklyChange = controller.weeklyCalorieChangePercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Smart Insights',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (proteinGap > 0)
          _InsightTile(
            icon: Icons.bar_chart_rounded,
            iconColor: DailySummaryView._purple,
            text: 'Your protein intake is ',
            bold: '${proteinGap}g below',
            suffix: ' target. Try adding more protein-rich foods.',
            onTap: () => Get.toNamed(AppRoutes.addFood),
          ),
        if (waterLeftMl > 0)
          _InsightTile(
            icon: Icons.water_drop_rounded,
            iconColor: DailySummaryView._blue,
            text: 'Drink ',
            bold: '$waterLeftMl ml more',
            suffix: ' water to complete today\'s hydration goal.',
            onTap: () => Get.toNamed(AppRoutes.waterTracker),
          ),
        _InsightTile(
          icon: Icons.trending_up_rounded,
          iconColor: AppColors.primary,
          text: weeklyChange <= 0
              ? 'You are eating '
              : 'You are eating ',
          bold: weeklyChange <= 0
              ? '${weeklyChange.abs()}% fewer'
              : '$weeklyChange% more',
          suffix: ' calories than earlier this week. '
              '${weeklyChange <= 0 ? 'Great consistency!' : 'Stay mindful of your goal.'}',
          onTap: () {
            Get.find<MainController>().changeTab(3);
            Get.back();
          },
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

class _WeeklyProgressSection extends GetView<DailySummaryController> {
  @override
  Widget build(BuildContext context) {
    final bars = controller.weeklyBars;
    final maxBarHeight = 120.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Weekly Progress',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Text(
                      'This Week',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: maxBarHeight + 36,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bars.map((bar) {
                final h = bar.hasData
                    ? (bar.percent / 100 * maxBarHeight).clamp(8.0, maxBarHeight)
                    : 8.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (bar.hasData)
                          Text(
                            '${bar.percent}%',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else
                          const Text('—', style: TextStyle(fontSize: 9)),
                        const SizedBox(height: 4),
                        Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: bar.hasData
                                ? AppColors.primary
                                : AppColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bar.day,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextGoalCard extends GetView<DailySummaryController> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_rounded, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.nextGoalTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "You're almost there!",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB800).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 16),
                SizedBox(width: 4),
                Text(
                  '+50 XP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class _BottomStatsRow extends GetView<DailySummaryController> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatMiniCard(
          icon: Icons.military_tech_rounded,
          color: DailySummaryView._purple,
          value: '${controller.totalAchievements}',
          label: 'Total Achievements',
          subtitle: 'Keep going!',
        ),
        const SizedBox(width: 8),
        _StatMiniCard(
          icon: Icons.local_fire_department_rounded,
          color: DailySummaryView._orange,
          value: '${controller.loggingStreak}',
          label: 'Day Streak',
          subtitle: 'Amazing!',
        ),
        const SizedBox(width: 8),
        _StatMiniCard(
          icon: Icons.favorite_rounded,
          color: DailySummaryView._blue,
          value: '${controller.healthScore}/100',
          label: 'Health Score',
          subtitle: 'Good',
        ),
      ],
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  const _StatMiniCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 9, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
