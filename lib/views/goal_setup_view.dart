import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/onboarding_nav.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../models/goal_type.dart';
import '../models/onboarding_request_model.dart';
import '../routes/app_routes.dart';
import '../widgets/onboarding_question_transition.dart';
import '../widgets/onboarding_step_scaffold.dart';

class GoalSetupView extends StatefulWidget {
  const GoalSetupView({super.key});

  static const _loseAsset = 'assets/image/right-down.svg';
  static const _gainAsset = 'assets/image/upgain.svg';
  static const _maintainAsset = 'assets/image/balance.svg';

  @override
  State<GoalSetupView> createState() => _GoalSetupViewState();
}

class _GoalSetupViewState extends State<GoalSetupView> {
  final UserController controller = Get.find<UserController>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (RouteArgs.isEditingFromProfile) {
      controller.beginGoalEditFromProfile();
    }
  }

  String _subtitleFor(GoalType goal) {
    switch (goal) {
      case GoalType.loseWeight:
        return 'Drop weight at a healthy pace';
      case GoalType.maintainWeight:
        return 'Stay at your current weight';
      case GoalType.gainWeight:
        return 'Build muscle and gain healthy weight';
    }
  }

  Widget _iconFor(GoalType goal) {
    final asset = switch (goal) {
      GoalType.loseWeight => GoalSetupView._loseAsset,
      GoalType.gainWeight => GoalSetupView._gainAsset,
      GoalType.maintainWeight => GoalSetupView._maintainAsset,
    };
    return SizedBox(
      width: 40,
      height: 40,
      child: SvgPicture.asset(asset, fit: BoxFit.contain),
    );
  }

  Future<void> _onBack({required bool fromProfile}) async {
    if (fromProfile) {
      controller.cancelGoalEditFromProfile();
      Get.back<void>();
      return;
    }
    OnboardingNav.markBackward();
    await controller.goToPreviousOnboardingStep(AppRoutes.goalSetup);
  }

  void _onSelectGoal(GoalType goal) {
    controller.selectGoal(goal, persistDraft: !RouteArgs.isEditingFromProfile);
  }

  Future<void> _onContinue({required bool fromProfile}) async {
    if (_isSaving) return;

    final goal = controller.user.goal;
    if (goal == null) {
      AppSnackbar.error('Select your goal first.');
      return;
    }

    if (fromProfile) {
      if (goal == GoalType.maintainWeight) {
        setState(() => _isSaving = true);
        try {
          controller.useRecommendedGoalWeight();
          final patch = OnboardingPatchModel.goalProfileDiff(
            controller.user,
            controller.baselineForGoalProfileSave(),
          );
          if (patch.isEmpty) {
            controller.commitGoalEditFromProfile();
            AppSnackbar.info('No changes to save.', title: 'Nothing changed');
            controller.popToMyGoals();
            return;
          }
          final error = await controller.patchOnboarding(patch);
          if (error != null) {
            AppSnackbar.error(error, title: 'Save failed');
            return;
          }
          controller.commitGoalEditFromProfile();
          controller.popToMyGoals();
          AppSnackbar.success('Goal updated.');
        } finally {
          if (mounted) setState(() => _isSaving = false);
        }
        return;
      }

      Get.toNamed(AppRoutes.goalAmount, arguments: RouteArgs.fromProfileMap);
      return;
    }

    // Onboarding: goal type → target weight.
    await controller.persistOnboardingStep(AppRoutes.goalAmount);
    await OnboardingNav.offNamed(AppRoutes.goalAmount);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final fromProfile = RouteArgs.isEditingFromProfile;

    return PopScope(
      canPop: fromProfile,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_onBack(fromProfile: fromProfile));
      },
      child: GetBuilder<UserController>(
        builder: (_) {
          final selected = controller.user.goal;

          return OnboardingCupertinoShell(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: r.scale(20, tablet: 28),
                ),
                child: Column(
                  children: [
                    SizedBox(height: r.scale(4)),
                    OnboardingStepTopBar(
                      stepIndex: fromProfile
                          ? 0
                          : OnboardingFlowProgress.goalSetup,
                      totalSteps: fromProfile
                          ? 2
                          : OnboardingFlowProgress.totalSteps,
                      showProgress: true,
                      onBack: () =>
                          unawaited(_onBack(fromProfile: fromProfile)),
                      sectionLabel: fromProfile
                          ? 'GOALS'
                          : OnboardingJourney.labelForStep(
                              OnboardingFlowProgress.goalSetup,
                            ),
                    ),
                    SizedBox(height: r.scale(28)),
                    Expanded(
                      child: OnboardingQuestionTransition(
                        stepKey: OnboardingFlowProgress.goalSetup,
                        question: const OnboardingQuestionHeader(
                          title: 'What’s your goal?',
                        ),
                        description: const OnboardingQuestionDescription(
                          'We’ll shape your calories and plan around this.',
                        ),
                        answer: ListView(
                          physics: const BouncingScrollPhysics(),
                          children: [
                            for (final goal in GoalType.values) ...[
                              OnboardingOptionCard(
                                title: goal.title,
                                subtitle: _subtitleFor(goal),
                                leading: _iconFor(goal),
                                selected: selected == goal,
                                onTap: () => _onSelectGoal(goal),
                              ),
                              SizedBox(height: r.scale(10)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    OnboardingContinueButton(
                      label: _isSaving
                          ? 'Saving...'
                          : (fromProfile ? 'Next' : 'Continue'),
                      onPressed: selected == null || _isSaving
                          ? null
                          : () {
                              OnboardingNav.markForward();
                              unawaited(_onContinue(fromProfile: fromProfile));
                            },
                    ),
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
