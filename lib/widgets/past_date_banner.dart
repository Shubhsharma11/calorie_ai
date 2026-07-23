import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../theme/app_colors.dart';

/// Persistent notice when Home / Diary are showing a day other than today.
class PastDateBanner extends StatelessWidget {
  const PastDateBanner({
    super.key,
    required this.dateLabel,
    required this.onBackToToday,
    this.message =
        'You\'re viewing a previous day. Home and Diary both show this date.',
  });

  final String dateLabel;
  final VoidCallback onBackToToday;
  final String message;

  static const amber = Color(0xFFFF9800);
  static const amberDark = Color(0xFFE65100);

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        r.scale(12),
        r.scale(10),
        r.scale(8),
        r.scale(10),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: r.scale(34),
            height: r.scale(34),
            decoration: BoxDecoration(
              color: amber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: amberDark,
              size: 20,
            ),
          ),
          SizedBox(width: r.scale(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Viewing $dateLabel',
                  style: TextStyle(
                    fontSize: r.scale(13),
                    fontWeight: FontWeight.w700,
                    color: amberDark,
                  ),
                ),
                SizedBox(height: r.scale(2)),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: r.scale(12),
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onBackToToday,
            style: TextButton.styleFrom(
              foregroundColor: amberDark,
              padding: EdgeInsets.symmetric(horizontal: r.scale(10)),
              minimumSize: Size(0, r.scale(36)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Today',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
