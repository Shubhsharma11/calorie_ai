import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../theme/app_colors.dart';

/// Green numbered section label (e.g. "1 Profile").
class ProfileSectionHeader extends StatelessWidget {
  const ProfileSectionHeader({
    super.key,
    required this.number,
    required this.title,
    this.titleColor,
  });

  final int number;
  final String title;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return Padding(
      padding: EdgeInsets.only(bottom: r.scale(12)),
      child: Row(
        children: [
          Container(
            width: r.scale(28),
            height: r.scale(28),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: r.scale(14),
              ),
            ),
          ),
          SizedBox(width: r.scale(10)),
          Text(
            title,
            style: TextStyle(
              fontSize: r.scale(17, tablet: 18),
              fontWeight: FontWeight.w700,
              color: titleColor ?? AppColors.textPrimaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded card used across profile sub-screens.
class ProfileSectionCard extends StatelessWidget {
  const ProfileSectionCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(20),
        vertical: r.scale(20),
      ),
      child: child,
    );
  }
}

class ProfileMenuRow extends StatelessWidget {
  const ProfileMenuRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: context.responsive.scale(16, tablet: 18),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: context.responsive.scale(26, tablet: 28),
              color: AppColors.primary,
            ),
            SizedBox(width: context.responsive.scale(18)),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: context.responsive.scale(16, tablet: 17),
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: context.responsive.scale(24),
              color: AppColors.textSecondaryOf(context),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileGoalField extends StatelessWidget {
  const ProfileGoalField({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.onTap,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return Material(
      color: AppColors.cardOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderOf(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(16),
            vertical: r.scale(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: r.scale(13),
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    SizedBox(height: r.scale(4)),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: r.scale(18, tablet: 19),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: r.scale(2)),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: r.scale(12),
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                icon ?? Icons.chevron_right_rounded,
                size: r.scale(22),
                color: iconColor ?? AppColors.textSecondaryOf(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileGoalProgressCard extends StatelessWidget {
  const ProfileGoalProgressCard({
    super.key,
    required this.progress,
    this.goalSet = true,
    this.detail,
  });

  final double progress;
  final bool goalSet;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final progressPct = (progress * 100).round();
    final label = goalSet ? '$progressPct%' : '—';
    final barValue = goalSet ? progress : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(16),
        vertical: r.scale(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: TextStyle(
                  fontSize: r.scale(13),
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: r.scale(16),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ],
          ),
          if (detail != null) ...[
            SizedBox(height: r.scale(4)),
            Text(
              detail!,
              style: TextStyle(
                fontSize: r.scale(12),
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
          SizedBox(height: r.scale(12)),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: barValue,
              minHeight: r.scale(8),
              backgroundColor: AppColors.borderOf(context),
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
