import 'package:flutter/material.dart';

import '../core/goal_progress_message.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';

/// Standalone home card for today's progress message.
class TodayProgressCard extends StatelessWidget {
  const TodayProgressCard({
    super.key,
    required this.eaten,
    required this.goal,
    required this.progressPercent,
    required this.isOverGoal,
  });

  final int eaten;
  final int goal;
  final int progressPercent;
  final bool isOverGoal;

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
    final compact = r.width < 360;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.scale(18, tablet: 22)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          SizedBox(height: r.scale(compact ? 8 : 10)),
          Text(
            message.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.scale(compact ? 16 : 18, tablet: 19),
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
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.scale(compact ? 12 : 13),
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  String get _statusLabel {
    if (eaten == 0) return "Today's intake";
    if (isOverGoal) return 'Over daily goal';
    if (progressPercent >= 100) return 'Goal reached';
    return "Today's progress";
  }
}
