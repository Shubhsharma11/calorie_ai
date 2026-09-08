import 'dart:async';

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
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/onboarding_step_scaffold.dart';

class ActivityLevelView extends StatefulWidget {
  const ActivityLevelView({super.key});

  @override
  State<ActivityLevelView> createState() => _ActivityLevelViewState();
}

class _ActivityLevelViewState extends State<ActivityLevelView> {
  final UserController controller = Get.find<UserController>();
  late final ProfileSyncSnapshot _baseline;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _baseline = controller.captureProfileSyncSnapshot();
  }

  Future<void> _onContinue({
    required bool fromProfile,
    required bool returnToDailyGoal,
  }) async {
    if (_saving) return;
    final selected = controller.user.activityLevel;
    if (selected == null) {
      AppSnackbar.error('Select your activity level.');
      return;
    }

    controller.notifyGoalConsumers();
    if (fromProfile || returnToDailyGoal) {
      setState(() => _saving = true);
      try {
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

          final error = await controller.patchOnboarding(patch);
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
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    } else {
      controller.finishSetup();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final fromProfile = RouteArgs.isEditingFromProfile;
    final returnToDailyGoal = RouteArgs.shouldReturnToDailyGoal;
    final pageBg = AppColors.backgroundOf(context);
    final editing = fromProfile || returnToDailyGoal;

    return PopScope(
      canPop: editing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(
          controller.goToPreviousOnboardingStep(AppRoutes.activityLevel),
        );
      },
      child: GetBuilder<UserController>(
        builder: (_) {
          final selected = controller.user.activityLevel;

          return Scaffold(
            backgroundColor: pageBg,
            body: SafeArea(
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: r.scale(20, tablet: 28)),
                child: Column(
                  children: [
                    SizedBox(height: r.scale(4)),
                    OnboardingStepTopBar(
                      stepIndex:
                          editing ? 0 : OnboardingFlowProgress.activity,
                      totalSteps:
                          editing ? 1 : OnboardingFlowProgress.totalSteps,
                      showProgress: !editing,
                      onBack: () {
                        if (editing) {
                          Get.back<void>();
                          return;
                        }
                        unawaited(
                          controller.goToPreviousOnboardingStep(
                            AppRoutes.activityLevel,
                          ),
                        );
                      },
                    ),
                    SizedBox(height: r.scale(28)),
                    Text(
                      'Choose your activity level',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: r.scale(28, tablet: 32),
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryOf(context),
                        height: 1.15,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: r.scale(10)),
                    Text(
                      'How active are you during a typical week?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: r.scale(14, tablet: 15),
                        color: AppColors.textSecondaryOf(context),
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: r.scale(24)),
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          for (final level in ActivityLevel.values) ...[
                            OnboardingOptionCard(
                              title: level.title,
                              subtitle: level.description,
                              leading: SizedBox(
                                width: 44,
                                height: 44,
                                child: SvgPicture.asset(
                                  level.imageAsset,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              selected: selected == level,
                              onTap: () => controller.selectActivity(level),
                            ),
                            SizedBox(height: r.scale(12)),
                          ],
                        ],
                      ),
                    ),
                    OnboardingContinueButton(
                      label: _saving
                          ? 'Saving...'
                          : (editing ? 'Save' : 'Continue'),
                      onPressed: selected == null || _saving
                          ? null
                          : () => unawaited(
                                _onContinue(
                                  fromProfile: fromProfile,
                                  returnToDailyGoal: returnToDailyGoal,
                                ),
                              ),
                    ),
                    if (!editing) ...[
                      SizedBox(height: r.scale(10)),
                      Text(
                        'You can change this anytime in your profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: r.scale(12, tablet: 13),
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                    SizedBox(height: r.scale(12)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
