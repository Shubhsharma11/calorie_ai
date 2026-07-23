import 'dart:async';

import 'package:flutter/material.dart';
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
  bool _noneSelected = false;
  late ProfileSyncSnapshot _baseline;

  static const _categories = [
    _ProblemCategory(label: 'Diabetes', asset: 'assets/image/glucosemeter.svg'),
    _ProblemCategory(
      label: 'Blood Pressure',
      shortLabel: 'Blood\nPressure',
      asset: 'assets/image/blood_pressure.svg',
    ),
    _ProblemCategory(label: 'Respiratory', asset: 'assets/image/lungs.svg'),
    _ProblemCategory(label: 'Digestive', asset: 'assets/image/stomach.svg'),
    _ProblemCategory(
      label: 'Stress / Anxiety',
      shortLabel: 'Stress',
      asset: 'assets/image/anxiety.svg',
    ),
    _ProblemCategory(label: 'Immunity', asset: 'assets/image/immunity.svg'),
    _ProblemCategory(
      label: 'High Cholesterol',
      shortLabel: 'High\nCholesterol',
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
  static const _heroAsset = 'assets/image/notebook.png';

  bool get _fromProfile => RouteArgs.isEditingFromProfile;

  @override
  void initState() {
    super.initState();
    _baseline = _user.captureProfileSyncSnapshot();
    for (final concern in _user.user.healthConcerns) {
      if (concern.isNone) {
        _noneSelected = true;
        continue;
      }
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
    if (_fromProfile) {
      Get.back<void>();
      return;
    }
    await _savePartialHealth();
    await _user.goToPreviousOnboardingStep(AppRoutes.healthProblem);
  }

  Future<void> _continue() async {
    if (!_noneSelected && _selectedCategories.isEmpty) {
      _showValidationMessage(
        'Select a category',
        'Please choose one or more health concerns, or tap "I don\'t have any of these" below.',
      );
      return;
    }

    if (_noneSelected) {
      await _saveAndFinish([HealthConcern.none()]);
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
      if (!patch.isEmpty) {
        final error = await _user.patchOnboarding(patch);
        if (!mounted) return;
        if (error != null) {
          AppSnackbar.error(error, title: 'Save failed');
          return;
        }
        _baseline = _user.captureProfileSyncSnapshot();
      }

      Get.back();
      AppSnackbar.success(
        patch.isEmpty ? 'Health concerns saved.' : 'Health concerns updated.',
      );
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

  void _toggleNone() {
    FocusScope.of(context).unfocus();
    setState(() {
      _noneSelected = !_noneSelected;
      if (_noneSelected) {
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
    setState(() {
      _noneSelected = false;
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
    final hasHealthConcerns = _selectedCategories.isNotEmpty && !_noneSelected;
    final sortedCategories = _selectedCategories.toList()..sort();

    return PopScope(
      canPop: _fromProfile,
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
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: r.scale(compact ? 8 : 14)),
                _HeroSection(r: r, compact: compact),
                SizedBox(height: r.scale(compact ? 18 : 24)),
                _SectionTitle(text: 'Select Your Problem Categories', r: r),
                SizedBox(height: r.scale(6)),
                Text(
                  'Tap to select multiple concerns. Tap again to deselect.',
                  style: TextStyle(
                    fontSize: r.scale(13, tablet: 14),
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                if (hasHealthConcerns) ...[
                  SizedBox(height: r.scale(6)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _CountBadge(count: _selectedCategories.length),
                  ),
                ],
                SizedBox(height: r.scale(8)),
                _CategoryGrid(
                  categories: _categories,
                  selectedCategories: _selectedCategories,
                  onChanged: _toggleCategory,
                ),
                if (!_noneSelected && _selectedCategories.isEmpty) ...[
                  SizedBox(height: r.scale(compact ? 14 : 18)),
                  const _GuidanceCard(
                    iconAsset: 'assets/image/point.svg',
                    title: 'Choose what applies to you',
                    message:
                        'Select one or more health concerns and fill in details for each, or choose the option below if none apply.',
                  ),
                ],
                SizedBox(height: r.scale(12)),
                _OrDivider(),
                SizedBox(height: r.scale(10)),
                _NoneOption(selected: _noneSelected, onTap: _toggleNone),
                SizedBox(height: r.scale(compact ? 18 : 22)),
                if (hasHealthConcerns) ...[
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
            action: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _continue,
                    child: Text(_fromProfile ? 'Save' : 'Continue'),
                  ),
                ),
                SizedBox(height: r.scale(12)),
                const _SettingsNote(),
              ],
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
    this.shortLabel,
  });

  final String label;
  final String? shortLabel;
  final String asset;

  String get gridLabel => shortLabel ?? label;
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

abstract final class _CategoryTile {
  static BoxDecoration decoration({required bool selected}) {
    return BoxDecoration(
      color: selected ? AppColors.selectionFill : AppColors.card,
      borderRadius: BorderRadius.circular(12),
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Row(
      children: [
        Expanded(child: Divider(height: 1, color: AppColors.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.scale(12)),
          child: Text(
            'Or',
            style: TextStyle(
              fontSize: r.scale(12, tablet: 13),
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
        ),
        Expanded(child: Divider(height: 1, color: AppColors.border)),
      ],
    );
  }
}

class _NoneOption extends StatelessWidget {
  const _NoneOption({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final iconSize = r.scale(42, tablet: 46);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          constraints: BoxConstraints(minHeight: r.scale(64, tablet: 68)),
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(16),
            vertical: r.scale(14, tablet: 16),
          ),
          decoration: _CategoryTile.decoration(selected: selected),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: iconSize,
                height: iconSize,
                child: Transform.scale(
                  scale: 0.8,
                  child: Image.asset(
                    'assets/image/no-entry.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              SizedBox(width: r.scale(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'I don\'t have any of these',
                      style: TextStyle(
                        fontSize: r.scale(15, tablet: 16),
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: r.scale(2)),
                    Text(
                      'Skip health concern details',
                      style: TextStyle(
                        fontSize: r.scale(12, tablet: 13),
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: r.scale(8)),
              _SelectionIndicator(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.r, required this.compact});

  final Responsive r;
  final bool compact;

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
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: r.scale(compact ? 25 : 28, tablet: 31),
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.16,
                      letterSpacing: -0.5,
                    ),
                    children: const [
                      TextSpan(text: 'Enter your\n'),
                      TextSpan(
                        text: 'health concern',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r.scale(compact ? 6 : 8)),
                Text(
                  'Select all concerns that apply. You\'ll add separate details for each one.',
                  style: TextStyle(
                    fontSize: r.scale(compact ? 13 : 14, tablet: 15),
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: r.scale(12)),
          SizedBox(
            width: r.scale(compact ? 142 : 164, tablet: 190),
            height: r.scale(compact ? 142 : 164, tablet: 190),
            child: const _MedicalHeroIllustration(),
          ),
        ],
      ),
    );
  }
}

class _MedicalHeroIllustration extends StatelessWidget {
  const _MedicalHeroIllustration();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _HealthProblemViewState._heroAsset,
      fit: BoxFit.contain,
      alignment: Alignment.center,
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
    final crossAxisCount = r.width < 600 ? 4 : 5;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: r.scale(7),
        crossAxisSpacing: r.scale(7),
        childAspectRatio: r.isTablet ? 0.76 : 0.74,
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(6),
            vertical: r.scale(8),
          ),
          decoration: _CategoryTile.decoration(selected: selected),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: r.scale(38, tablet: 40),
                    height: r.scale(38, tablet: 40),
                    child: Center(
                      child: SvgPicture.asset(
                        category.asset,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                  SizedBox(height: r.scale(6)),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      category.gridLabel,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r.scale(10, tablet: 11),
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        height: 1.12,
                      ),
                    ),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: r.scale(4),
                  right: r.scale(4),
                  child: Container(
                    width: r.scale(16),
                    height: r.scale(16),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: r.scale(11),
                      color: AppColors.onPrimary,
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

class _SettingsNote extends StatelessWidget {
  const _SettingsNote();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: r.scale(14),
          color: AppColors.primary,
        ),
        SizedBox(width: r.scale(6)),
        Flexible(
          child: Text(
            'You can change this anytime in settings',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.scale(12, tablet: 13),
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
