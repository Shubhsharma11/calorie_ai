import 'package:flutter/material.dart';

/// Headline and detail for the home-screen goal progress banner.
class GoalProgressMessage {
  const GoalProgressMessage({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

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
        title: 'Ready to fuel your day?',
        subtitle: 'Log your first meal to start tracking today.',
        icon: Icons.restaurant_outlined,
      );
    }

    if (progressPercent >= 100) {
      final over = consumed - goal;
      if (over > 0) {
        return const GoalProgressMessage(
          title: 'Daily goal reached!',
          subtitle: 'You are slightly above today\'s target. Stay mindful.',
          icon: Icons.emoji_events_rounded,
        );
      }
      return const GoalProgressMessage(
        title: 'You hit your goal! 🎉',
        subtitle: 'Goal complete for today — well done!',
        icon: Icons.emoji_events_rounded,
      );
    }

    if (progressPercent >= 80) {
      return GoalProgressMessage(
        title: 'Almost there!',
        subtitle: 'You are $progressPercent% toward your goal today.',
        icon: Icons.trending_up_rounded,
      );
    }

    if (progressPercent >= 50) {
      return GoalProgressMessage(
        title: "You're doing great!",
        subtitle: 'You are $progressPercent% closer to your goal today.',
        icon: Icons.trending_up_rounded,
      );
    }

    if (progressPercent >= 25) {
      return GoalProgressMessage(
        title: 'Nice progress!',
        subtitle: 'You are $progressPercent% of the way there — keep going.',
        icon: Icons.local_fire_department_outlined,
      );
    }

    return GoalProgressMessage(
      title: 'Good start!',
      subtitle:
          'You are $progressPercent% toward your goal · keep building momentum.',
      icon: Icons.wb_sunny_outlined,
    );
  }
}
