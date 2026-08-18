import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/user_controller.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../models/user_model.dart';
import '../widgets/profile_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

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
                  isUploadingAvatar: ctrl.isUploadingAvatar,
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
                        onTap: () => Get.toNamed(AppRoutes.personalInformation),
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
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(
        'Terms of Service',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),

      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                'Last Updated: August 7, 2026',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Welcome to FitBuddy AI. By using this app, you agree to these Terms of Service.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 20),

              _termsTitle('1. About FitBuddy AI'),
              _termsText(
                'FitBuddy AI helps you track your meals, calories, water intake, exercise, weight progress, and personal health goals.',
              ),

              _termsTitle('2. Health Disclaimer'),
              _termsText(
                'FitBuddy AI is designed for general health and wellness purposes only. It does not provide medical advice, diagnosis, or treatment.\n\nCalorie information, food details, and AI suggestions may not always be completely accurate. Please consult a healthcare professional before making important health or diet decisions.',
              ),

              _termsTitle('3. Your Account'),
              _termsText(
                'You are responsible for providing accurate information while creating your account and keeping your account details secure.',
              ),

              _termsTitle('4. Your Information'),
              _termsText(
                'You are responsible for the information you enter into FitBuddy AI. Your information is handled according to our Privacy Policy.',
              ),

              _termsTitle('5. Notifications'),
              _termsText(
                'FitBuddy AI may send reminders for meals, water intake, progress updates, and other activities.\n\nNotifications may sometimes be delayed due to device settings, internet connection, or system limitations.',
              ),

              _termsTitle('6. Using the App'),
              _termsText(
                'You agree not to misuse the app, attempt unauthorized access, harm the service, or use FitBuddy AI for illegal activities.',
              ),

              _termsTitle('7. App Updates'),
              _termsText(
                'We may update, modify, or remove features from FitBuddy AI to improve your experience.',
              ),

              _termsTitle('8. Account Deletion'),
              _termsText(
                'You can delete your account from the app settings. Some information may be retained when required by law or for legitimate business purposes.',
              ),

              _termsTitle('9. Changes to Terms'),
              _termsText(
                'We may update these Terms of Service from time to time. Continued use of FitBuddy AI means you accept the updated terms.',
              ),

              _termsTitle('10. Contact Us'),
              _termsText(
  'If you have any questions regarding these Terms, please contact us at:',
),

const SizedBox(height: 8),

GestureDetector(
  onTap: _openEmail,
  child: Text(
    'support@fitbuddyai.com',
    style: TextStyle(
      color: AppColors.primary,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    ),
  ),
),
              const SizedBox(height: 10),

              Text(
                'By using FitBuddy AI, you agree to these Terms of Service.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
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

  Future<void> _shareApp(BuildContext context) async {
    const message = 'Check out FitBuddy AI — your smart nutrition tracker!';

    await SharePlus.instance.share(
      ShareParams(text: message, title: 'Share FitBuddy AI'),
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
          'This permanently deletes your FitBuddy AI account and all app data. '
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.onAvatarTap,
    this.isUploadingAvatar = false,
  });

  final UserModel user;
  final VoidCallback onAvatarTap;
  final bool isUploadingAvatar;

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
                  ? [AppColors.darkHeaderWash, AppColors.background]
                  : const [Color(0xFFE8F5E9), Color(0xFFF5F5F5)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProfileAvatar(
                user: user,
                onTap: onAvatarTap,
                radius: r.scale(42, tablet: 46, desktop: 50),
                isUploading: isUploadingAvatar,
                showEditBadge: true,
                tooltip: 'Profile photo',
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
                  child: Icon(icon, color: accent, size: r.scale(22)),
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
              ? [AppColors.darkSurface, AppColors.card]
              : const [Color(0xFFF3F7F4), Color(0xFFEEF3EF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Opening $platform...')));
  }
}

class _SocialBrandButton extends StatelessWidget {
  const _SocialBrandButton({required this.child, required this.onTap});

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
Widget _termsTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

Widget _termsText(String text) {
  return Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      height: 1.5,
    ),
  );
}

Future<void> _openEmail() async {
  final Uri emailUri = Uri(
    scheme: 'mailto',
    path: 'support@fitbuddyai.com',
    query: 'subject=FitBuddy AI Support',
  );

  final bool opened = await launchUrl(
    emailUri,
    mode: LaunchMode.externalApplication,
  );

  if (!opened) {
    Get.snackbar(
      'Email App Not Found',
      'Please contact us at support@fitbuddyai.com',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}