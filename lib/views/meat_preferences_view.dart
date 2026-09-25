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

/// Meat preference (multi-select) — only for diets that include land meat.
class MeatPreferencesView extends StatefulWidget {
  const MeatPreferencesView({super.key});

  @override
  State<MeatPreferencesView> createState() => _MeatPreferencesViewState();
}

class _MeatPreferencesViewState extends State<MeatPreferencesView> {
  late final UserController _user = Get.find<UserController>();
  late final ProfileSyncSnapshot _baseline;
  final Set<String> _selected = {};
  bool _skipping = false;
  bool _saving = false;

  bool get _fromProfile => RouteArgs.isEditingFromProfile;

  List<HabitOption> get _options =>
      LifestyleHabitOptions.meatPreferencesFor(_user.user.dietType);

  @override
  void initState() {
    super.initState();
    _baseline = _user.captureProfileSyncSnapshot();
    final diet = _user.user.dietType;
    if (!_fromProfile && diet != null && !diet.asksMeatPreferences) {
      _skipping = true;
      _user.user.meatPreferences =
          List<String>.from(diet.impliedMeatPreferences);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_skipToAllergies());
      });
      return;
    }

    final allowed = _options.map((o) => o.value).toSet();
    _selected.addAll(
      _user.user.meatPreferences.where(allowed.contains),
    );
  }

  Future<void> _skipToAllergies() async {
    if (!mounted) return;
    await _user.persistOnboardingStep(AppRoutes.habitFoodAllergies);
    await OnboardingNav.offNamed(AppRoutes.habitFoodAllergies, animate: false);
  }

  List<String> get _itemValues => _options.map((e) => e.value).toList();

  bool get _allSelected {
    final meats = _itemValues;
    return meats.every(_selected.contains) && meats.isNotEmpty;
  }

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
    _user.user.meatPreferences = _selected.toList()..sort();
    _user.scheduleOnboardingDraftSave();
  }

  Future<void> _onBack() async {
    if (_saving) return;
    if (_fromProfile) {
      Get.back<void>();
      return;
    }
    await _user.goToPreviousOnboardingStep(AppRoutes.meatPreferences);
  }

  Future<void> _continue() async {
    if (_saving) return;
    if (_selected.isEmpty) {
      AppSnackbar.error('Please choose at least one option.');
      return;
    }
    final next = _selected.toList()..sort();
    _user.user.meatPreferences = next;
    if (_fromProfile) {
      if (ProfileSyncSnapshot.stringListsEqual(
        next,
        _baseline.meatPreferences,
      )) {
        AppSnackbar.info('No changes to save.', title: 'Nothing changed');
        Get.back<void>();
        return;
      }
      setState(() => _saving = true);
      try {
        final error = await _user.patchOnboarding(
          OnboardingPatchModel.meatPreferences(next),
        );
        if (!mounted) return;
        if (error != null) {
          AppSnackbar.error(error, title: 'Save failed');
          return;
        }
        Get.back<void>();
        AppSnackbar.success('Meat preferences updated.');
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }
    await _user.persistOnboardingStep(AppRoutes.habitFoodAllergies);
    await OnboardingNav.offNamed(AppRoutes.habitFoodAllergies);
  }

  @override
  Widget build(BuildContext context) {
    if (_skipping) {
      return const ColoredBox(color: Colors.transparent);
    }

    return PopScope(
      canPop: _fromProfile && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_onBack());
      },
      child: OnboardingMultiChoicePage(
        stepIndex: _fromProfile ? 0 : OnboardingFlowProgress.meatPreferences,
        totalSteps: _fromProfile ? 1 : OnboardingFlowProgress.totalSteps,
        showProgress: !_fromProfile,
        title: 'Which meat do you prefer?',
        subtitle: 'Select all that apply',
        options: _options,
        selectedValues: _selected,
        onToggle: _toggle,
        onSelectAll: _toggleSelectAll,
        selectAllSelected: _allSelected,
        onBack: () => unawaited(_onBack()),
        continueLabel: _saving
            ? 'Saving...'
            : (_fromProfile ? 'Save' : 'Continue'),
        onContinue: _saving ? null : () => unawaited(_continue()),
      ),
    );
  }
}
