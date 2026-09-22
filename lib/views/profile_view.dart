import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/user_controller.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../models/goal_type.dart';
import '../models/user_model.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/privacy_policy_dialog.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_photo_sheet.dart';
import '../widgets/terms_of_service_dialog.dart';

class ProfileView extends GetView<UserController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);

    final r = context.responsive;
    final horizontalPadding = r.scale(20, tablet: 28, desktop: 32);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final bottomPad = r.scale(110) + bottomInset;

    return ColoredBox(
      color: AppColors.background,
      child: GetBuilder<UserController>(
        builder: (ctrl) {
          final isAppleProfile = Platform.isIOS && ctrl.authProvider == 'apple';
          final user = ctrl.user;
          final signingOut = ctrl.isLoggingOut || ctrl.isDeletingAccount;
          // While Signing out, keep the last Profile paint under the barrier.
          // Never show "Loading your profile…" just because tokens were cleared.
          final profileSettling = !signingOut &&
              ctrl.isLoggedIn &&
              (ctrl.isLoadingProfile || !user.hasProfileBasics);

          if (profileSettling) {
            return _ProfileSettlingState(
              horizontalPadding: horizontalPadding,
              bottomPad: bottomPad,
            );
          }

          if (!ctrl.isLoggedIn && !signingOut && !user.hasProfileBasics) {
            return ColoredBox(color: AppColors.background);
          }

          if (!user.hasProfileBasics) {
            // Signing out after defaults reset, one frame before nav — keep calm.
            return ColoredBox(color: AppColors.background);
          }

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              r.scale(8),
              horizontalPadding,
              bottomPad,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: r.scale(28, tablet: 30),
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: r.scale(18)),
                _ProfileIdentityRow(
                  user: user,
                  isAppleProfile: isAppleProfile,
                  isUploadingAvatar: ctrl.isUploadingAvatar,
                  onAvatarTap: () {
                    if (isAppleProfile && user.hasProfilePhoto) {
                      showProfilePhotoViewer(context: context, user: user);
                      return;
                    }
                    ctrl.showProfilePhotoOptions(context);
                  },
                  onEditTap: () => showEditProfileBottomSheet(
                    context: context,
                    controller: ctrl,
                  ),
                ),
                SizedBox(height: r.scale(18)),
                _OverviewCard(
                  title: 'Body Overview',
                  icon: Icons.monitor_heart_outlined,
                  onTap: () => Get.toNamed(AppRoutes.personalInformation),
                  children: [
                    _MetricTile(
                      icon: Icons.monitor_weight_outlined,
                      label: 'Weight',
                      value: user.weightKg != null && user.weightKg! > 0
                          ? '${user.weightKg}kg'
                          : '—',
                    ),
                    _MetricTile(
                      icon: Icons.height_rounded,
                      label: 'Height',
                      value: user.heightCm != null && user.heightCm! > 0
                          ? '${user.heightCm}cm'
                          : '—',
                    ),
                    _MetricTile(
                      icon: Icons.cake_outlined,
                      label: 'Age',
                      value: user.age != null && user.age! > 0
                          ? '${user.age}yrs'
                          : '—',
                    ),
                  ],
                ),
                SizedBox(height: r.scale(12)),
                _OverviewCard(
                  title: 'My Goal',
                  icon: Icons.flag_outlined,
                  onTap: () => Get.toNamed(AppRoutes.myGoals),
                  children: [
                    _MetricTile(
                      icon: Icons.monitor_weight_outlined,
                      label: 'Weight',
                      value: user.goalWeightKg > 0
                          ? '${user.goalWeightKg.round()}kg'
                          : '—',
                      trailing: _goalTrendIcon(user),
                    ),
                    _MetricTile(
                      icon: Icons.local_fire_department_outlined,
                      label: 'Daily Calories',
                      value: user.dailyCalorieGoal > 0
                          ? '${user.dailyCalorieGoal}kcal'
                          : '—',
                    ),
                    _MetricTile(
                      icon: Icons.calendar_today_outlined,
                      label: 'Target Date',
                      value: DateFormat('d MMM, yy').format(user.targetDate),
                    ),
                  ],
                ),
                SizedBox(height: r.scale(14)),
                _ProfileMenuRow(
                  icon: Icons.eco_outlined,
                  title: 'Meal Plan',
                  onTap: () => Get.toNamed(
                    AppRoutes.dietPreferences,
                    arguments: RouteArgs.fromProfileMap,
                  ),
                ),
                _ProfileMenuRow(
                  icon: Icons.medical_services_outlined,
                  title: 'Health Concern',
                  onTap: () => Get.toNamed(
                    AppRoutes.healthProblem,
                    arguments: RouteArgs.fromProfileMap,
                  ),
                ),
                _ProfileMenuRow(
                  icon: Icons.headset_mic_outlined,
                  title: 'Help & Support',
                  onTap: () => Get.toNamed(AppRoutes.helpSupport),
                ),
                _ProfileMenuRow(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () => Get.toNamed(AppRoutes.settings),
                ),
                _ProfileMenuRow(
                  icon: Icons.shield_outlined,
                  title: 'Privacy Policy',
                  onTap: openPrivacyPolicy,
                ),
                _ProfileMenuRow(
                  icon: Icons.description_outlined,
                  title: 'Terms & Service',
                  onTap: openTermsOfService,
                ),
                _ProfileMenuRow(
                  icon: Icons.card_giftcard_outlined,
                  title: 'Invite Friends',
                  onTap: () => Get.toNamed(AppRoutes.inviteFriends),
                ),
                _ProfileMenuRow(
                  icon: Icons.share_outlined,
                  title: 'Share App',
                  onTap: _shareApp,
                ),
                SizedBox(height: r.scale(8)),
                _ActionButton(
                  label: 'Log Out',
                  color: AppColors.textPrimary,
                  onTap: ctrl.isLoggingOut
                      ? null
                      : () => _confirmLogout(context, ctrl),
                  isLoading: ctrl.isLoggingOut,
                ),
                SizedBox(height: r.scale(10)),
                _ActionButton(
                  label: 'Delete Account',
                  color: AppColors.error,
                  onTap: ctrl.isDeletingAccount || ctrl.isLoggingOut
                      ? null
                      : () => _confirmDeleteAccount(context, ctrl),
                  isLoading: ctrl.isDeletingAccount,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget? _goalTrendIcon(UserModel user) {
    final goal = user.pinnedGoalType ?? user.goal;
    if (goal == GoalType.gainWeight) {
      return Icon(
        Icons.arrow_upward_rounded,
        size: 14,
        color: AppColors.primary,
      );
    }
    if (goal == GoalType.loseWeight) {
      return Icon(
        Icons.arrow_downward_rounded,
        size: 14,
        color: AppColors.primary,
      );
    }
    return null;
  }

  Future<void> _shareApp() async {
    const message = 'Check out MyCaloriePal — your smart nutrition tracker!';
    await SharePlus.instance.share(
      ShareParams(text: message, title: 'Share MyCaloriePal'),
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    UserController ctrl,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !ctrl.isDeletingAccount,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This permanently deletes your MyCaloriePal account and all app data. '
          'You will need to create a new account to use the app again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ctrl.performDeleteAccount();
    }
  }

  Future<void> _confirmLogout(BuildContext context, UserController ctrl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !ctrl.isLoggingOut,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Logout', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ctrl.performLogout();
    }
  }
}

class _ProfileIdentityRow extends StatelessWidget {
  const _ProfileIdentityRow({
    required this.user,
    required this.onAvatarTap,
    required this.onEditTap,
    this.isAppleProfile = false,
    this.isUploadingAvatar = false,
  });

  final UserModel user;
  final VoidCallback onAvatarTap;
  final VoidCallback onEditTap;
  final bool isAppleProfile;
  final bool isUploadingAvatar;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final avatarRadius = r.scale(34, tablet: 38);
    final displayName = user.name.trim();
    final nameLabel = displayName.isEmpty ? 'MyCaloriePal' : displayName;
    final emailLabel = user.email.trim().isEmpty ? '—' : user.email.trim();

    return Row(
      children: [
        ProfileAvatar(
          user: user,
          onTap: onAvatarTap,
          radius: avatarRadius,
          isUploading: isUploadingAvatar,
          showEditBadge: true,
          onEditBadgeTap: onEditTap,
          tooltip: isAppleProfile && user.hasProfilePhoto
              ? 'View photo'
              : 'Profile photo',
        ),
        SizedBox(width: r.scale(14)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nameLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: r.scale(18, tablet: 20),
                  fontWeight: FontWeight.w800,
                  color: displayName.isEmpty
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
              ),
              SizedBox(height: r.scale(4)),
              Text(
                emailLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: r.scale(13, tablet: 14),
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.title,
    required this.icon,
    required this.onTap,
    required this.children,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            r.scale(14),
            r.scale(14),
            r.scale(12),
            r.scale(14),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primary, size: r.scale(20)),
                  SizedBox(width: r.scale(8)),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: r.scale(15, tablet: 16),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                    size: r.scale(22),
                  ),
                ],
              ),
              SizedBox(height: r.scale(12)),
              Row(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) SizedBox(width: r.scale(8)),
                    Expanded(child: children[i]),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(8),
        vertical: r.scale(10),
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: r.scale(18)),
          SizedBox(height: r.scale(8)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.scale(11),
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: r.scale(2)),
          Row(
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.scale(14, tablet: 15),
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    height: 1.15,
                  ),
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: r.scale(2)),
                trailing!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Padding(
      padding: EdgeInsets.only(bottom: r.scale(10)),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: r.scale(14),
              vertical: r.scale(13),
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.55),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowColor,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: r.scale(40, tablet: 42),
                  height: r.scale(40, tablet: 42),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: r.scale(20)),
                ),
                SizedBox(width: r.scale(14)),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: r.scale(15, tablet: 16),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: r.scale(24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: r.scale(16)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isLoading
              ? SizedBox(
                  width: r.scale(20),
                  height: r.scale(20),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: r.scale(15, tablet: 16),
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ProfileSettlingState extends StatelessWidget {
  const _ProfileSettlingState({
    required this.horizontalPadding,
    required this.bottomPad,
  });

  final double horizontalPadding;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        r.scale(8),
        horizontalPadding,
        bottomPad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Profile',
            style: TextStyle(
              fontSize: r.scale(28, tablet: 30),
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
              height: 1.15,
            ),
          ),
          SizedBox(height: r.scale(28)),
          Center(
            child: SizedBox(
              width: r.scale(28),
              height: r.scale(28),
              child: const CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
          SizedBox(height: r.scale(16)),
          Text(
            'Loading your profile…',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.scale(14),
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: r.scale(24)),
          _PulseBlock(height: r.scale(88)),
          SizedBox(height: r.scale(12)),
          _PulseBlock(height: r.scale(120)),
          SizedBox(height: r.scale(12)),
          _PulseBlock(height: r.scale(120)),
        ],
      ),
    );
  }
}

class _PulseBlock extends StatelessWidget {
  const _PulseBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
    );
  }
}
