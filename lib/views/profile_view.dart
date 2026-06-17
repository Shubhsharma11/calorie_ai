import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_ui.dart';
import '../widgets/responsive_page.dart';

class ProfileView extends GetView<UserController> {
  const ProfileView({super.key});

  static const _emailColor = Color(0xFF7A8A9E);

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return GetBuilder<UserController>(
      builder: (ctrl) {
        return ResponsivePage(
          scrollable: true,
          maxWidth: r.width,
          padding: EdgeInsets.fromLTRB(
            r.scale(20, tablet: 28, desktop: 32),
            r.scale(24, tablet: 28),
            r.scale(20, tablet: 28, desktop: 32),
            r.scale(32),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ProfileAvatar(
                    user: ctrl.user,
                    onTap: () => ctrl.showProfilePhotoOptions(context),
                    radius: r.scale(44, tablet: 48, desktop: 52),
                  ),
                  SizedBox(height: r.scale(16)),
                  Text(
                    ctrl.user.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: r.scale(22, tablet: 24, desktop: 26),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: r.scale(6)),
                  Text(
                    ctrl.user.email.isEmpty
                        ? 'john.doe@email.com'
                        : ctrl.user.email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: r.scale(15, tablet: 16),
                      color: _emailColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.scale(28)),
              Divider(height: 1, thickness: 1, color: AppColors.border),
              SizedBox(height: r.scale(8)),
              ProfileMenuRow(
                icon: Icons.track_changes_outlined,
                title: 'My Goals',
                onTap: () => Get.toNamed(AppRoutes.myGoals),
              ),
              ProfileMenuRow(
                icon: Icons.person_outline,
                title: 'Personal Details',
                onTap: () => Get.toNamed(
                  AppRoutes.personalDetails,
                  arguments: RouteArgs.fromProfileMap,
                ),
              ),
              ProfileMenuRow(
                icon: Icons.bar_chart_rounded,
                title: 'Activity Level',
                onTap: () => Get.toNamed(
                  AppRoutes.activityLevel,
                  arguments: RouteArgs.fromProfileMap,
                ),
              ),
              ProfileMenuRow(
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () => Get.toNamed(AppRoutes.settings),
              ),
              ProfileMenuRow(
                icon: Icons.headset_mic_outlined,
                title: 'Help & Support',
                onTap: () => Get.toNamed(AppRoutes.helpSupport),
              ),
              SizedBox(height: r.scale(32)),
              SizedBox(
                width: double.infinity,
                height: r.scale(52, tablet: 54),
                child: OutlinedButton(
                  onPressed: ctrl.logout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    backgroundColor: AppColors.background,
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        size: r.scale(22),
                        color: AppColors.error,
                      ),
                      SizedBox(width: r.scale(10)),
                      Text(
                        'Logout',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: r.scale(16, tablet: 17),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
