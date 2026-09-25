import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../models/health_concern.dart';
import '../models/lifestyle_habits.dart';
import '../models/onboarding_request_model.dart';
import '../models/profile_sync_snapshot.dart';
import '../models/user_model.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/profile_form_ui.dart';

/// Profile-only Health & medications editor (form style).
/// Onboarding health / medications question screens are unchanged.
class HealthFormView extends StatefulWidget {
  const HealthFormView({super.key});

  @override
  State<HealthFormView> createState() => _HealthFormViewState();
}

class _HealthFormViewState extends State<HealthFormView> {
  late final UserController _userController = Get.find<UserController>();
  late ProfileSyncSnapshot _baseline;
  bool _isSaving = false;

  static const _conditionCategories = <String>[
    'None',
    'Diabetes',
    'Blood Pressure',
    'Respiratory',
    'Digestive',
    'Stress / Anxiety',
    'Immunity',
    'High Cholesterol',
    'Other',
  ];

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
    var patch = OnboardingPatchModel.healthConcernsDiff(
      user.healthConcerns,
      _baseline,
    );
    if (!ProfileSyncSnapshot.stringListsEqual(
      user.medications,
      _baseline.medications,
    )) {
      patch = patch.merge(
        OnboardingPatchModel.medications(user.medications),
      );
    }

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
    AppSnackbar.success('Health details updated.');
  }

  String _conditionsSummary(UserModel user) {
    final concerns = user.healthConcerns;
    if (concerns.isEmpty) return 'Not set';
    if (concerns.every((c) => c.isNone)) return 'None';
    final labels = concerns
        .where((c) => !c.isNone)
        .map((c) => c.category)
        .where((c) => c.isNotEmpty)
        .toList();
    if (labels.isEmpty) return 'None';
    if (labels.length == 1) return labels.first;
    if (labels.length == 2) return '${labels[0]}, ${labels[1]}';
    return '${labels.length} conditions';
  }

  String _medicationsSummary(UserModel user) {
    final meds = user.medications;
    if (meds.isEmpty) return 'Not set';
    if (meds.length == 1 && meds.first.toLowerCase() == 'no') return 'None';
    final labels = <String>[];
    for (final value in meds) {
      var found = false;
      for (final option in LifestyleHabitOptions.medications) {
        if (option.value == value) {
          labels.add(option.label);
          found = true;
          break;
        }
      }
      if (!found) labels.add(value);
    }
    if (labels.length == 1) return labels.first;
    if (labels.length == 2) return '${labels[0]}, ${labels[1]}';
    return '${labels.length} selected';
  }

  Set<String> _selectedConditionCategories(UserModel user) {
    final concerns = user.healthConcerns;
    if (concerns.isEmpty) return {};
    if (concerns.every((c) => c.isNone)) return {'None'};
    return concerns
        .where((c) => !c.isNone)
        .map((c) => c.category)
        .where((c) => c.isNotEmpty)
        .toSet();
  }

  Future<void> _editConditions(UserModel user) async {
    final existingByCategory = <String, HealthConcern>{
      for (final concern in user.healthConcerns)
        if (!concern.isNone && concern.category.isNotEmpty)
          concern.category: concern,
    };

    final result = await showProfileMultiSelectSheet(
      context: context,
      title: 'Health conditions',
      initiallySelected: _selectedConditionCategories(user),
      exclusiveValue: 'None',
      options: [
        for (final label in _conditionCategories)
          ProfileFormOption(value: label, label: label),
      ],
    );
    if (result == null) return;

    final selected = result.toSet();
    late final List<HealthConcern> next;
    if (selected.isEmpty || selected.contains('None')) {
      next = [HealthConcern.none()];
    } else {
      next = (selected.toList()..sort())
          .map((category) {
            final existing = existingByCategory[category];
            if (existing != null) return existing;
            return HealthConcern(
              category: category,
              description: category == 'Other' ? 'Other health concern' : category,
              duration: '1-6 months',
              severity: 'Mild',
              medication: 'No',
            );
          })
          .toList();
    }

    setState(() {
      user.healthConcerns = next;
    });
    _userController.update();
  }

  Future<void> _editMedications(UserModel user) async {
    final result = await showProfileMultiSelectSheet(
      context: context,
      title: 'Medications',
      initiallySelected: user.medications.toSet(),
      exclusiveValue: 'no',
      options: [
        for (final option in LifestyleHabitOptions.medications)
          ProfileFormOption(
            value: option.value,
            label: option.label,
            emoji: option.emoji,
          ),
      ],
    );
    if (result == null) return;

    setState(() {
      user.medications = result.isEmpty ? ['no'] : (result..sort());
    });
    _userController.update();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: const AppAppBar(title: 'Health & Medications'),
      body: GetBuilder<UserController>(
        builder: (_) {
          final user = _userController.user;

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
                        'These details stay private and only shape your plan.',
                        style: TextStyle(
                          fontSize: r.scale(13, tablet: 14),
                          color: AppColors.textSecondaryOf(context),
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: r.scale(24)),
                      const ProfileFormSectionLabel(title: 'PRIVATE DETAILS'),
                      SizedBox(height: r.scale(10)),
                      ProfileFormInfoRow(
                        label: 'Health conditions',
                        subtitle: 'Conditions that affect your plan',
                        value: _conditionsSummary(user),
                        wideValue: true,
                        onTap: () => _editConditions(user),
                      ),
                      SizedBox(height: r.scale(10)),
                      ProfileFormInfoRow(
                        label: 'Medications',
                        subtitle: 'Anything you’re currently taking',
                        value: _medicationsSummary(user),
                        wideValue: true,
                        onTap: () => _editMedications(user),
                      ),
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
