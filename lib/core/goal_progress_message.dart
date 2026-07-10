import 'package:flutter/material.dart';

/// Headline and detail for the home-screen goal progress banner.
class GoalProgressMessage {
  const GoalProgressMessage({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isOverGoal = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isOverGoal;

  static GoalProgressMessage forIntake({
    required int consumed,
    required int goal,
    required int progressPercent,
  }) {
    if (goal <= 0) {
      return const GoalProgressMessage(
        title: 'Set your daily goal',
        subtitle: 'Complete your profile to get a calorie target.',
        icon: Icons.flag_rounded,
      );
    }

    if (consumed == 0) {
      return const GoalProgressMessage(
        title: 'No calories logged yet',
        subtitle:
            'Start logging your meals and activities to track your progress.',
        icon: Icons.restaurant_outlined,
      );
    }

    if (goal > 0 && consumed > goal) {
      final over = consumed - goal;
      return GoalProgressMessage(
        title: '$over kcal over your goal',
        subtitle: 'You\'ve passed today\'s target. Stay mindful of the rest.',
        icon: Icons.warning_amber_rounded,
        isOverGoal: true,
      );
    }

    if (progressPercent >= 100) {
      return const GoalProgressMessage(
        title: 'Daily goal complete',
        subtitle: 'You\'ve reached today\'s target.',
        icon: Icons.check_circle_outline_rounded,
      );
    }

    if (progressPercent >= 80) {
      return GoalProgressMessage(
        title: 'Almost there',
        subtitle: '$progressPercent% of your daily goal.',
        icon: Icons.trending_up_rounded,
      );
    }

    if (progressPercent >= 50) {
      return GoalProgressMessage(
        title: 'You\'re on track',
        subtitle: '$progressPercent% of your daily goal.',
        icon: Icons.trending_up_rounded,
      );
    }

    if (progressPercent >= 25) {
      return GoalProgressMessage(
        title: 'Making progress',
        subtitle: '$progressPercent% of your daily goal.',
        icon: Icons.trending_up_rounded,
      );
    }

    return GoalProgressMessage(
      title: 'Good start',
      subtitle: '$progressPercent% of your daily goal.',
      icon: Icons.trending_up_rounded,
    );
  }
}
