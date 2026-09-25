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

/// Dedicated allergies page (replaces diet-preferences allergy chips).
class HabitFoodAllergiesView extends StatefulWidget {
  const HabitFoodAllergiesView({super.key});

  @override
  State<HabitFoodAllergiesView> createState() => _HabitFoodAllergiesViewState();
}

class _HabitFoodAllergiesViewState extends State<HabitFoodAllergiesView> {
  late final UserController _user = Get.find<UserController>();
  late final ProfileSyncSnapshot _baseline;
  final Set<String> _selected = {};
  bool _saving = false;

  bool get _fromProfile => RouteArgs.isEditingFromProfile;

  List<HabitOption> get _options =>
      LifestyleHabitOptions.foodAllergiesFor(_user.user.dietType);

  @override
  void initState() {
    super.initState();
    _baseline = _user.captureProfileSyncSnapshot();
    _user.user.applyDietTypeConstraints();
    final saved = _user.user.foodAllergies;
    for (final item in saved) {
      HabitOption? match;
      for (final option in _options) {
        if (option.value == item ||
            option.label.toLowerCase() == item.toLowerCase()) {
          match = option;
          break;
        }
      }
      if (match != null) {
        _selected.add(match.value);
      }
    }
  }

  void _toggle(String value) {
    setState(() {
      if (value == 'none' || value == 'prefer_not') {
        _selected
          ..clear()
          ..add(value);
      } else {
        _selected.remove('none');
        _selected.remove('prefer_not');
        if (!_selected.remove(value)) _selected.add(value);
      }
    });
    _persist();
  }

  void _persist() {
    if (_fromProfile) return;
    _user.user.foodAllergies = _labelsToSave();
    _user.scheduleOnboardingDraftSave();
  }

  List<String> _labelsToSave() {
    if (_selected.contains('none') || _selected.isEmpty) {
      return ['None'];
    }
    if (_selected.contains('prefer_not')) {
      return ['Prefer not to answer'];
    }
    return _options
        .where((o) => _selected.contains(o.value))
        .map((o) => o.label)
        .toList();
  }

  Future<void> _onBack() async {
    if (_saving) return;
    if (_fromProfile) {
      Get.back<void>();
      return;
    }
    await _user.goToPreviousOnboardingStep(AppRoutes.habitFoodAllergies);
  }

  Future<void> _continue() async {
    if (_saving) return;
    if (_selected.isEmpty) {
      AppSnackbar.error('Please choose an option to continue.');
      return;
    }
    final next = _labelsToSave();
    _user.user.foodAllergies = next;
    if (_fromProfile) {
      if (ProfileSyncSnapshot.foodAllergiesEqual(
        next,
        _baseline.foodAllergies,
      )) {
        AppSnackbar.info('No changes to save.', title: 'Nothing changed');
        Get.back<void>();
        return;
      }
      setState(() => _saving = true);
      try {
        final error = await _user.patchOnboarding(
          OnboardingPatchModel.foodAllergies(next),
        );
        if (!mounted) return;
        if (error != null) {
          AppSnackbar.error(error, title: 'Save failed');
          return;
        }
        Get.back<void>();
        AppSnackbar.success('Allergies updated.');
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }
    await _user.persistOnboardingStep(AppRoutes.dietPreferences);
    await OnboardingNav.offNamed(
      AppRoutes.dietPreferences,
      arguments: RouteArgs.dietAvoidMap,
    );
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
        stepIndex: _fromProfile ? 0 : OnboardingFlowProgress.habitFoodAllergies,
        totalSteps: _fromProfile ? 1 : OnboardingFlowProgress.totalSteps,
        showProgress: !_fromProfile,
        title: 'Do you have any food allergies or intolerances?',
        subtitle: 'Select all that apply so we keep meals safe.',
        options: _options,
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
