import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../models/goal_type.dart';
import '../models/onboarding_request_model.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/responsive_page.dart';

class GoalSetupView extends StatefulWidget {
  const GoalSetupView({super.key});

  static const _targetAsset = 'assets/image/target.svg';
  static const _loseWeightAsset = 'assets/image/right-down.svg';
  static const _gainWeightAsset = 'assets/image/upgain.svg';
  static const _maintainWeightAsset = 'assets/image/balance.svg';

  @override
  State<GoalSetupView> createState() => _GoalSetupViewState();
}

class _GoalSetupViewState extends State<GoalSetupView> {
  final UserController controller = Get.find<UserController>();

  @override
  void initState() {
    super.initState();
    if (RouteArgs.isEditingFromProfile) {
      controller.beginGoalEditFromProfile();
    }
  }

  Future<void> _onBack({required bool fromProfile}) async {
    if (fromProfile) {
      controller.cancelGoalEditFromProfile();
      Get.back<void>();
      return;
    }
    await controller.goToPreviousOnboardingStep(AppRoutes.goalSetup);
  }

  void _onSelectGoal(GoalType goal) {
    controller.selectGoal(
      goal,
      persistDraft: !RouteArgs.isEditingFromProfile,
    );
  }

  Future<void> _onContinue({required bool fromProfile}) async {
    final goal = controller.user.goal;
    if (goal == null) {
      AppSnackbar.error('Select your goal first.');
      return;
    }

    if (fromProfile) {
      if (goal == GoalType.maintainWeight) {
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
        return;
      }

      Get.toNamed(
        AppRoutes.goalAmount,
        arguments: RouteArgs.fromProfileMap,
      );
      return;
    }

    if (goal == GoalType.maintainWeight) {
      controller.useRecommendedGoalWeight();
      await controller.persistOnboardingStep(AppRoutes.activityLevel);
      Get.toNamed(AppRoutes.activityLevel);
      return;
    }

    await controller.persistOnboardingStep(AppRoutes.goalAmount);
    Get.toNamed(AppRoutes.goalAmount);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final compact = r.height < 720;
    final fromProfile = RouteArgs.isEditingFromProfile;

    return PopScope(
      canPop: fromProfile,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_onBack(fromProfile: fromProfile));
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppAppBar.backOnly(
          onBack: () => unawaited(_onBack(fromProfile: fromProfile)),
        ),
        body: GetBuilder<UserController>(
          builder: (_) {
            final selected = controller.user.goal;

            return SetupScreenLayout(
              scrollable: true,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: r.scale(compact ? 4 : 8)),
                  _HeroSection(r: r, compact: compact),
                  SizedBox(height: r.scale(compact ? 16 : 20)),
                  ...GoalType.values.map(
                    (g) => Padding(
                      padding: EdgeInsets.only(bottom: r.scale(12)),
                      child: _GoalCard(
                        goal: g,
                        selected: selected == g,
                        onTap: () => _onSelectGoal(g),
                      ),
                    ),
                  ),
                ],
              ),
              action: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: selected == null
                      ? null
                      : () => _onContinue(fromProfile: fromProfile),
                  child: Text(fromProfile ? 'Next' : 'Next'),
                ),
              ),
            );
          },
        ),
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
                      TextSpan(text: 'What\'s your '),
                      TextSpan(
                        text: 'goal?',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r.scale(compact ? 6 : 8)),
                Text(
                  'Choose what you want to work toward.',
                  style: TextStyle(
                    fontSize: r.scale(compact ? 13 : 14, tablet: 15),
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: r.scale(8)),
          SizedBox(
            width: r.scale(compact ? 88 : 96, tablet: 104),
            height: r.scale(compact ? 88 : 96, tablet: 104),
            child: SvgPicture.asset(
              GoalSetupView._targetAsset,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  final GoalType goal;
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
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(14),
            vertical: r.scale(14),
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
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _GoalLeadingIcon(goal: goal),
              SizedBox(width: r.scale(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
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
                      goal.description,
                      style: TextStyle(
                        fontSize: r.scale(12, tablet: 13),
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: r.scale(8)),
              _SelectionIndicator(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalLeadingIcon extends StatelessWidget {
  const _GoalLeadingIcon({required this.goal});

  final GoalType goal;

  @override
  Widget build(BuildContext context) {
    if (goal == GoalType.loseWeight) {
      return SizedBox(
        width: 44,
        height: 44,
        child: SvgPicture.asset(
          GoalSetupView._loseWeightAsset,
          fit: BoxFit.contain,
        ),
      );
    }

    if (goal == GoalType.gainWeight) {
      return SizedBox(
        width: 44,
        height: 44,
        child: SvgPicture.asset(
          GoalSetupView._gainWeightAsset,
          fit: BoxFit.contain,
        ),
      );
    }

    return SizedBox(
      width: 44,
      height: 44,
      child: SvgPicture.asset(
        GoalSetupView._maintainWeightAsset,
        fit: BoxFit.contain,
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
        decoration: const BoxDecoration(
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
