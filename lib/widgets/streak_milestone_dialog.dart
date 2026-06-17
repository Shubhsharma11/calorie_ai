import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';

/// Celebration when the user hits a streak milestone.
class StreakMilestoneDialog extends StatelessWidget {
  const StreakMilestoneDialog({super.key, required this.days});

  final int days;

  static const _streakOrange = Color(0xFFFF9800);

  static Future<void> show({required int days}) {
    return Get.dialog<void>(
      StreakMilestoneDialog(days: days),
      barrierDismissible: true,
      barrierColor: Colors.black54,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _streakOrange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                color: _streakOrange,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$days-Day Streak!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _messageFor(days),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: Get.back,
                child: const Text('Keep it going'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _messageFor(int days) => switch (days) {
        3 => 'Three days in a row — consistency is building.',
        7 => 'A full week of logging. That is real momentum.',
        14 => 'Two weeks strong. You are making this a habit.',
        30 => 'One month streak. Incredible dedication.',
        60 => 'Sixty days. You are unstoppable.',
        100 => 'One hundred days. Legendary consistency.',
        _ => 'Amazing work staying consistent.',
      };
}
