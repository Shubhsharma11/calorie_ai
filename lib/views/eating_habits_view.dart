import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/onboarding_nav.dart';
import '../core/route_args.dart';
import '../models/lifestyle_habits.dart';
import '../models/onboarding_request_model.dart';
import '../models/profile_sync_snapshot.dart';
import '../routes/app_routes.dart';
import '../widgets/onboarding_choice_page.dart';
import '../widgets/onboarding_step_scaffold.dart';

/// “How would you describe your eating habits?”
class EatingHabitsView extends StatefulWidget {
  const EatingHabitsView({super.key});

  @override
  State<EatingHabitsView> createState() => _EatingHabitsViewState();
}

class _EatingHabitsViewState extends State<EatingHabitsView> {
  late final UserController _user = Get.find<UserController>();
  late final ProfileSyncSnapshot _baseline;
  String? _selected;
  bool _saving = false;

  bool get _fromProfile => RouteArgs.isEditingFromProfile;

  @override
  void initState() {
    super.initState();
    _baseline = _user.captureProfileSyncSnapshot();
    _selected = _user.user.eatingHabits;
  }

  void _select(String value) {
    setState(() => _selected = value);
    if (!_fromProfile) {
      _user.user.eatingHabits = value;
      _user.scheduleOnboardingDraftSave();
    }
  }

  Future<void> _onBack() async {
    if (_saving) return;
    if (_fromProfile) {
      Get.back<void>();
      return;
    }
    await _user.goToPreviousOnboardingStep(AppRoutes.eatingHabits);
  }

  Future<void> _continue() async {
    if (_saving) return;
    if (_selected == null) {
      AppSnackbar.error('Please choose an option to continue.');
      return;
    }
    _user.user.eatingHabits = _selected;
    if (_fromProfile) {
      if (_selected == _baseline.eatingHabits) {
        AppSnackbar.info('No changes to save.', title: 'Nothing changed');
        Get.back<void>();
        return;
      }
      setState(() => _saving = true);
      try {
        final error = await _user.patchOnboarding(
          OnboardingPatchModel.eatingHabits(_selected!),
        );
        if (!mounted) return;
        if (error != null) {
          AppSnackbar.error(error, title: 'Save failed');
          return;
        }
        Get.back<void>();
        AppSnackbar.success('Eating habits updated.');
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }
    await _user.persistOnboardingStep(AppRoutes.livingArea);
    await OnboardingNav.offNamed(AppRoutes.livingArea);
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
        stepIndex: _fromProfile ? 0 : OnboardingFlowProgress.eatingHabits,
        totalSteps: _fromProfile ? 1 : OnboardingFlowProgress.totalSteps,
        showProgress: !_fromProfile,
        title: 'How would you describe your eating habits?',
        options: LifestyleHabitOptions.eatingHabits,
        selectedValue: _selected,
        onSelect: _select,
        onBack: () => unawaited(_onBack()),
        continueLabel: _saving
            ? 'Saving...'
            : (_fromProfile ? 'Save' : 'Continue'),
        onContinue: _saving ? null : () => unawaited(_continue()),
      ),
    );
  }
}
