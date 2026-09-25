import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../models/diet_plan_interest.dart';
import '../models/diet_type.dart';
import '../models/lifestyle_habits.dart';
import '../models/onboarding_request_model.dart';
import '../models/profile_sync_snapshot.dart';
import '../models/user_model.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/profile_form_ui.dart';

/// Profile-only Food profile editor (Personal Information–style form).
/// Onboarding diet / habit question screens are unchanged.
class FoodProfileFormView extends StatefulWidget {
  const FoodProfileFormView({super.key});

  @override
  State<FoodProfileFormView> createState() => _FoodProfileFormViewState();
}

class _FoodProfileFormViewState extends State<FoodProfileFormView> {
  late final UserController _userController = Get.find<UserController>();
  late ProfileSyncSnapshot _baseline;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _baseline = _userController.captureProfileSyncSnapshot();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadProfileFromApi());
    });
  }

  Future<void> _loadProfileFromApi() async {
    final error = await _userController.fetchProfile();
    if (!mounted) return;
    if (error != null) {
      AppSnackbar.error(error, title: 'Could not load profile');
    }
    setState(() {
      _baseline = _userController.captureProfileSyncSnapshot();
    });
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;

    final user = _userController.user;
    final patch = OnboardingPatchModel.dietPreferencesDiff(user, _baseline);
    if (patch.isEmpty) {
      AppSnackbar.info('No changes to save.', title: 'Nothing changed');
      return;
    }

    setState(() => _isSaving = true);
    final error = await _userController.patchOnboarding(patch);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      AppSnackbar.error(error, title: 'Save failed');
      return;
    }

    _baseline = _userController.captureProfileSyncSnapshot();
    _userController.onProfileUpdated();
    Get.back();
    AppSnackbar.success('Food profile updated.');
  }

  String _optionLabel(List<HabitOption> options, String? value) {
    if (value == null || value.isEmpty) return '—';
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return value;
  }

  String _livingAreaLabel(UserModel user) {
    final region = LifestyleHabitOptions.livingRegionByValue(user.livingArea);
    if (region == null) return 'Not set';
    final stateValue = user.livingState;
    if (stateValue == null || stateValue.isEmpty) return region.label;
    for (final state in region.states) {
      if (state.value == stateValue) {
        return '${region.label} · ${state.label}';
      }
    }
    return region.label;
  }

  String _listSummary(
    List<String> values, {
    required String emptyLabel,
    String Function(String)? labelOf,
  }) {
    if (values.isEmpty) return emptyLabel;
    final labels = values.map((v) => labelOf?.call(v) ?? v).toList();
    if (labels.length == 1) return labels.first;
    if (labels.length == 2) return '${labels[0]}, ${labels[1]}';
    return '${labels.length} selected';
  }

  String _allergySummary(UserModel user) {
    final allergies = user.foodAllergies
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (allergies.isEmpty) return 'None';
    final lower = allergies.map((e) => e.toLowerCase()).toList();
    if (lower.any((e) => e == 'none')) return 'None';
    if (lower.any((e) => e.contains('prefer not'))) return 'Prefer not';
    return _listSummary(allergies, emptyLabel: 'None');
  }

  String _avoidSummary(UserModel user) {
    final raw = user.foodsToAvoid.trim();
    if (raw.isEmpty) return 'Nothing excluded';
    final lower = raw.toLowerCase();
    if (lower.contains('nothing') || lower == 'none') return 'Nothing excluded';
    final chips = <String>[];
    for (final option in LifestyleHabitOptions.foodsToAvoid) {
      if (option.value == 'none') continue;
      if (lower.contains(option.label.toLowerCase()) ||
          lower.contains(option.value.replaceAll('_', ' '))) {
        chips.add(option.label);
      }
    }
    if (chips.isEmpty) {
      final parts = raw
          .split(RegExp(r'[,;]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return _listSummary(parts, emptyLabel: 'Nothing excluded');
    }
    return _listSummary(chips, emptyLabel: 'Nothing excluded');
  }

  Set<String> _allergyValuesFromSaved(UserModel user) {
    final selected = <String>{};
    final saved = user.foodAllergies;
    if (saved.isEmpty) return selected;
    final lower = saved.map((e) => e.toLowerCase()).toList();
    if (lower.any((e) => e == 'none')) return {'none'};
    if (lower.any((e) => e.contains('prefer not'))) return {'prefer_not'};
    for (final option in LifestyleHabitOptions.foodAllergies) {
      if (option.value == 'none' || option.value == 'prefer_not') continue;
      if (saved.any(
        (s) =>
            s.toLowerCase() == option.label.toLowerCase() ||
            s.toLowerCase() == option.value,
      )) {
        selected.add(option.value);
      }
    }
    return selected;
  }

  Set<String> _avoidValuesFromSaved(UserModel user) {
    final selected = <String>{};
    final text = user.foodsToAvoid.trim();
    if (text.isEmpty) return {'none'};
    final lower = text.toLowerCase();
    if (lower.contains('nothing') || lower == 'none') return {'none'};
    for (final option in LifestyleHabitOptions.foodsToAvoid) {
      if (option.value == 'none') continue;
      if (lower.contains(option.label.toLowerCase()) ||
          lower.contains(option.value.replaceAll('_', ' '))) {
        selected.add(option.value);
      }
    }
    return selected;
  }

  List<String> _allergyLabelsToSave(Set<String> selected) {
    if (selected.contains('none') || selected.isEmpty) return ['None'];
    if (selected.contains('prefer_not')) return ['Prefer not to answer'];
    return LifestyleHabitOptions.foodAllergies
        .where((o) => selected.contains(o.value))
        .map((o) => o.label)
        .toList();
  }

  String _avoidLabelsToSave(Set<String> selected) {
    if (selected.isEmpty || selected.contains('none')) return '';
    return LifestyleHabitOptions.foodsToAvoid
        .where((o) => selected.contains(o.value) && o.value != 'none')
        .map((o) => o.label)
        .join(', ');
  }

  Future<void> _editDietType(UserModel user) async {
    final selected = await showAppOptionsSheet<DietType>(
      context: context,
      title: 'Diet type',
      selected: user.dietType,
      options: [
        for (final type in DietType.values)
          AppSheetOption(value: type, label: type.title, subtitle: type.choiceTitle),
      ],
    );
    if (selected == null) return;
    setState(() {
      user.dietType = selected;
      if (!selected.asksMeatPreferences) {
        user.meatPreferences = List<String>.from(selected.impliedMeatPreferences);
      } else {
        final allowed = LifestyleHabitOptions.meatPreferencesFor(selected)
            .map((o) => o.value)
            .toSet();
        user.meatPreferences =
            user.meatPreferences.where(allowed.contains).toList();
      }
      final likeAllowed = LifestyleHabitOptions.foodPreferencesFor(selected)
          .map((o) => o.value)
          .toSet();
      user.foodPreferences =
          user.foodPreferences.where(likeAllowed.contains).toList();
    });
    _userController.update();
  }

  Future<void> _editMealsPerDay(UserModel user) async {
    final selected = await showAppOptionsSheet<int>(
      context: context,
      title: 'Meals per day',
      selected: user.mealsPerDay,
      options: [
        for (final count in MealsPerDayOptions.values)
          AppSheetOption(
            value: count,
            label: MealsPerDayOptions.countLabel(count),
            subtitle: MealsPerDayOptions.structureLabel(count),
          ),
      ],
    );
    if (selected == null) return;
    setState(() => user.mealsPerDay = selected);
    _userController.update();
  }

  Future<void> _editLivingArea(UserModel user) async {
    final region = await showAppOptionsSheet<String>(
      context: context,
      title: 'Food region',
      selected: user.livingArea,
      options: [
        for (final r in LifestyleHabitOptions.livingRegions)
          AppSheetOption(value: r.value, label: r.label),
      ],
    );
    if (region == null || !mounted) return;

    final regionModel = LifestyleHabitOptions.livingRegionByValue(region);
    if (regionModel == null) return;

    final state = await showAppOptionsSheet<String>(
      context: context,
      title: 'State cuisine',
      selected: user.livingArea == region ? user.livingState : null,
      options: [
        for (final s in regionModel.states)
          AppSheetOption(value: s.value, label: s.label),
      ],
    );
    if (state == null) return;

    setState(() {
      user.livingArea = region;
      user.livingState = state;
    });
    _userController.update();
  }

  Future<void> _editPlanInterest(UserModel user) async {
    final selected = await showAppOptionsSheet<DietPlanInterest>(
      context: context,
      title: 'Plan interest',
      selected: user.dietPlanInterest,
      options: [
        for (final plan in DietPlanInterest.values)
          AppSheetOption(value: plan, label: plan.title),
      ],
    );
    if (selected == null) return;
    setState(() => user.dietPlanInterest = selected);
    _userController.update();
  }

  Future<void> _editAllergies(UserModel user) async {
    final options = LifestyleHabitOptions.foodAllergiesFor(user.dietType);
    final result = await showProfileMultiSelectSheet(
      context: context,
      title: 'Allergies & intolerances',
      initiallySelected: _allergyValuesFromSaved(user),
      exclusiveValues: const ['none', 'prefer_not'],
      options: [
        for (final o in options)
          ProfileFormOption(value: o.value, label: o.label, emoji: o.emoji),
      ],
    );
    if (result == null) return;
    setState(() {
      user.foodAllergies = _allergyLabelsToSave(result.toSet());
    });
    _userController.update();
  }

  Future<void> _editDontEat(UserModel user) async {
    final options = LifestyleHabitOptions.foodsToAvoidFor(user.dietType);
    final result = await showProfileMultiSelectSheet(
      context: context,
      title: "Don't eat",
      initiallySelected: _avoidValuesFromSaved(user),
      exclusiveValue: 'none',
      options: [
        for (final o in options)
          ProfileFormOption(value: o.value, label: o.label, emoji: o.emoji),
      ],
    );
    if (result == null) return;
    setState(() {
      user.foodsToAvoid = _avoidLabelsToSave(result.toSet());
    });
    _userController.update();
  }

  Future<void> _editLikes(UserModel user) async {
    final options = LifestyleHabitOptions.foodPreferencesFor(user.dietType);
    final result = await showProfileMultiSelectSheet(
      context: context,
      title: 'Foods I like',
      initiallySelected: user.foodPreferences.toSet(),
      options: [
        for (final o in options)
          ProfileFormOption(value: o.value, label: o.label, emoji: o.emoji),
      ],
    );
    if (result == null) return;
    setState(() {
      user.foodPreferences = result;
    });
    _userController.update();
  }

  Future<void> _editMeat(UserModel user) async {
    final options = LifestyleHabitOptions.meatPreferencesFor(user.dietType);
    final result = await showProfileMultiSelectSheet(
      context: context,
      title: 'Meat preferences',
      initiallySelected: user.meatPreferences.toSet(),
      options: [
        for (final o in options)
          ProfileFormOption(value: o.value, label: o.label, emoji: o.emoji),
      ],
    );
    if (result == null) return;
    setState(() {
      user.meatPreferences = result;
    });
    _userController.update();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: const AppAppBar(title: 'Food Profile'),
      body: GetBuilder<UserController>(
        builder: (_) {
          final user = _userController.user;
          final showMeat = user.dietType?.asksMeatPreferences ?? false;
          final likesLabel = _listSummary(
            user.foodPreferences,
            emptyLabel: 'Add foods',
            labelOf: (v) => _optionLabel(LifestyleHabitOptions.foodPreferences, v),
          );
          final meatLabel = _listSummary(
            user.meatPreferences,
            emptyLabel: 'Not set',
            labelOf: (v) => _optionLabel(LifestyleHabitOptions.meatPreferences, v),
          );

          return Column(
            children: [
              if (_userController.isLoadingProfile)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    r.scale(20, tablet: 28),
                    r.scale(12),
                    r.scale(20, tablet: 28),
                    r.scale(32),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Update your food preferences for meal suggestions.',
                        style: TextStyle(
                          fontSize: r.scale(13, tablet: 14),
                          color: AppColors.textSecondaryOf(context),
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: r.scale(24)),
                      const ProfileFormSectionLabel(title: 'DIET BASICS'),
                      SizedBox(height: r.scale(10)),
                      ProfileFormInfoRow(
                        label: 'Diet type',
                        subtitle: 'What you usually eat',
                        value: user.dietType?.title ?? 'Not set',
                        wideValue: true,
                        onTap: () => _editDietType(user),
                      ),
                      SizedBox(height: r.scale(10)),
                      ProfileFormInfoRow(
                        label: 'Meals per day',
                        subtitle: user.mealsPerDay != null
                            ? MealsPerDayOptions.structureLabel(
                                user.mealsPerDay!,
                              )
                            : 'How many meals you prefer',
                        value: user.mealsPerDay != null
                            ? MealsPerDayOptions.countLabel(user.mealsPerDay!)
                            : 'Not set',
                        wideValue: true,
                        onTap: () => _editMealsPerDay(user),
                      ),
                      SizedBox(height: r.scale(10)),
                      ProfileFormInfoRow(
                        label: 'Food region',
                        subtitle: 'Cuisine style you like',
                        value: _livingAreaLabel(user),
                        wideValue: true,
                        onTap: () => _editLivingArea(user),
                      ),
                      SizedBox(height: r.scale(10)),
                      ProfileFormInfoRow(
                        label: 'Plan interest',
                        subtitle: 'Meal plan style',
                        value: user.dietPlanInterest?.title ?? 'Not set',
                        wideValue: true,
                        onTap: () => _editPlanInterest(user),
                      ),
                      SizedBox(height: r.scale(22)),
                      const ProfileFormSectionLabel(title: 'RESTRICTIONS'),
                      SizedBox(height: r.scale(10)),
                      ProfileFormInfoRow(
                        label: 'Allergies',
                        subtitle: 'Strict rules for suggestions',
                        value: _allergySummary(user),
                        wideValue: true,
                        onTap: () => _editAllergies(user),
                      ),
                      SizedBox(height: r.scale(10)),
                      ProfileFormInfoRow(
                        label: "Don't eat",
                        subtitle: 'Preferences we try to respect',
                        value: _avoidSummary(user),
                        wideValue: true,
                        onTap: () => _editDontEat(user),
                      ),
                      SizedBox(height: r.scale(22)),
                      const ProfileFormSectionLabel(title: 'PREFERENCES'),
                      SizedBox(height: r.scale(10)),
                      ProfileFormInfoRow(
                        label: 'Foods I like',
                        subtitle: 'Favourites for meal ideas',
                        value: likesLabel,
                        wideValue: true,
                        onTap: () => _editLikes(user),
                      ),
                      if (showMeat) ...[
                        SizedBox(height: r.scale(10)),
                        ProfileFormInfoRow(
                          label: 'Meat preferences',
                          subtitle: 'Meats you prefer',
                          value: meatLabel,
                          wideValue: true,
                          onTap: () => _editMeat(user),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              ProfileFormSaveBar(
                isLoading: _isSaving,
                onSave: _saveChanges,
              ),
            ],
          );
        },
      ),
    );
  }
}
