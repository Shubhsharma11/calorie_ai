import 'package:flutter/material.dart';

import '../core/app_coach_marks.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';
import 'rotating_motivation_text.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.firstName,
    this.showNotificationBadge = false,
    this.onSearch,
    this.onCalendar,
    this.onNotifications,
    this.searchShowcaseKey,
  });

  final String firstName;
  final bool showNotificationBadge;
  final VoidCallback? onSearch;
  final VoidCallback? onCalendar;
  final VoidCallback? onNotifications;
  final GlobalKey? searchShowcaseKey;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final greeting = _Greeting.forNow();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: r.scale(24),
                        height: r.scale(24),
                        decoration: BoxDecoration(
                          color: greeting.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          greeting.icon,
                          size: r.scale(15),
                          color: greeting.color,
                        ),
                      ),
                      SizedBox(width: r.scale(8)),
                      Flexible(
                        child: Text(
                          greeting.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: r.scale(13, tablet: 14),
                            fontWeight: FontWeight.w700,
                            color: greeting.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: r.scale(4)),
                  Text(
                    firstName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: r.scale(28, tablet: 30, desktop: 32),
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.05,
                    ),
                  ),
                  SizedBox(height: r.scale(6)),
                  RotatingMotivationText(
                    style: TextStyle(
                      fontSize: r.scale(14),
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: r.scale(12)),
                ],
              ),
            ),
            _wrapSearchShowcase(
              context,
              _HeaderIconButton(icon: Icons.search_rounded, onTap: onSearch),
            ),
            SizedBox(width: r.scale(8)),
            _HeaderIconButton(
              icon: Icons.calendar_today_rounded,
              onTap: onCalendar,
            ),
            SizedBox(width: r.scale(8)),
            _HeaderIconButton(
              icon: Icons.notifications_none_rounded,
              showBadge: showNotificationBadge,
              onTap: onNotifications,
            ),
          ],
        ),
      ],
    );
  }

  Widget _wrapSearchShowcase(BuildContext context, Widget child) {
    final key = searchShowcaseKey;
    if (key == null) return child;
    return AppCoachMarks.target(key: key, child: child);
  }
}

class _Greeting {
  const _Greeting(this.message, this.icon, this.color);

  final String message;
  final IconData icon;
  final Color color;

  factory _Greeting.forNow([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 5) {
      return const _Greeting(
        'Good night',
        Icons.dark_mode_rounded,
        Color(0xFF7C8CFF),
      );
    }
    if (hour < 12) {
      return const _Greeting(
        'Good morning',
        Icons.wb_sunny_rounded,
        Color(0xFFFFB800),
      );
    }
    if (hour < 17) {
      return const _Greeting(
        'Good afternoon',
        Icons.wb_twilight_rounded,
        Color(0xFFFF9500),
      );
    }
    if (hour < 21) {
      return const _Greeting(
        'Good evening',
        Icons.nights_stay_rounded,
        Color(0xFF8B5CF6),
      );
    }
    return const _Greeting(
      'Good night',
      Icons.dark_mode_rounded,
      Color(0xFF7C8CFF),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    this.onTap,
    this.showBadge = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 22, color: AppColors.textPrimary),
              if (showBadge)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
