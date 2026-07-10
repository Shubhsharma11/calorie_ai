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

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final compact = maxWidth < 380;
        final veryCompact = maxWidth < 320;

        final label = _label(compact: compact, veryCompact: veryCompact);
        final atRiskHint = isAtRisk ? _atRiskHint(compact: compact) : null;
        final iconSize = r.scale(compact ? 15 : 16);
        final fontSize = r.scale(compact ? 12 : 13);
        final horizontalPadding = r.scale(compact ? 10 : 12);
        final verticalPadding = r.scale(compact ? 6 : 7);

        return Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
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
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: iconSize,
                          color: _streakOrange,
                        ),
                        SizedBox(width: r.scale(compact ? 4 : 5)),
                        Text(
                          label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w600,
                            color: _streakOrange,
                          ),
                        ),
                        if (atRiskHint != null) ...[
                          SizedBox(width: r.scale(4)),
                          if (veryCompact)
                            Container(
                              width: r.scale(6),
                              height: r.scale(6),
                              margin: EdgeInsets.only(right: r.scale(2)),
                              decoration: const BoxDecoration(
                                color: _streakOrange,
                                shape: BoxShape.circle,
                              ),
                            )
                          else
                            Text(
                              atRiskHint,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: r.scale(compact ? 11 : 12),
                                fontWeight: FontWeight.w500,
                                color: _streakOrange.withValues(alpha: 0.85),
                              ),
                            ),
                        ],
                        SizedBox(width: r.scale(2)),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: r.scale(compact ? 16 : 18),
                          color: _streakOrange.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _label({required bool compact, required bool veryCompact}) {
    if (streakDays > 0) {
      if (veryCompact) return '$streakDays-day';
      if (compact) return '$streakDays-day streak';
      return '$streakDays Day Streak';
    }
    if (veryCompact) return 'Streak';
    if (compact) return 'Start streak';
    return 'Start your streak';
  }

  String? _atRiskHint({required bool compact}) {
    if (!isAtRisk) return null;
    return compact ? '· Log' : '· Log today';
  }
}
