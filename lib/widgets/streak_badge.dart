import 'package:flutter/material.dart';

import '../core/responsive.dart';

/// Orange pill badge showing the user's logging streak on the home screen.
class StreakBadge extends StatelessWidget {
  const StreakBadge({
    super.key,
    required this.streakDays,
    this.isAtRisk = false,
    this.onTap,
  });

  final int streakDays;
  final bool isAtRisk;
  final VoidCallback? onTap;

  static const _streakOrange = Color(0xFFFF9800);

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    final label = streakDays > 0
        ? '$streakDays Day Streak'
        : 'Start your streak';

    return Padding(
      padding: EdgeInsets.only(top: r.scale(12)),
      child: Material(
        color: isAtRisk
            ? _streakOrange.withValues(alpha: 0.18)
            : _streakOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: r.scale(12),
              vertical: r.scale(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: r.scale(16),
                  color: _streakOrange,
                ),
                SizedBox(width: r.scale(4)),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: r.scale(13),
                    fontWeight: FontWeight.w600,
                    color: _streakOrange,
                  ),
                ),
                if (isAtRisk) ...[
                  SizedBox(width: r.scale(4)),
                  Text(
                    '· Log today',
                    style: TextStyle(
                      fontSize: r.scale(12),
                      color: _streakOrange.withValues(alpha: 0.85),
                    ),
                  ),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  size: r.scale(18),
                  color: _streakOrange.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
