import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../models/user_model.dart';
import '../widgets/profile_avatar.dart';

class ProfileView extends GetView<UserController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);

    final r = context.responsive;
    final horizontalPadding = r.scale(20, tablet: 28, desktop: 32);

    return ColoredBox(
      color: AppColors.background,
      child: GetBuilder<UserController>(
        builder: (ctrl) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileHeader(
                  user: ctrl.user,
                  onAvatarTap: () => ctrl.showProfilePhotoOptions(context),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    r.scale(18),
                    horizontalPadding,
                    r.scale(28),
                  ),
                  child: Column(
                    children: [
                      _ProfileMenuRow(
                        icon: Icons.person_outline_rounded,
                        title: 'Personal Information',
                        onTap: () =>
                            Get.toNamed(AppRoutes.personalInformation),
                      ),
                        _ProfileMenuRow(
                          icon: Icons.track_changes_rounded,
                          title: 'My Goals',
                          onTap: () => Get.toNamed(AppRoutes.myGoals),
                        ),
                        _ProfileMenuRow(
                          icon: Icons.medical_information_outlined,
                          title: 'Health Concerns',
                          subtitle: _healthConcernsSummary(ctrl.user),
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
                          icon: Icons.description_outlined,
                          title: 'Terms of Service',
                          onTap: () => _showTerms(context),
                        ),
                        _ProfileMenuRow(
                          icon: Icons.share_outlined,
                          title: 'Share App',
                          onTap: () => _shareApp(context),
                        ),
                        _ProfileMenuRow(
                          icon: Icons.delete_outline_rounded,
                          title: 'Delete Account',
                          destructive: true,
                          onTap: ctrl.isDeletingAccount || ctrl.isLoggingOut
                              ? null
                              : () => _confirmDeleteAccount(context, ctrl),
                          showChevron: !ctrl.isDeletingAccount,
                          trailing: ctrl.isDeletingAccount
                              ? SizedBox(
                                  width: r.scale(20),
                                  height: r.scale(20),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.error,
                                  ),
                                )
                              : null,
                        ),
                        _ProfileMenuRow(
                          icon: Icons.logout_rounded,
                          title: 'Logout',
                          onTap: ctrl.isLoggingOut
                              ? null
                              : () => _confirmLogout(context, ctrl),
                          showChevron: !ctrl.isLoggingOut,
                          trailing: ctrl.isLoggingOut
                              ? SizedBox(
                                  width: r.scale(20),
                                  height: r.scale(20),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                              : null,
                        ),
                        SizedBox(height: r.scale(10)),
                        const _FollowUsFooter(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
    );
  }

  String _healthConcernsSummary(UserModel user) {
    if (!user.hasHealthConcernsConfigured || user.hasNoHealthConcerns) {
      return 'None selected';
    }
    return user.healthProblemCategory;
  }

  void _showTerms(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'By using FitBuddy AI, you agree to track nutrition and health '
            'data responsibly. Do not use this app as a substitute for '
            'professional medical advice. You are responsible for the '
            'accuracy of the information you enter.',
            style: TextStyle(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _shareApp(BuildContext context) {
    const message = 'Check out FitBuddy AI — your smart nutrition tracker!';
    Clipboard.setData(const ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App link copied to clipboard')),
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
          'This removes your app data only. Your login account stays, '
          'so you can sign in again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
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
            child: Text(
              'Logout',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ctrl.performLogout();
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.onAvatarTap,
  });

  final UserModel user;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final topInset = MediaQuery.paddingOf(context).top;
    final isDark = AppColors.isDark(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            r.scale(20, tablet: 28, desktop: 32),
            topInset + r.scale(12, tablet: 16),
            r.scale(20, tablet: 28, desktop: 32),
            r.scale(24, tablet: 28),
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      AppColors.darkHeaderWash,
                      AppColors.background,
                    ]
                  : const [
                      Color(0xFFE8F5E9),
                      Color(0xFFF5F5F5),
                    ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProfileAvatar(
                user: user,
                onTap: onAvatarTap,
                radius: r.scale(42, tablet: 46, desktop: 50),
              ),
              SizedBox(height: r.scale(16)),
              Text(
                user.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: r.scale(20, tablet: 22),
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
              ),
              SizedBox(height: r.scale(6)),
              Text(
                user.email.isEmpty ? 'john.doe@email.com' : user.email,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: r.scale(13, tablet: 14),
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: topInset + r.scale(4),
          right: r.scale(12),
          child: IgnorePointer(
            child: Icon(
              Icons.eco_outlined,
              size: r.scale(72, tablet: 84),
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.showChevron = true,
    this.trailing,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showChevron;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final accent = destructive ? AppColors.error : AppColors.iconAccent;

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
                  width: r.scale(42, tablet: 44),
                  height: r.scale(42, tablet: 44),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: accent,
                    size: r.scale(22),
                  ),
                ),
                SizedBox(width: r.scale(14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: r.scale(15, tablet: 16),
                          fontWeight: FontWeight.w600,
                          color: destructive
                              ? AppColors.error
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: r.scale(2)),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: r.scale(12, tablet: 13),
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (showChevron)
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

class _FollowUsFooter extends StatelessWidget {
  const _FollowUsFooter();

  static const _facebookAsset = 'assets/image/facebook.svg';

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final isDark = AppColors.isDark(context);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: r.scale(4)),
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(16),
        vertical: r.scale(24),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  AppColors.darkSurface,
                  AppColors.card,
                ]
              : const [
                  Color(0xFFF3F7F4),
                  Color(0xFFEEF3EF),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  thickness: 1,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.scale(14)),
                child: Text(
                  'Follow us on',
                  style: TextStyle(
                    fontSize: r.scale(15, tablet: 16),
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.primaryDark,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  thickness: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: r.scale(20)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SocialBrandButton(
                onTap: () => _showSocialSnack(context, 'Facebook'),
                child: ClipOval(
                  child: SvgPicture.asset(
                    _facebookAsset,
                    width: r.scale(48),
                    height: r.scale(48),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(width: r.scale(20)),
              _SocialBrandButton(
                onTap: () => _showSocialSnack(context, 'Instagram'),
                child: Container(
                  width: r.scale(48),
                  height: r.scale(48),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF9CE34),
                        Color(0xFFEE2A7B),
                        Color(0xFF6228D7),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.onPrimary,
                    size: r.scale(24),
                  ),
                ),
              ),
              SizedBox(width: r.scale(20)),
              _SocialBrandButton(
                onTap: () => _showSocialSnack(context, 'X'),
                child: Container(
                  width: r.scale(48),
                  height: r.scale(48),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF111111),
                  ),
                  child: Text(
                    '𝕏',
                    style: TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: r.scale(22),
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSocialSnack(BuildContext context, String platform) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening $platform...')),
    );
  }
}

class _SocialBrandButton extends StatelessWidget {
  const _SocialBrandButton({
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: r.scale(10),
                offset: Offset(0, r.scale(4)),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
