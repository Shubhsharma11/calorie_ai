import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../models/activity_level.dart';
import '../models/onboarding_request_model.dart';
import '../models/profile_sync_snapshot.dart';
import '../models/user_model.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/primary_button.dart';

class PersonalInformationView extends StatefulWidget {
  const PersonalInformationView({super.key});

  @override
  State<PersonalInformationView> createState() =>
      _PersonalInformationViewState();
}

class _PersonalInformationViewState extends State<PersonalInformationView> {
  late final UserController _userController = Get.find<UserController>();
  late ProfileSyncSnapshot _baseline;
  bool _isSaving = false;

  static Color _valueBackground(BuildContext context) =>
      AppColors.surfaceOf(context);

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
    final patch = OnboardingPatchModel.profileDiff(user, _baseline);
    if (patch.isEmpty) {
      AppSnackbar.info('No changes to save.', title: 'Nothing changed');
      return;
    }

    final changedSummary = _changedFieldsSummary(user);

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
    _userController.syncWeightFromProfile();
    Get.back();
    AppSnackbar.success(changedSummary);
  }

  String _changedFieldsSummary(UserModel user) {
    final changed = <String>[];
    if (user.age != _baseline.age) changed.add('Age');
    if (user.gender != _baseline.gender) changed.add('Gender');
    if (user.heightCm != _baseline.heightCm) changed.add('Height');
    if (user.weightKg != _baseline.weightKg) changed.add('Weight');
    if (user.activityLevel != _baseline.activityLevel) {
      changed.add('Activity level');
    }

    if (changed.isEmpty) return 'Your changes were saved.';
    if (changed.length == 1) return '${changed.first} updated.';
    final last = changed.removeLast();
    return '${changed.join(', ')} and $last updated.';
  }

  Future<void> _editAge(UserModel user) async {
    final result = await _showNumberDialog(
      title: 'Age',
      initialValue: '${user.age}',
      unit: 'years',
      maxLength: 3,
    );
    if (result == null) return;
    final age = int.tryParse(result);
    if (age == null || age < 1 || age > 100) {
      AppSnackbar.error(
        'Please enter a valid age between 1 and 100.',
        title: 'Invalid age',
      );
      return;
    }
    setState(() => user.age = age);
    _userController.update();
  }

  Future<void> _editGender(UserModel user) async {
    const options = ['Male', 'Female'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select gender',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
              ),
              for (final option in options)
                ListTile(
                  title: Text(option),
                  trailing: user.gender == option
                      ? const Icon(Icons.check_rounded, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(option),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    setState(() => user.gender = selected);
    _userController.update();
  }

  Future<void> _editHeight(UserModel user) async {
    final result = await _showNumberDialog(
      title: 'Height',
      initialValue: '${user.heightCm}',
      unit: 'cm',
      maxLength: 3,
    );
    if (result == null) return;
    final height = int.tryParse(result);
    if (height == null || height < 100 || height > 250) {
      AppSnackbar.error(
        'Please enter a valid height between 100 and 250 cm.',
        title: 'Invalid height',
      );
      return;
    }
    setState(() => user.heightCm = height);
    _userController.update();
  }

  Future<void> _editWeight(UserModel user) async {
    final result = await _showNumberDialog(
      title: 'Weight',
      initialValue: '${user.weightKg}',
      unit: 'kg',
      maxLength: 3,
    );
    if (result == null) return;
    final weight = int.tryParse(result);
    if (weight == null || weight < 30 || weight > 300) {
      AppSnackbar.error(
        'Please enter a valid weight between 30 and 300 kg.',
        title: 'Invalid weight',
      );
      return;
    }
    setState(() => user.weightKg = weight);
    _userController.update();
  }

  Future<void> _editActivityLevel(UserModel user) async {
    final selected = await showModalBottomSheet<ActivityLevel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final r = context.responsive;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              r.scale(16),
              r.scale(12),
              r.scale(16),
              r.scale(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: r.scale(14)),
                Text(
                  'Activity Level',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: r.scale(17, tablet: 18),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                SizedBox(height: r.scale(14)),
                ...ActivityLevel.values.map(
                  (level) => Padding(
                    padding: EdgeInsets.only(bottom: r.scale(8)),
                    child: _ActivityOptionTile(
                      level: level,
                      selected: user.activityLevel == level,
                      onTap: () => Navigator.of(ctx).pop(level),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null) return;
    _userController.selectActivity(selected);
    setState(() {});
  }

  Future<String?> _showNumberDialog({
    required String title,
    required String initialValue,
    required String unit,
    required int maxLength,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: maxLength,
          autofocus: true,
          decoration: InputDecoration(
            suffixText: unit,
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: const AppAppBar(title: 'Personal Information'),
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
                    r.scale(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Update your personal details',
                        style: TextStyle(
                          fontSize: r.scale(13, tablet: 14),
                          color: AppColors.textSecondaryOf(context),
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: r.scale(24)),
                      _SectionLabel(title: 'BASIC DETAILS'),
                      SizedBox(height: r.scale(10)),
                      _InfoRow(
                        label: 'Age',
                        subtitle: 'Your current age',
                        value: '${user.age}',
                        unit: 'years',
                        onTap: () => _editAge(user),
                      ),
                      SizedBox(height: r.scale(10)),
                      _InfoRow(
                        label: 'Gender',
                        subtitle: 'Select your gender',
                        value: user.gender,
                        onTap: () => _editGender(user),
                      ),
                      SizedBox(height: r.scale(22)),
                      _SectionLabel(title: 'BODY MEASUREMENTS'),
                      SizedBox(height: r.scale(10)),
                      _InfoRow(
                        label: 'Height',
                        subtitle: 'Your height',
                        value: '${user.heightCm}',
                        unit: 'cm',
                        onTap: () => _editHeight(user),
                      ),
                      SizedBox(height: r.scale(10)),
                      _InfoRow(
                        label: 'Weight',
                        subtitle: 'Your current weight',
                        value: '${user.weightKg}',
                        unit: 'kg',
                        onTap: () => _editWeight(user),
                      ),
                      SizedBox(height: r.scale(22)),
                      _SectionLabel(title: 'LIFESTYLE'),
                      SizedBox(height: r.scale(10)),
                      _InfoRow(
                        label: 'Activity Level',
                        subtitle: 'Your daily activity level',
                        value: user.activityLevel.title,
                        wideValue: true,
                        onTap: () => _editActivityLevel(user),
                      ),
                      SizedBox(height: r.scale(22)),
                      const _WhyWeNeedThisCard(),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.45),
                    ),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  r.scale(20, tablet: 28),
                  r.scale(12),
                  r.scale(20, tablet: 28),
                  r.scale(12) + MediaQuery.paddingOf(context).bottom,
                ),
                child: PrimaryButton(
                  label: 'Save Changes',
                  isLoading: _isSaving,
                  onPressed: _saveChanges,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Row(
      children: [
        Container(
          width: 3,
          height: r.scale(16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: r.scale(8)),
        Text(
          title,
          style: TextStyle(
            fontSize: r.scale(12, tablet: 13),
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondaryOf(context),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onTap,
    this.unit,
    this.wideValue = false,
  });

  final String label;
  final String subtitle;
  final String value;
  final String? unit;
  final bool wideValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final displayValue = unit == null ? value : '$value $unit';

    return Material(
      color: AppColors.cardOf(context),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  r.scale(16),
                  r.scale(14),
                  r.scale(wideValue ? 156 : 116),
                  r.scale(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: r.scale(15, tablet: 16),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    SizedBox(height: r.scale(2)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: r.scale(12, tablet: 13),
                        color: AppColors.textSecondaryOf(context),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: r.scale(12),
                top: r.scale(12),
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: r.scale(wideValue ? 108 : 84),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: r.scale(wideValue ? 12 : 14),
                    vertical: r.scale(9),
                  ),
                  decoration: BoxDecoration(
                    color: _PersonalInformationViewState._valueBackground(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: r.scale(wideValue ? 124 : 80),
                        ),
                        child: Text(
                          displayValue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: r.scale(13, tablet: 14),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimaryOf(context).withValues(alpha: 0.82),
                          ),
                        ),
                      ),
                      SizedBox(width: r.scale(4)),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: r.scale(18),
                        color: AppColors.textSecondaryOf(context).withValues(alpha: 0.75),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhyWeNeedThisCard extends StatelessWidget {
  const _WhyWeNeedThisCard();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.scale(16)),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: r.scale(40),
                height: r.scale(40),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.primary,
                  size: r.scale(22),
                ),
              ),
              SizedBox(width: r.scale(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Why we need this?',
                      style: TextStyle(
                        fontSize: r.scale(15, tablet: 16),
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    SizedBox(height: r.scale(6)),
                    Text(
                      'This helps us personalize your calorie goal and recommendations.',
                      style: TextStyle(
                        fontSize: r.scale(13, tablet: 14),
                        color: AppColors.textSecondaryOf(context),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: r.scale(8),
          bottom: r.scale(4),
          child: IgnorePointer(
            child: Icon(
              Icons.spa_outlined,
              size: r.scale(48),
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityOptionTile extends StatelessWidget {
  const _ActivityOptionTile({
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
      color: AppColors.cardOf(context),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(12),
            vertical: r.scale(12),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.title,
                      style: TextStyle(
                        fontSize: r.scale(15),
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      level.description,
                      style: TextStyle(
                        fontSize: r.scale(12),
                        color: AppColors.textSecondaryOf(context),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.primary : AppColors.textSecondaryOf(context),
                size: r.scale(22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
