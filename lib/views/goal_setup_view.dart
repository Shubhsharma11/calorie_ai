import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../models/goal_type.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/responsive_page.dart';

class GoalSetupView extends GetView<UserController> {
  const GoalSetupView({super.key});

  static const _targetAsset = 'assets/image/target.svg';
  static const _loseWeightAsset = 'assets/image/right-down.svg';
  static const _gainWeightAsset = 'assets/image/upgain.svg';
  static const _maintainWeightAsset = 'assets/image/balance.svg';

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final compact = r.height < 720;
    final fromProfile = RouteArgs.isEditingFromProfile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: GetBuilder<UserController>(
        builder: (_) {
          final selected = controller.user.goal;

          return SetupScreenLayout(
            scrollable: true,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroSection(r: r, compact: compact),
                SizedBox(height: r.scale(24)),
                ...GoalType.values.map(
                  (g) => Padding(
                    padding: EdgeInsets.only(bottom: r.scale(12)),
                    child: _GoalCard(
                      goal: g,
                      selected: selected == g,
                      onTap: () => controller.selectGoal(g),
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
                    : () {
                        if (fromProfile) {
                          Get.back();
                        } else {
                          controller.useRecommendedGoalWeight();
                          Get.toNamed(AppRoutes.activityLevel);
                        }
                      },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(fromProfile ? 'Save' : 'Next'),
                    if (!fromProfile) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
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

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.r,
    required this.compact,
  });

  final Responsive r;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: r.scale(compact ? 26 : 28, tablet: 30),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.2,
                    letterSpacing: -0.3,
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
        SizedBox(width: r.scale(4)),
        Transform.translate(
          offset: Offset(-r.scale(12, tablet: 14), -r.scale(8, tablet: 10)),
          child: SizedBox(
            width: r.scale(88, tablet: 96),
            height: r.scale(88, tablet: 96),
            child: SvgPicture.asset(
              GoalSetupView._targetAsset,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
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
        child: Icon(
          Icons.check_rounded,
          size: 16,
          color: Colors.white,
        ),
      );
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.border,
          width: 1.5,
        ),
      ),
    );
  }
}
