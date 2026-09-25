import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/onboarding_nav.dart';
import '../core/route_args.dart';
import '../models/diet_type.dart';
import '../models/lifestyle_habits.dart';
import '../models/onboarding_request_model.dart';
import '../models/profile_sync_snapshot.dart';
import '../routes/app_routes.dart';
import '../widgets/onboarding_multi_choice_page.dart';
import '../widgets/onboarding_step_scaffold.dart';

/// Food preferences (pick at least 5).
class FoodPreferencesView extends StatefulWidget {
  const FoodPreferencesView({super.key});

  @override
  State<FoodPreferencesView> createState() => _FoodPreferencesViewState();
}

class _FoodPreferencesViewState extends State<FoodPreferencesView> {
  late final UserController _user = Get.find<UserController>();
  late final ProfileSyncSnapshot _baseline;
  final Set<String> _selected = {};
  static const _preferredMinCount = 5;
  bool _saving = false;

  bool get _fromProfile => RouteArgs.isEditingFromProfile;

  List<HabitOption> get _options =>
      LifestyleHabitOptions.foodPreferencesFor(_user.user.dietType);

  int get _minCount {
    final available = _options.length;
    if (available <= 0) return 0;
    return _preferredMinCount.clamp(1, available);
  }

  @override
  void initState() {
    super.initState();
    _baseline = _user.captureProfileSyncSnapshot();
    _user.user.applyDietTypeConstraints();
    final allowed = _options.map((o) => o.value).toSet();
    _selected.addAll(
      _user.user.foodPreferences.where(allowed.contains),
    );
  }

  List<String> get _itemValues => _options.map((e) => e.value).toList();

  bool get _allSelected =>
      _itemValues.every(_selected.contains) && _itemValues.isNotEmpty;

  void _toggle(String value) {
    setState(() {
      if (!_selected.remove(value)) _selected.add(value);
    });
    _persist();
  }

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_itemValues);
      }
    });
    _persist();
  }

  void _persist() {
    if (_fromProfile) return;
    _user.user.foodPreferences = _selected.toList()..sort();
    _user.scheduleOnboardingDraftSave();
  }

  Future<void> _onBack() async {
    if (_saving) return;
    if (_fromProfile) {
      Get.back<void>();
      return;
    }
    await _user.goToPreviousOnboardingStep(AppRoutes.foodPreferences);
  }

  Future<void> _continue() async {
    if (_saving) return;
    if (_selected.length < _minCount) {
      AppSnackbar.error('Choose at least $_minCount products to continue.');
      return;
    }
    final next = _selected.toList()..sort();
    _user.user.foodPreferences = next;
    if (_fromProfile) {
      if (ProfileSyncSnapshot.stringListsEqual(
        next,
        _baseline.foodPreferences,
      )) {
        AppSnackbar.info('No changes to save.', title: 'Nothing changed');
        Get.back<void>();
        return;
      }
      setState(() => _saving = true);
      try {
        final error = await _user.patchOnboarding(
          OnboardingPatchModel.foodPreferences(next),
        );
        if (!mounted) return;
        if (error != null) {
          AppSnackbar.error(error, title: 'Save failed');
          return;
        }
        Get.back<void>();
        AppSnackbar.success('Food preferences updated.');
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }

    final diet = _user.user.dietType;
    if (diet != null && !diet.asksMeatPreferences) {
      _user.user.meatPreferences =
          List<String>.from(diet.impliedMeatPreferences);
      await _user.persistOnboardingStep(AppRoutes.habitFoodAllergies);
      await OnboardingNav.offNamed(AppRoutes.habitFoodAllergies);
      return;
    }

    await _user.persistOnboardingStep(AppRoutes.meatPreferences);
    await OnboardingNav.offNamed(AppRoutes.meatPreferences);
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
        stepIndex: _fromProfile ? 0 : OnboardingFlowProgress.foodPreferences,
        totalSteps: _fromProfile ? 1 : OnboardingFlowProgress.totalSteps,
        showProgress: !_fromProfile,
        title: 'What are your food preferences?',
        subtitle: 'Choose at least $_minCount products',
        options: _options,
        selectedValues: _selected,
        onToggle: _toggle,
        onSelectAll: _toggleSelectAll,
        selectAllSelected: _allSelected,
        onBack: () => unawaited(_onBack()),
        continueLabel: _saving
            ? 'Saving...'
            : (_fromProfile ? 'Save' : 'Continue'),
        continueEnabled: !_saving && _selected.length >= _minCount,
        onContinue: _saving ? null : () => unawaited(_continue()),
      ),
    );
  }
}
