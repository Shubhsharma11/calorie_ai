import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../models/activity_level.dart';
import '../theme/app_colors.dart';
import '../widgets/responsive_page.dart';

class ActivityLevelView extends GetView<UserController> {
  const ActivityLevelView({super.key});

  static const _heroAsset = 'assets/image/activity2.0.svg';

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final compact = r.height < 720;
    final fromProfile = RouteArgs.isEditingFromProfile;
    final returnToDailyGoal = RouteArgs.shouldReturnToDailyGoal;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GetBuilder<UserController>(
        builder: (_) {
          final selected = controller.user.activityLevel;

          return SetupScreenLayout(
            scrollable: true,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _BackButton(),
                SizedBox(height: r.scale(16)),
                _HeroSection(r: r, compact: compact),
                SizedBox(height: r.scale(24)),
                ...ActivityLevel.values.map(
                  (level) => Padding(
                    padding: EdgeInsets.only(bottom: r.scale(12)),
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
                    onPressed: () {
                      if (fromProfile || returnToDailyGoal) {
                        Get.back();
                      } else {
                        controller.finishSetup();
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          fromProfile || returnToDailyGoal ? 'Save' : 'Continue',
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

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: AppColors.card,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: Get.back,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
        ),
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
              Text(
                'Activity Level',
                style: TextStyle(
                  fontSize: r.scale(compact ? 26 : 28, tablet: 30),
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1.2,
                  letterSpacing: -0.3,
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
        SizedBox(width: r.scale(4)),
        OverflowBox(
          maxWidth: r.scale(220, tablet: 240),
          maxHeight: r.scale(200, tablet: 220),
          alignment: Alignment.topCenter,
          child: Transform.translate(
            offset: Offset(-r.scale(10, tablet: 12), -r.scale(16, tablet: 20)),
            child: const _ActivityHeroIllustration(),
          ),
        ),
      ],
    );
  }
}

class _ActivityHeroIllustration extends StatelessWidget {
  const _ActivityHeroIllustration();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return SizedBox(
      width: r.scale(168, tablet: 188),
      height: r.scale(168, tablet: 188),
      child: SvgPicture.asset(
        ActivityLevelView._heroAsset,
        fit: BoxFit.contain,
      ),
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
      width: 44,
      height: 44,
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

class _SettingsNote extends StatelessWidget {
  const _SettingsNote();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Row(
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
