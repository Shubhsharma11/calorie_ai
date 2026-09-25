import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/onboarding_nav.dart';
import '../core/route_args.dart';
import '../models/diet_plan_interest.dart';
import '../models/lifestyle_habits.dart';
import '../models/onboarding_request_model.dart';
import '../models/profile_sync_snapshot.dart';
import '../routes/app_routes.dart';
import '../widgets/onboarding_choice_page.dart';
import '../widgets/onboarding_step_scaffold.dart';

/// Separate onboarding page after health concerns.
/// Question: which meal-style plan the user wants to explore.
class DietPlanInterestView extends StatefulWidget {
  const DietPlanInterestView({super.key});

  @override
  State<DietPlanInterestView> createState() => _DietPlanInterestViewState();
}

class _DietPlanInterestViewState extends State<DietPlanInterestView> {
  late final UserController _user = Get.find<UserController>();
  late final ProfileSyncSnapshot _baseline;
  String? _selected;
  bool _saving = false;

  bool get _fromProfile => RouteArgs.isEditingFromProfile;

  @override
  void initState() {
    super.initState();
    _baseline = _user.captureProfileSyncSnapshot();
    _selected = _user.user.dietPlanInterest?.apiValue;
  }

  void _select(String value) {
    final plan = DietPlanInterestX.tryParse(value);
    setState(() => _selected = value);
    if (!_fromProfile && plan != null) {
      _user.user.dietPlanInterest = plan;
      _user.scheduleOnboardingDraftSave();
    }
  }

  Future<void> _onBack() async {
    if (_saving) return;
    if (_fromProfile) {
      Get.back<void>();
      return;
    }
    await _user.goToPreviousOnboardingStep(AppRoutes.dietPlanInterest);
  }

  Future<void> _continue() async {
    if (_saving) return;
    final plan = DietPlanInterestX.tryParse(_selected);
    if (plan == null) {
      AppSnackbar.error('Please choose a diet plan to continue.');
      return;
    }

    _user.user.dietPlanInterest = plan;

    if (_fromProfile) {
      setState(() => _saving = true);
      try {
        if (plan == _baseline.dietPlanInterest) {
          AppSnackbar.info('No changes to save.', title: 'Nothing changed');
          return;
        }
        final error = await _user.patchOnboarding(
          OnboardingPatchModel.dietPlanInterest(plan),
        );
        if (!mounted) return;
        if (error != null) {
          AppSnackbar.error(error, title: 'Save failed');
          return;
        }
        Get.back<void>();
        AppSnackbar.success('Diet plan updated.');
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }

    await _user.persistOnboardingStep(AppRoutes.foodPreferences);
    await OnboardingNav.offNamed(AppRoutes.foodPreferences);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _fromProfile && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_onBack());
      },
      child: OnboardingChoicePage(
        stepIndex: _fromProfile ? 0 : OnboardingFlowProgress.dietPlanInterest,
        totalSteps: _fromProfile ? 1 : OnboardingFlowProgress.totalSteps,
        showProgress: !_fromProfile,
        title: 'Which diet plan are you interested in?',
        subtitle:
            'We’ll lean meal ideas toward this style — you can change later.',
        options: LifestyleHabitOptions.dietPlanInterest,
        selectedValue: _selected,
        onSelect: _select,
        onBack: () => unawaited(_onBack()),
        continueLabel: _saving
            ? 'Saving...'
            : (_fromProfile ? 'Save' : 'Continue'),
        continueEnabled: !_saving,
        onContinue: () => unawaited(_continue()),
      ),
    );
  }
}
