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
import '../widgets/onboarding_multi_choice_page.dart';
import '../widgets/onboarding_step_scaffold.dart';

class MedicationsView extends StatefulWidget {
  const MedicationsView({super.key});

  @override
  State<MedicationsView> createState() => _MedicationsViewState();
}

class _MedicationsViewState extends State<MedicationsView> {
  late final UserController _user = Get.find<UserController>();
  late final ProfileSyncSnapshot _baseline;
  final Set<String> _selected = {};
  bool _saving = false;

  bool get _fromProfile => RouteArgs.isEditingFromProfile;

  @override
  void initState() {
    super.initState();
    _baseline = _user.captureProfileSyncSnapshot();
    _selected.addAll(_user.user.medications);
  }

  void _toggle(String value) {
    setState(() {
      if (value == 'no') {
        _selected
          ..clear()
          ..add('no');
      } else {
        _selected.remove('no');
        if (!_selected.remove(value)) _selected.add(value);
      }
    });
    _persist();
  }

  void _persist() {
    if (_fromProfile) return;
    _user.user.medications = _selected.toList()..sort();
    _user.scheduleOnboardingDraftSave();
  }

  Future<void> _onBack() async {
    if (_saving) return;
    if (_fromProfile) {
      Get.back<void>();
      return;
    }
    await _user.goToPreviousOnboardingStep(AppRoutes.medications);
  }

  Future<void> _continue() async {
    if (_saving) return;
    if (_selected.isEmpty) {
      AppSnackbar.error('Please choose an option to continue.');
      return;
    }
    final next = _selected.toList()..sort();
    _user.user.medications = next;
    if (_fromProfile) {
      if (ProfileSyncSnapshot.stringListsEqual(next, _baseline.medications)) {
        AppSnackbar.info('No changes to save.', title: 'Nothing changed');
        Get.back<void>();
        return;
      }
      setState(() => _saving = true);
      try {
        final error = await _user.patchOnboarding(
          OnboardingPatchModel.medications(next),
        );
        if (!mounted) return;
        if (error != null) {
          AppSnackbar.error(error, title: 'Save failed');
          return;
        }
        Get.back<void>();
        AppSnackbar.success('Medications updated.');
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }
    await _user.persistOnboardingStep(AppRoutes.dietPlanInterest);
    await OnboardingNav.offNamed(AppRoutes.dietPlanInterest);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _fromProfile && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_onBack());
      },
      child: OnboardingMultiChoicePage(
        stepIndex: _fromProfile ? 0 : OnboardingFlowProgress.medications,
        totalSteps: _fromProfile ? 1 : OnboardingFlowProgress.totalSteps,
        showProgress: !_fromProfile,
        title: 'Are you taking any medications?',
        subtitle: 'Select all that apply — this stays private to your plan.',
        options: LifestyleHabitOptions.medications,
        selectedValues: _selected,
        onToggle: _toggle,
        onBack: () => unawaited(_onBack()),
        continueLabel: _saving
            ? 'Saving...'
            : (_fromProfile ? 'Save' : 'Continue'),
        onContinue: _saving ? null : () => unawaited(_continue()),
      ),
    );
  }
}
