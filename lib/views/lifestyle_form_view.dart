import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../models/activity_level.dart';
import '../models/lifestyle_habits.dart';
import '../models/onboarding_request_model.dart';
import '../models/profile_sync_snapshot.dart';
import '../models/user_model.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/profile_form_ui.dart';

/// Profile-only Lifestyle editor (Personal Information–style form).
/// Onboarding habit question screens are unchanged.
class LifestyleFormView extends StatefulWidget {
  const LifestyleFormView({super.key});

  @override
  State<LifestyleFormView> createState() => _LifestyleFormViewState();
}

class _LifestyleFormViewState extends State<LifestyleFormView> {
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
    var patch = OnboardingPatchModel.activityLevelDiff(
      user.activityLevel,
      _baseline,
    );
    if (user.eatingHabits != _baseline.eatingHabits &&
        user.eatingHabits != null) {
      patch = patch.merge(
        OnboardingPatchModel.eatingHabits(user.eatingHabits!),
      );
    }
    if (user.cookingSkills != _baseline.cookingSkills &&
        user.cookingSkills != null) {
      patch = patch.merge(
        OnboardingPatchModel.cookingSkills(user.cookingSkills!),
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
    AppSnackbar.success('Lifestyle updated.');
  }

  String _optionLabel(List<HabitOption> options, String? value) {
    if (value == null || value.isEmpty) return 'Not set';
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return value;
  }

  Future<void> _editActivityLevel(UserModel user) async {
    final selected = await showAppBottomSheet<ActivityLevel>(
      context: context,
      builder: (ctx) {
        final r = ctx.responsive;
        return AppSheetScaffold(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Activity Level',
                style: TextStyle(
                  fontSize: r.scale(18),
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: r.scale(14)),
              ...ActivityLevel.values.map(
                (level) => Padding(
                  padding: EdgeInsets.only(bottom: r.scale(8)),
                  child: Material(
                    color: user.activityLevel == level
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(ctx).pop(level),
                      child: Padding(
                        padding: EdgeInsets.all(r.scale(14)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              level.title,
                              style: TextStyle(
                                fontSize: r.scale(15),
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: r.scale(4)),
                            Text(
                              level.description,
                              style: TextStyle(
                                fontSize: r.scale(12),
                                height: 1.35,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    _userController.selectActivity(selected);
    setState(() {});
  }

  Future<void> _editEatingHabits(UserModel user) async {
    final selected = await showAppOptionsSheet<String>(
      context: context,
      title: 'Eating habits',
      selected: user.eatingHabits,
      options: [
        for (final option in LifestyleHabitOptions.eatingHabits)
          AppSheetOption(value: option.value, label: option.label),
      ],
    );
    if (selected == null) return;
    setState(() => user.eatingHabits = selected);
    _userController.update();
  }

  Future<void> _editCookingSkills(UserModel user) async {
    final selected = await showAppOptionsSheet<String>(
      context: context,
      title: 'Cooking skills',
      selected: user.cookingSkills,
      options: [
        for (final option in LifestyleHabitOptions.cookingSkills)
          AppSheetOption(value: option.value, label: option.label),
      ],
    );
    if (selected == null) return;
    setState(() => user.cookingSkills = selected);
    _userController.update();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: const AppAppBar(title: 'Lifestyle'),
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
                        'Update how you move and eat day to day.',
                        style: TextStyle(
                          fontSize: r.scale(13, tablet: 14),
                          color: AppColors.textSecondaryOf(context),
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: r.scale(24)),
                      const ProfileFormSectionLabel(title: 'DAILY LIFESTYLE'),
                      SizedBox(height: r.scale(10)),
                      ProfileFormInfoRow(
                        label: 'Activity level',
                        subtitle: 'Your daily activity level',
                        value: user.activityLevel?.title ?? 'Not set',
                        wideValue: true,
                        onTap: () => _editActivityLevel(user),
                      ),
                      SizedBox(height: r.scale(10)),
                      ProfileFormInfoRow(
                        label: 'Eating habits',
                        subtitle: 'How varied your meals are',
                        value: _optionLabel(
                          LifestyleHabitOptions.eatingHabits,
                          user.eatingHabits,
                        ),
                        wideValue: true,
                        onTap: () => _editEatingHabits(user),
                      ),
                      SizedBox(height: r.scale(10)),
                      ProfileFormInfoRow(
                        label: 'Cooking skills',
                        subtitle: 'How comfortable you are cooking',
                        value: _optionLabel(
                          LifestyleHabitOptions.cookingSkills,
                          user.cookingSkills,
                        ),
                        wideValue: true,
                        onTap: () => _editCookingSkills(user),
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
