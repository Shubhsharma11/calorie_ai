import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';

class RepeatYesterdayCard extends StatelessWidget {
  const RepeatYesterdayCard({
    super.key,
    required this.dayLabel,
    required this.mealCount,
    required this.calories,
    required this.onRepeat,
    required this.onDismiss,
  });

  final String dayLabel;
  final int mealCount;
  final int calories;
  final VoidCallback onRepeat;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final kcalLabel = NumberFormat('#,###').format(calories);
    final mealsLabel = mealCount == 1 ? '1 meal' : '$mealCount meals';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.replay_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Repeat last logged meals',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dayLabel.isEmpty
                            ? 'Copy a previous day’s meals in one tap.'
                            : 'Last logged on $dayLabel. Copy in one tap.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                visualDensity: VisualDensity.compact,
                tooltip: 'Dismiss',
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Compact pills — same language as the date chip on this screen.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaPill(
                background: AppColors.primary.withValues(alpha: 0.10),
                icon: Image.asset(
                  'assets/image/food.png',
                  width: 18,
                  height: 18,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                label: mealsLabel,
                labelColor: AppColors.textPrimary,
              ),
              _MetaPill(
                background: AppColors.warning.withValues(alpha: 0.12),
                icon: Image.asset(
                  'assets/image/flame.png',
                  width: 15,
                  height: 15,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                label: '$kcalLabel kcal',
                labelColor: AppColors.textPrimary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRepeat,
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text(
                'Repeat Meals',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.background,
    required this.icon,
    required this.label,
    required this.labelColor,
  });

  final Color background;
  final Widget icon;
  final String label;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}


