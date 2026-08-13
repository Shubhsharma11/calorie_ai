import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../models/health_concern.dart';
import '../models/onboarding_request_model.dart';
import '../models/profile_sync_snapshot.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_page.dart';

class HealthProblemView extends StatefulWidget {
  const HealthProblemView({super.key});

  @override
  State<HealthProblemView> createState() => _HealthProblemViewState();
}

class _ConcernFormData {
  _ConcernFormData({HealthConcern? concern, VoidCallback? onChanged})
    : description = TextEditingController(text: concern?.description ?? ''),
      duration = concern?.duration,
      severity = concern?.severity,
      medication = concern?.medication {
    if (onChanged != null) {
      description.addListener(onChanged);
    }
  }

  final TextEditingController description;
  String? duration;
  String? severity;
  String? medication;

  void dispose() => description.dispose();

  HealthConcern toConcern(String category) {
    return HealthConcern(
      category: category,
      description: description.text.trim(),
      duration: duration,
      severity: severity,
      medication: medication,
    );
  }

  bool get isComplete =>
      description.text.trim().isNotEmpty &&
      duration != null &&
      severity != null &&
      medication != null;
}

class _HealthProblemViewState extends State<HealthProblemView> {
  late final UserController _user = Get.find<UserController>();
  final Set<String> _selectedCategories = {};
  final Map<String, _ConcernFormData> _forms = {};
  final Set<String> _expandedCategories = {};
  /// null = not chosen yet, true = has concerns, false = none
  bool? _hasConcerns;
  late ProfileSyncSnapshot _baseline;
  bool _isSaving = false;

  static const _categories = [
    _ProblemCategory(label: 'Diabetes', asset: 'assets/image/glucosemeter.svg'),
    _ProblemCategory(
      label: 'Blood Pressure',
      asset: 'assets/image/blood_pressure.svg',
    ),
    _ProblemCategory(label: 'Respiratory', asset: 'assets/image/lungs.svg'),
    _ProblemCategory(label: 'Digestive', asset: 'assets/image/stomach.svg'),
    _ProblemCategory(
      label: 'Stress / Anxiety',
      asset: 'assets/image/anxiety.svg',
    ),
    _ProblemCategory(label: 'Immunity', asset: 'assets/image/immunity.svg'),
    _ProblemCategory(
      label: 'High Cholesterol',
      asset: 'assets/image/Cholesterol.svg',
    ),
    _ProblemCategory(label: 'Other', asset: 'assets/image/menu (1).svg'),
  ];

  static const _durationOptions = [
    'Less than a week',
    '1-4 weeks',
    '1-6 months',
    'More than 6 months',
  ];
  static const _severityOptions = ['Mild', 'Moderate', 'Severe'];
  static const _medicationOptions = ['No', 'Yes', 'Prefer not to say'];

  bool get _fromProfile => RouteArgs.isEditingFromProfile;
  bool get _noneSelected => _hasConcerns == false;

  @override
  void initState() {
    super.initState();
    _baseline = _user.captureProfileSyncSnapshot();
    for (final concern in _user.user.healthConcerns) {
      if (concern.isNone) {
        _hasConcerns = false;
        continue;
      }
      _hasConcerns = true;
      _selectedCategories.add(concern.category);
      _forms[concern.category] = _ConcernFormData(
        concern: concern,
        onChanged: _persistPartialHealth,
      );
      _expandedCategories.add(concern.category);
    }
  }

  @override
  void dispose() {
    for (final form in _forms.values) {
      form.dispose();
    }
    super.dispose();
  }

  void _persistPartialHealth() {
    if (_fromProfile) return;
    unawaited(_savePartialHealth());
  }

  Future<void> _savePartialHealth() async {
    if (_noneSelected) {
      await _user.saveHealthConcerns([HealthConcern.none()]);
      return;
    }

    if (_selectedCategories.isEmpty) {
      await _user.saveHealthConcerns([]);
      return;
    }

    final concerns = (_selectedCategories.toList()..sort())
        .map((category) => _forms[category]!.toConcern(category))
        .toList();
    await _user.saveHealthConcerns(concerns);
  }

  Future<void> _onBack() async {
    if (_isSaving) return;
    if (_fromProfile) {
      Get.back<void>();
      return;
    }
    await _savePartialHealth();
    await _user.goToPreviousOnboardingStep(AppRoutes.healthProblem);
  }

  Future<void> _continue() async {
    if (_isSaving) return;
    if (_hasConcerns == null) {
      _showValidationMessage(
        'Make a choice',
        'Please tell us whether you have any health concerns.',
      );
      return;
    }

    if (_noneSelected) {
      await _saveAndFinish([HealthConcern.none()]);
      return;
    }

    if (_selectedCategories.isEmpty) {
      _showValidationMessage(
        'Select a concern',
        'Please choose one or more health concerns before continuing.',
      );
      return;
    }

    final sortedCategories = _selectedCategories.toList()..sort();
    for (final category in sortedCategories) {
      final form = _forms[category];
      if (form == null) continue;

      final description = form.description.text.trim();
      if (description.isEmpty) {
        _showValidationMessage(
          'Describe $category',
          'Please add a short description for $category before continuing.',
        );
        setState(() => _expandedCategories.add(category));
        return;
      }

      if (category == 'Other' && description.length < 8) {
        _showValidationMessage(
          'Describe your other concern',
          'Please explain your other health concern in a bit more detail.',
        );
        setState(() => _expandedCategories.add(category));
        return;
      }

      if (!form.isComplete) {
        _showValidationMessage(
          'Complete $category details',
          'Please fill in duration, severity, and medication for $category.',
        );
        setState(() => _expandedCategories.add(category));
        return;
      }
    }

    final concerns = sortedCategories
        .map((category) => _forms[category]!.toConcern(category))
        .toList();

    await _saveAndFinish(concerns);
  }

  Future<void> _saveAndFinish(List<HealthConcern> concerns) async {
    await _user.saveHealthConcerns(concerns);

    if (_fromProfile) {
      final patch = OnboardingPatchModel.healthConcernsDiff(
        concerns,
        _baseline,
      );
      if (patch.isEmpty) {
        AppSnackbar.info('No changes to save.', title: 'Nothing changed');
        Get.back();
        return;
      }

      FocusScope.of(context).unfocus();
      setState(() => _isSaving = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      try {
        final error = await _user.patchOnboarding(patch);
        if (!mounted) return;
        if (error != null) {
          AppSnackbar.error(error, title: 'Save failed');
          return;
        }
        _baseline = _user.captureProfileSyncSnapshot();
        Get.back();
        AppSnackbar.success('Health concerns updated.');
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
      return;
    }

    await _user.persistOnboardingStep(AppRoutes.nutritionPlanLoading);
    Get.toNamed(AppRoutes.nutritionPlanLoading);
  }

  void _showValidationMessage(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _selectHasConcerns(bool hasConcerns) {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _hasConcerns = hasConcerns;
      if (!hasConcerns) {
        for (final form in _forms.values) {
          form.dispose();
        }
        _forms.clear();
        _selectedCategories.clear();
        _expandedCategories.clear();
      }
    });
    _persistPartialHealth();
  }

  void _toggleCategory(String category) {
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _hasConcerns = true;
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
        _expandedCategories.remove(category);
        _forms.remove(category)?.dispose();
      } else {
        _selectedCategories.add(category);
        _forms[category] = _ConcernFormData(onChanged: _persistPartialHealth);
        _expandedCategories.add(category);
      }
    });
    _persistPartialHealth();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final compact = r.height < 760;
    final showingConcerns = _hasConcerns == true;
    final hasHealthConcerns =
        showingConcerns && _selectedCategories.isNotEmpty;
    final sortedCategories = _selectedCategories.toList()..sort();
    final actionLabel = _fromProfile ? 'Save' : 'Continue';

    return PopScope(
      canPop: _fromProfile && !_isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_onBack());
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppAppBar.backOnly(onBack: () => unawaited(_onBack())),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SetupScreenLayout(
            scrollable: true,
            content: AbsorbPointer(
              absorbing: _isSaving,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                SizedBox(height: r.scale(compact ? 4 : 8)),
                _HeroSection(r: r, compact: compact),
                SizedBox(height: r.scale(compact ? 14 : 18)),
                Text(
                  'Do you have any health concerns?',
                  style: TextStyle(
                    fontSize: r.scale(17, tablet: 18),
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: r.scale(4)),


                Text(
                  'Start with Yes or No — easy to change anytime.',
                  style: TextStyle(
                    fontSize: r.scale(13, tablet: 14),
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: r.scale(12)),
                _PathChoiceRow(
                  hasConcerns: _hasConcerns,
                  onSelect: _selectHasConcerns,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _noneSelected
                      ? Padding(
                          padding: EdgeInsets.only(top: r.scale(14)),
                          child: _NoneConfirmedCard(actionLabel: actionLabel),
                        )
                      : const SizedBox.shrink(),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: showingConcerns
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: r.scale(compact ? 18 : 22)),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Which ones apply?',
                                    style: TextStyle(
                                      fontSize: r.scale(17, tablet: 18),
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (hasHealthConcerns)
                                  _CountBadge(
                                    count: _selectedCategories.length,
                                  ),
                              ],
                            ),
                            SizedBox(height: r.scale(4)),
                            Text(
                              'Select all that apply. Tap again to remove.',
                              style: TextStyle(
                                fontSize: r.scale(13, tablet: 14),
                                color: AppColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                            SizedBox(height: r.scale(12)),
                            _CategoryGrid(
                              categories: _categories,
                              selectedCategories: _selectedCategories,
                              onChanged: _toggleCategory,
                            ),
                            if (_selectedCategories.isEmpty) ...[
                              SizedBox(height: r.scale(14)),
                              const _GuidanceCard(
                                iconAsset: 'assets/image/point.svg',
                                title: 'Select your concerns',
                                message:
                                    'Choose one or more categories, then add details for each.',
                              ),
                            ],
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                if (hasHealthConcerns) ...[
                  SizedBox(height: r.scale(compact ? 18 : 22)),
                  _SectionTitle(text: 'Details for Each Concern', r: r),
                  SizedBox(height: r.scale(6)),
                  Text(
                    'Expand each concern and add its own description and details.',
                    style: TextStyle(
                      fontSize: r.scale(13, tablet: 14),
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: r.scale(12)),
                  ...sortedCategories.map((category) {
                    final form = _forms[category]!;
                    final asset = _categories
                        .firstWhere((item) => item.label == category)
                        .asset;
                    return Padding(
                      padding: EdgeInsets.only(bottom: r.scale(12)),
                      child: _ConcernDetailCard(
                        category: category,
                        asset: asset,
                        form: form,
                        expanded: _expandedCategories.contains(category),
                        onExpansionChanged: (expanded) {
                          setState(() {
                            if (expanded) {
                              _expandedCategories.add(category);
                            } else {
                              _expandedCategories.remove(category);
                            }
                          });
                        },
                        onChanged: () {
                          setState(() {});
                          _persistPartialHealth();
                        },
                      ),
                    );
                  }),
                ],
              ],
            ),
            ),
            action: PrimaryButton(
              label: actionLabel,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : () => unawaited(_continue()),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProblemCategory {
  const _ProblemCategory({
    required this.label,
    required this.asset,
  });

  final String label;
  final String asset;
}

class _ConcernDetailCard extends StatelessWidget {
  const _ConcernDetailCard({
    required this.category,
    required this.asset,
    required this.form,
    required this.expanded,
    required this.onExpansionChanged,
    required this.onChanged,
  });

  final String category;
  final String asset;
  final _ConcernFormData form;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final complete = form.isComplete;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: _SetupCard.decoration(
        selected: complete,
        highlighted: expanded && !complete,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onExpansionChanged(!expanded),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: r.scale(14),
                  vertical: r.scale(14),
                ),
                child: Row(
                  children: [
                    _CategoryIconBadge(
                      asset: asset,
                      selected: complete || expanded,
                      size: r.scale(44),
                    ),
                    SizedBox(width: r.scale(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: r.scale(15, tablet: 16),
                              fontWeight: FontWeight.w700,
                              color: complete || expanded
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: r.scale(4)),
                          Text(
                            complete
                                ? 'Details complete'
                                : 'Tap to add details',
                            style: TextStyle(
                              fontSize: r.scale(12, tablet: 13),
                              color: complete
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: complete
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: r.scale(8)),
                    _SelectionIndicator(selected: complete),
                    SizedBox(width: r.scale(4)),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                      size: r.scale(22),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            sizeCurve: Curves.easeOutCubic,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Divider(height: 1, color: AppColors.border),
                Container(
                  color: AppColors.surface.withValues(alpha: 0.65),
                  padding: EdgeInsets.fromLTRB(
                    r.scale(14),
                    r.scale(14),
                    r.scale(14),
                    r.scale(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DescriptionField(
                        controller: form.description,
                        category: category,
                        onChanged: onChanged,
                      ),
                      SizedBox(height: r.scale(12)),
                      _DetailDropdown(
                        icon: Icons.calendar_month_rounded,
                        hint: 'When did you first notice this concern?',
                        value: form.duration,
                        options: _HealthProblemViewState._durationOptions,
                        onChanged: (value) {
                          form.duration = value;
                          onChanged();
                        },
                      ),
                      SizedBox(height: r.scale(10)),
                      _DetailDropdown(
                        icon: Icons.bar_chart_rounded,
                        hint: 'How much is this affecting you right now?',
                        value: form.severity,
                        options: _HealthProblemViewState._severityOptions,
                        onChanged: (value) {
                          form.severity = value;
                          onChanged();
                        },
                      ),
                      SizedBox(height: r.scale(10)),
                      _DetailDropdown(
                        icon: Icons.medication_rounded,
                        hint: 'Are you taking anything for this concern?',
                        value: form.medication,
                        options: _HealthProblemViewState._medicationOptions,
                        onChanged: (value) {
                          form.medication = value;
                          onChanged();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(10),
        vertical: r.scale(5),
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Text(
        '$count selected',
        style: TextStyle(
          fontSize: r.scale(12, tablet: 13),
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _CategoryIconBadge extends StatelessWidget {
  const _CategoryIconBadge({
    required this.asset,
    required this.selected,
    required this.size,
  });

  final String asset;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.2),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.14)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.28)
              : AppColors.border,
        ),
      ),
      child: SvgPicture.asset(asset, fit: BoxFit.contain),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 16,
          color: AppColors.onPrimary,
        ),
      );
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
    );
  }
}

abstract final class _SetupCard {
  static BoxDecoration decoration({
    bool selected = false,
    bool highlighted = false,
  }) {
    final active = selected || highlighted;

    return BoxDecoration(
      color: selected ? AppColors.selectionFill : AppColors.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: active ? AppColors.primary : AppColors.border,
        width: active ? 1.5 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowColor,
          blurRadius: active ? 8 : 4,
          offset: Offset(0, active ? 2 : 1),
        ),
      ],
    );
  }
}

class _PathChoiceRow extends StatelessWidget {
  const _PathChoiceRow({
    required this.hasConcerns,
    required this.onSelect,
  });

  final bool? hasConcerns;
  final ValueChanged<bool> onSelect;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Row(
      children: [
        Expanded(
          child: _PathChoiceCard(
            title: 'Yes',
            subtitle: 'I have concerns',
            imageAsset: 'assets/image/heartbeat.svg',
            selected: hasConcerns == true,
            onTap: () => onSelect(true),
          ),
        ),
        SizedBox(width: r.scale(10)),
        Expanded(
          child: _PathChoiceCard(
            title: 'No',
            subtitle: "I don't have any",
            imageAsset: 'assets/image/smile.svg',
            selected: hasConcerns == false,
            onTap: () => onSelect(false),
          ),
        ),
      ],
    );
  }
}

class _PathChoiceCard extends StatelessWidget {
  const _PathChoiceCard({
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String imageAsset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(
            r.scale(14),
            r.scale(14),
            r.scale(12),
            r.scale(14),
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.selectionFill : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.8 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.shadowColor,
                blurRadius: selected ? 14 : 8,
                offset: Offset(0, selected ? 4 : 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: r.scale(40),
                    height: r.scale(40),
                    child: SvgPicture.asset(
                      imageAsset,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const Spacer(),
                  _SelectionIndicator(selected: selected),
                ],
              ),
              SizedBox(height: r.scale(12)),
              Text(
                title,
                style: TextStyle(
                  fontSize: r.scale(20, tablet: 21),
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              SizedBox(height: r.scale(4)),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: r.scale(12, tablet: 13),
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoneConfirmedCard extends StatelessWidget {
  const _NoneConfirmedCard({required this.actionLabel});

  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(14),
        vertical: r.scale(14),
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: r.scale(36),
            height: r.scale(36),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              color: AppColors.primary,
              size: r.scale(20),
            ),
          ),
          SizedBox(width: r.scale(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No health concerns',
                  style: TextStyle(
                    fontSize: r.scale(14, tablet: 15),
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: r.scale(2)),
                Text(
                  'Tap $actionLabel below when you\'re ready.',
                  style: TextStyle(
                    fontSize: r.scale(12, tablet: 13),
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.r, required this.compact});

  final Responsive r;
  final bool compact;

  static const _heroAsset = 'assets/image/medical_report.svg';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(2),
        vertical: r.scale(compact ? 0 : 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: r.scale(compact ? 22 : 24, tablet: 26),
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.18,
                      letterSpacing: -0.4,
                    ),
                    children: [
                      const TextSpan(text: "We're here for\n"),
                      const TextSpan(
                        text: 'your health',
                        style: TextStyle(color: AppColors.primary),
                      ),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: EdgeInsets.only(left: r.scale(5)),
                          child: Icon(
                            Icons.favorite_border_rounded,
                            size: r.scale(compact ? 18 : 20, tablet: 22),
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r.scale(compact ? 5 : 6)),
                Text(
                  'Tell us a little about your health so we can personalize your journey.',
                  style: TextStyle(
                    fontSize: r.scale(compact ? 12 : 13, tablet: 14),
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: r.scale(10)),
          SizedBox(
            width: r.scale(compact ? 96 : 110, tablet: 124),
            height: r.scale(compact ? 96 : 110, tablet: 124),
            child: SvgPicture.asset(
              _heroAsset,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.r});

  final String text;
  final Responsive r;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: r.scale(16, tablet: 17),
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({
    required this.iconAsset,
    required this.title,
    required this.message,
  });

  final String iconAsset;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(14),
        vertical: r.scale(14),
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: r.scale(34),
            height: r.scale(34),
            child: SvgPicture.asset(iconAsset, fit: BoxFit.contain),
          ),
          SizedBox(width: r.scale(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: r.scale(14, tablet: 15),
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: r.scale(4)),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: r.scale(12, tablet: 13),
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selectedCategories,
    required this.onChanged,
  });

  final List<_ProblemCategory> categories;
  final Set<String> selectedCategories;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final crossAxisCount = r.width < 600 ? 2 : 3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: r.scale(10),
        crossAxisSpacing: r.scale(10),
        childAspectRatio: r.isTablet ? 2.4 : 2.2,
      ),
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryCard(
          category: category,
          selected: selectedCategories.contains(category.label),
          onTap: () => onChanged(category.label),
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final _ProblemCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(10),
            vertical: r.scale(10),
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.selectionFill : AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: selected ? 8 : 5,
                offset: Offset(0, selected ? 2 : 1),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: r.scale(34, tablet: 36),
                height: r.scale(34, tablet: 36),
                child: SvgPicture.asset(
                  category.asset,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: r.scale(8)),
              Expanded(
                child: Text(
                  category.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r.scale(12, tablet: 13),
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    height: 1.15,
                  ),
                ),
              ),
              SizedBox(width: r.scale(4)),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: r.scale(18),
                height: r.scale(18),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        size: r.scale(12),
                        color: AppColors.onPrimary,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DescriptionField extends StatelessWidget {
  const _DescriptionField({
    required this.controller,
    required this.category,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String category;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final hint = category == 'Other'
        ? 'Please describe your health concern in detail.'
        : 'Describe your $category symptoms, when they started, and how often they occur.';

    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      minLines: 3,
      maxLines: 4,
      maxLength: 500,
      textInputAction: TextInputAction.newline,
      style: TextStyle(
        fontSize: r.scale(14, tablet: 15),
        color: AppColors.textPrimary,
        height: 1.35,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.card,
        alignLabelWithHint: true,
        labelText: 'Description',
        labelStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: r.scale(13, tablet: 14),
        ),
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: r.scale(13, tablet: 14),
          height: 1.35,
        ),
        counterStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: r.scale(12),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: r.scale(14),
          vertical: r.scale(12),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _DetailDropdown extends StatelessWidget {
  const _DetailDropdown({
    required this.icon,
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final IconData icon;
  final String hint;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  Future<void> _showOptions(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        final r = context.responsive;       

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: r.height * 0.62),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  r.scale(18),
                  r.scale(14),
                  r.scale(18),
                  r.scale(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    SizedBox(height: r.scale(16)),
                    Text(
                      hint,
                      style: TextStyle(
                        fontSize: r.scale(17, tablet: 18),
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: r.scale(14)),
                    ...options.map(
                      (option) => Padding(
                        padding: EdgeInsets.only(bottom: r.scale(8)),
                        child: _OptionTile(
                          label: option,
                          selected: option == value,
                          onTap: () => Navigator.of(context).pop(option),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          FocusScope.of(context).unfocus();
          _showOptions(context);
        },
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: value == null
                  ? AppColors.border.withValues(alpha: 0.85)
                  : AppColors.primary,
              width: value == null ? 1 : 1.5,
            ),
            boxShadow: value == null
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Container(
            constraints: BoxConstraints(minHeight: r.scale(56, tablet: 60)),
            padding: EdgeInsets.symmetric(
              horizontal: r.scale(14),
              vertical: r.scale(12),
            ),
            child: Row(
              children: [
                Container(
                  width: r.scale(34),
                  height: r.scale(34),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: r.scale(18),
                  ),
                ),
                SizedBox(width: r.scale(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: r.scale(12, tablet: 13),
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: r.scale(4)),
                      _SelectedValueLabel(value: value),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                  size: r.scale(22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedValueLabel extends StatelessWidget {
  const _SelectedValueLabel({required this.value});

  final String? value;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    if (value == null) {
      return Text(
        'Choose an option',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: r.scale(12, tablet: 13),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(8),
        vertical: r.scale(2),
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: r.scale(12, tablet: 13),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.1)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(14),
            vertical: r.scale(13),
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
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: r.scale(14, tablet: 15),
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: r.scale(20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


    
    
    
  