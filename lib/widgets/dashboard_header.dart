import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../theme/app_colors.dart';
import 'rotating_motivation_text.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.userName,
    this.showNotificationBadge = false,
    this.onSearch,
    this.onCalendar,
    this.onNotifications,
  });

  final String userName;
  final bool showNotificationBadge;
  final VoidCallback? onSearch;
  final VoidCallback? onCalendar;
  final VoidCallback? onNotifications;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

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
                  Text(
                    'Hello, $userName 👋',
                    style: TextStyle(
                      fontSize: r.scale(24, tablet: 26, desktop: 28),
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: r.scale(6)),
                  const RotatingMotivationText(),
                ],
              ),
            ),
            _HeaderIconButton(
              icon: Icons.search_rounded,
              onTap: onSearch,
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
