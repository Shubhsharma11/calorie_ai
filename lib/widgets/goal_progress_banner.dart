import 'package:flutter/material.dart';

import '../core/goal_progress_message.dart';
import '../theme/app_colors.dart';

/// Green encouragement card shown below water intake on the home screen.
class GoalProgressBanner extends StatelessWidget {
  const GoalProgressBanner({
    super.key,
    required this.consumed,
    required this.goal,
    required this.progressPercent,
    this.onTap,
  });

  final int consumed;
  final int goal;
  final int progressPercent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final message = GoalProgressMessage.forIntake(
      consumed: consumed,
      goal: goal,
      progressPercent: progressPercent,
    );

    return Material(
      color: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  message.icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: Column(
                    key: ValueKey('${message.title}-${message.subtitle}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
