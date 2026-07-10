import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../models/activity_level.dart';
import '../models/onboarding_request_model.dart';
import '../models/profile_sync_snapshot.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/responsive_page.dart';

class ActivityLevelView extends StatefulWidget {
  const ActivityLevelView({super.key});

  static const _heroAsset = 'assets/image/health.png';

  @override
  State<ActivityLevelView> createState() => _ActivityLevelViewState();
}

class _ActivityLevelViewState extends State<ActivityLevelView> {
  final UserController controller = Get.find<UserController>();
  late final ProfileSyncSnapshot _baseline;

  @override
  void initState() {
    super.initState();
    _baseline = controller.captureProfileSyncSnapshot();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final compact = r.height < 720;
    final fromProfile = RouteArgs.isEditingFromProfile;
    final returnToDailyGoal = RouteArgs.shouldReturnToDailyGoal;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppAppBar.backOnly(),
      body: GetBuilder<UserController>(
        builder: (_) {
          final selected = controller.user.activityLevel;

          return SetupScreenLayout(
            scrollable: true,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: r.scale(compact ? 4 : 8)),
                _HeroSection(r: r, compact: compact),
                SizedBox(height: r.scale(compact ? 8 : 12)),
                ...ActivityLevel.values.map(
                  (level) => Padding(
                    padding: EdgeInsets.only(bottom: r.scale(compact ? 8 : 10)),
                    child: _ActivityCard(
                      level: level,
                      selected: selected == level,
                      onTap: () => controller.selectActivity(level),
                    ),
                  ),
                ),
              ],
            ),
            action: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      controller.notifyGoalConsumers();
                      if (fromProfile || returnToDailyGoal) {
                        var didSaveProfile = false;
                        if (fromProfile) {
                          final patch = OnboardingPatchModel.activityLevelDiff(
                            controller.user.activityLevel,
                            _baseline,
                          );
                          if (patch.isEmpty) {
                            AppSnackbar.info(
                              'No changes to save.',
                              title: 'Nothing changed',
                            );
                            return;
                          }

                          final error =
                              await controller.patchOnboarding(patch);
                          if (error != null) {
                            AppSnackbar.error(error, title: 'Save failed');
                            return;
                          }
                          didSaveProfile = true;
                        }
                        Get.back();
                        if (didSaveProfile) {
                          AppSnackbar.success('Activity level updated.');
                        }
                      } else {
                        controller.finishSetup();
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          fromProfile || returnToDailyGoal
                              ? 'Save'
                              : 'Continue',
                        ),
                        if (!fromProfile && !returnToDailyGoal) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: r.scale(12)),
                const _SettingsNote(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.r, required this.compact});

  final Responsive r;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(2),
        vertical: r.scale(compact ? 0 : 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: r.scale(compact ? 25 : 28, tablet: 31),
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.16,
                      letterSpacing: -0.5,
                    ),
                    children: const [
                      TextSpan(text: 'Choose your\n'),
                      TextSpan(
                        text: 'activity level',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r.scale(compact ? 6 : 8)),
                Text(
                  'How active are you during a typical week?',
                  style: TextStyle(
                    fontSize: r.scale(compact ? 13 : 14, tablet: 15),
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: r.scale(12)),
          SizedBox(
            width: r.scale(compact ? 142 : 164, tablet: 190),
            height: r.scale(compact ? 142 : 164, tablet: 190),
            child: const _ActivityHeroIllustration(),
          ),
        ],
      ),
    );
  }
}

class _ActivityHeroIllustration extends StatelessWidget {
  const _ActivityHeroIllustration();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      ActivityLevelView._heroAsset,
      fit: BoxFit.contain,
      alignment: Alignment.center,
    );
  }
}

class _ActivityLevelIcon extends StatelessWidget {
  const _ActivityLevelIcon({required this.level});

  final ActivityLevel level;

  @override
  Widget build(BuildContext context) {
    final asset = level.imageAsset;

    return SizedBox(
      width: 52,
      height: 52,
      child: SvgPicture.asset(asset, fit: BoxFit.contain),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final ActivityLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: BoxConstraints(minHeight: r.scale(74, tablet: 82)),
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(12, tablet: 14),
            vertical: r.scale(10, tablet: 12),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActivityLevelIcon(level: level),
              SizedBox(width: r.scale(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.title,
                      style: TextStyle(
                        fontSize: r.scale(15, tablet: 16),
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      level.description,
                      style: TextStyle(
                        fontSize: r.scale(12, tablet: 13),
                        color: AppColors.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: r.scale(12)),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _SelectionIndicator(selected: selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {

  const _SelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {

    if (selected) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check_rounded, size: 16, color: AppColors.onPrimary),
      );
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
    );
  }
}

class _SettingsNote extends StatelessWidget {
  const _SettingsNote();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Row
    (
      mainAxisAlignment: MainAxisAlignment.center,
      children: [

              Icon(
          Icons.verified_user_outlined,
          size: r.scale(14),
          color: AppColors.primary,
        ),
        SizedBox(width: r.scale(6)),
        Flexible(
          child: Text(
            'You can change this anytime in settings',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.scale(12, tablet: 13),
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
