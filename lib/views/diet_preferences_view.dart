import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../models/diet_type.dart';
import '../models/onboarding_request_model.dart';
import '../models/profile_sync_snapshot.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/onboarding_entrance.dart';
import '../widgets/onboarding_step_scaffold.dart';

enum _DietStep { dietType, allergies, avoid, meals }

class DietPreferencesView extends StatefulWidget {
  const DietPreferencesView({super.key});

  @override
  State<DietPreferencesView> createState() => _DietPreferencesViewState();
}

class _DietPreferencesViewState extends State<DietPreferencesView> {
  late final UserController _user = Get.find<UserController>();
  late final ProfileSyncSnapshot _baseline;
  late final TextEditingController _avoidController;
  late final TextEditingController _otherAllergyController;
  late final FocusNode _otherAllergyFocus;
  final _allergyScrollController = ScrollController();
  final _otherAllergyFieldKey = GlobalKey();

  _DietStep _step = _DietStep.dietType;
  DietType? _dietType;
  final Set<String> _allergies = {};
  int? _mealsPerDay;
  bool _saving = false;
  bool _transitioning = false;
  bool _dietDropdownOpen = false;

  bool get _fromProfile => RouteArgs.isEditingFromProfile;

  int get _progressIndex => switch (_step) {
        _DietStep.dietType => OnboardingFlowProgress.dietType,
        _DietStep.allergies => OnboardingFlowProgress.foodAllergies,
        _DietStep.avoid => OnboardingFlowProgress.foodsToAvoid,
        _DietStep.meals => OnboardingFlowProgress.mealsPerDay,
      };

  String get _title => switch (_step) {
        _DietStep.dietType => 'What type of diet do you follow?',
        _DietStep.allergies => 'Any food allergies?',
        _DietStep.avoid => 'Anything you don’t eat?',
        _DietStep.meals => 'How many meals do you prefer?',
      };

  String get _subtitle => switch (_step) {
        _DietStep.dietType =>
          'This helps us tailor your meal plan to suit dietary preferences.',
        _DietStep.allergies =>
          'Select all that apply. This helps us keep your meals safe and healthy.',
        _DietStep.avoid =>
          'Let us know if there are any foods you prefer to avoid.',
        _DietStep.meals =>
          'This helps us plan the right calorie intake and protein size for you.',
      };

  String get _continueLabel {
    if (_saving) return 'Saving...';
    if (_step == _DietStep.meals) {
      return _fromProfile ? 'Save' : 'Continue';
    }
    return 'Continue';
  }

  bool get _showOtherAllergyField =>
      _allergies.contains(FoodAllergyOptions.other);

  @override
  void initState() {
    super.initState();
    _baseline = _user.captureProfileSyncSnapshot();
    final profile = _user.user;
    _dietType = profile.dietType;
    _mealsPerDay = profile.mealsPerDay;
    _avoidController = TextEditingController(text: profile.foodsToAvoid);
    _otherAllergyController = TextEditingController();
    _otherAllergyFocus = FocusNode();

    final saved = profile.foodAllergies;
    if (saved.isEmpty) return;

    if (saved.every((item) {
      final n = FoodAllergyOptions.normalize(item);
      return n == null || n == FoodAllergyOptions.none;
    })) {
      _allergies.add(FoodAllergyOptions.none);
      return;
    }

    final customOther = <String>[];
    for (final item in saved) {
      final normalized = FoodAllergyOptions.normalize(item);
      if (normalized == null || normalized == FoodAllergyOptions.none) {
        continue;
      }
      if (normalized == FoodAllergyOptions.other) {
        final knownLabels = {
          for (final chip in FoodAllergyOptions.chips)
            chip.toLowerCase(),
        };
        if (!knownLabels.contains(item.trim().toLowerCase())) {
          customOther.add(item.trim());
        }
        _allergies.add(FoodAllergyOptions.other);
      } else {
        _allergies.add(normalized);
      }
    }

    if (_allergies.isEmpty) {
      _allergies.add(FoodAllergyOptions.none);
    } else if (customOther.isNotEmpty) {
      _otherAllergyController.text = customOther.join(', ');
    }
  }

  @override
  void dispose() {
    _avoidController.dispose();
    _otherAllergyController.dispose();
    _otherAllergyFocus.dispose();
    _allergyScrollController.dispose();
    super.dispose();
  }

  List<String> get _allergiesToSave {
    if (_allergies.contains(FoodAllergyOptions.none) || _allergies.isEmpty) {
      return [FoodAllergyOptions.none];
    }
    final result = <String>[];
    for (final item in _allergies) {
      if (item == FoodAllergyOptions.other) {
        final custom = _otherAllergyController.text.trim();
        if (custom.isNotEmpty) result.add(custom);
      } else if (item != FoodAllergyOptions.none) {
        result.add(item);
      }
    }
    return result.isEmpty ? [FoodAllergyOptions.none] : result;
  }

  void _persistDraft() {
    if (_fromProfile) return;
    unawaited(
      _user.saveDietPreferences(
        dietType: _dietType,
        foodAllergies: _allergiesToSave,
        foodsToAvoid: _avoidController.text,
        mealsPerDay: _mealsPerDay,
      ),
    );
  }

  Future<void> _animateTo(_DietStep next, {required bool forward}) async {
    if (_transitioning || next == _step) return;
    setState(() {
      _transitioning = true;
      _dietDropdownOpen = false;
      _step = next;
    });
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    setState(() => _transitioning = false);
  }

  Future<void> _onBack() async {
    if (_saving || _transitioning) return;
    if (_step != _DietStep.dietType) {
      final previous = _DietStep.values[_step.index - 1];
      await _animateTo(previous, forward: false);
      return;
    }
    if (_fromProfile) {
      Get.back<void>();
      return;
    }
    _persistDraft();
    await _user.goToPreviousOnboardingStep(AppRoutes.dietPreferences);
  }

  void _selectDiet(DietType type) {
    HapticFeedback.selectionClick();
    setState(() {
      _dietType = type;
      _dietDropdownOpen = false;
    });
    _persistDraft();
  }

  void _toggleDietDropdown() {
    HapticFeedback.selectionClick();
    setState(() => _dietDropdownOpen = !_dietDropdownOpen);
  }

  void _toggleAllergy(String allergy) {
    HapticFeedback.selectionClick();
    final openingOther = allergy == FoodAllergyOptions.other &&
        !_allergies.contains(FoodAllergyOptions.other);
    setState(() {
      if (allergy == FoodAllergyOptions.none) {
        _allergies
          ..clear()
          ..add(FoodAllergyOptions.none);
        _otherAllergyController.clear();
        _otherAllergyFocus.unfocus();
      } else {
        _allergies.remove(FoodAllergyOptions.none);
        if (!_allergies.remove(allergy)) {
          _allergies.add(allergy);
        }
        if (!_allergies.contains(FoodAllergyOptions.other)) {
          _otherAllergyController.clear();
          _otherAllergyFocus.unfocus();
        }
      }
    });
    _persistDraft();
    if (openingOther) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _otherAllergyFocus.requestFocus();
        _ensureOtherAllergyVisible();
        Future<void>.delayed(const Duration(milliseconds: 280), () {
          if (mounted) _ensureOtherAllergyVisible();
        });
      });
    }
  }

  void _ensureOtherAllergyVisible() {
    final ctx = _otherAllergyFieldKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.2,
    );
  }

  void _selectMeals(int count) {
    HapticFeedback.selectionClick();
    setState(() => _mealsPerDay = count);
    _persistDraft();
  }

  Future<void> _skipAvoidFoods() async {
    if (_saving || _transitioning || _step != _DietStep.avoid) return;
    _avoidController.clear();
    _persistDraft();
    await _animateTo(_DietStep.meals, forward: true);
  }

  Future<void> _continue() async {
    if (_saving || _transitioning) return;

    switch (_step) {
      case _DietStep.dietType:
        if (_dietType == null) {
          AppSnackbar.error('Select the type of diet you follow.');
          return;
        }
        await _animateTo(_DietStep.allergies, forward: true);
        return;
      case _DietStep.allergies:
        if (_allergies.isEmpty) {
          AppSnackbar.error('Select at least one option.');
          return;
        }
        if (_showOtherAllergyField &&
            _otherAllergyController.text.trim().isEmpty) {
          AppSnackbar.error('Please enter your other allergies.');
          return;
        }
        await _animateTo(_DietStep.avoid, forward: true);
        return;
      case _DietStep.avoid:
        _persistDraft();
        await _animateTo(_DietStep.meals, forward: true);
        return;
      case _DietStep.meals:
        break;
    }

    if (_mealsPerDay == null) {
      AppSnackbar.error('Select how many meals you prefer per day.');
      return;
    }

    await _finish();
  }

  Future<void> _finish() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    await _user.saveDietPreferences(
      dietType: _dietType,
      foodAllergies: _allergiesToSave,
      foodsToAvoid: _avoidController.text,
      mealsPerDay: _mealsPerDay,
    );
    if (!mounted) return;

    if (_fromProfile) {
      final patch = OnboardingPatchModel.dietPreferencesDiff(
        _user.user,
        _baseline,
      );
      if (patch.isEmpty) {
        AppSnackbar.info('No changes to save.', title: 'Nothing changed');
        Get.back();
        return;
      }

      setState(() => _saving = true);
      try {
        final error = await _user.patchOnboarding(patch);
        if (!mounted) return;
        if (error != null) {
          AppSnackbar.error(error, title: 'Save failed');
          return;
        }
        Get.back();
        AppSnackbar.success('Diet preferences updated.');
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }

    await _user.persistOnboardingStep(AppRoutes.nutritionPlanLoading);
    Get.offNamed(AppRoutes.nutritionPlanLoading);
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final pageBg = AppColors.backgroundOf(context);

    return PopScope(
      canPop: _fromProfile && _step == _DietStep.dietType,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_onBack());
      },
      child: Scaffold(
        backgroundColor: pageBg,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: r.scale(20, tablet: 28),
              right: r.scale(20, tablet: 28),
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              children: [
                SizedBox(height: r.scale(4)),
                OnboardingStepTopBar(
                  stepIndex: _fromProfile ? _step.index : _progressIndex,
                  totalSteps: _fromProfile
                      ? _DietStep.values.length
                      : OnboardingFlowProgress.totalSteps,
                  showProgress: true,
                  onBack: () => unawaited(_onBack()),
                ),
                SizedBox(height: r.scale(20)),
                Expanded(
                  child: OnboardingEntrance(
                    replayToken: _step,
                    builder: (context, entrance) {
                      return Column(
                        children: [
                          entrance.item(
                            index: 0,
                            child: Text(
                              _title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: r.scale(26, tablet: 30),
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimaryOf(context),
                                height: 1.15,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                          SizedBox(height: r.scale(8)),
                          entrance.item(
                            index: 1,
                            child: Text(
                              _subtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: r.scale(14, tablet: 15),
                                color: AppColors.textSecondaryOf(context),
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(height: r.scale(20)),
                          Expanded(
                            child: entrance.item(
                              index: 2,
                              child: _buildStepBody(context),
                            ),
                          ),
                          entrance.item(
                            index: 3,
                            child: _step == _DietStep.avoid
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: r.scale(54, tablet: 58),
                                          child: OutlinedButton(
                                            onPressed:
                                                !_saving && !_transitioning
                                                    ? () => unawaited(
                                                          _skipAvoidFoods(),
                                                        )
                                                    : null,
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  AppColors.primary,
                                              side: BorderSide(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.7),
                                                width: 1.6,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(28),
                                              ),
                                            ),
                                            child: Text(
                                              'Skip',
                                              style: TextStyle(
                                                fontSize:
                                                    r.scale(16, tablet: 17),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: r.scale(12)),
                                      Expanded(
                                        child: OnboardingContinueButton(
                                          label: _continueLabel,
                                          onPressed:
                                              !_saving && !_transitioning
                                                  ? () => unawaited(
                                                        _continue(),
                                                      )
                                                  : null,
                                        ),
                                      ),
                                    ],
                                  )
                                : OnboardingContinueButton(
                                    label: _continueLabel,
                                    onPressed: !_saving && !_transitioning
                                        ? () => unawaited(_continue())
                                        : null,
                                  ),
                          ),
                          if (!_fromProfile &&
                              _step == _DietStep.meals) ...[
                            SizedBox(height: r.scale(10)),
                            Text(
                              'You can change this anytime in your profile',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: r.scale(12, tablet: 13),
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ],
                          SizedBox(height: r.scale(12)),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepBody(BuildContext context) {
    final r = context.responsive;
    return switch (_step) {
      _DietStep.dietType => Column(
          children: [
            _DietDropdownHeader(
              value: _dietType,
              open: _dietDropdownOpen,
              onToggle: _toggleDietDropdown,
            ),
            SizedBox(height: r.scale(12)),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                // Avoid stacking fading children — that creates a grey mush.
                layoutBuilder: (currentChild, previousChildren) {
                  return currentChild ?? const SizedBox.shrink();
                },
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: _dietDropdownOpen
                    ? _DietDropdownList(
                        key: const ValueKey('diet-list'),
                        value: _dietType,
                        onSelect: _selectDiet,
                      )
                    : const _DietHeroImage(
                        key: ValueKey('diet-hero'),
                        asset: 'assets/image/diet_follow.png',
                        expand: true,
                      ),
              ),
            ),
          ],
        ),
      _DietStep.allergies => ListView(
          controller: _allergyScrollController,
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(bottom: r.scale(16)),
          children: [
            _AllergyChipGrid(
              chips: FoodAllergyOptions.chips,
              selected: _allergies,
              onToggle: _toggleAllergy,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _showOtherAllergyField
                  ? Padding(
                      key: _otherAllergyFieldKey,
                      padding: EdgeInsets.only(top: r.scale(14)),
                      child: TextField(
                        controller: _otherAllergyController,
                        focusNode: _otherAllergyFocus,
                        onChanged: (_) => _persistDraft(),
                        onTap: _ensureOtherAllergyVisible,
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        style: TextStyle(
                          fontSize: r.scale(14, tablet: 15),
                          color: AppColors.textPrimaryOf(context),
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.cardOf(context),
                          hintText: 'Enter allergies',
                          hintStyle: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                            fontSize: r.scale(14, tablet: 15),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: r.scale(16),
                            vertical: r.scale(16),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.borderOf(context),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.borderOf(context),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 1.6,
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      _DietStep.avoid => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _avoidController,
              onChanged: (_) => _persistDraft(),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              minLines: 3,
              maxLines: 5,
              maxLength: 300,
              textInputAction: TextInputAction.done,
              style: TextStyle(
                fontSize: r.scale(14, tablet: 15),
                color: AppColors.textPrimaryOf(context),
                height: 1.35,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.cardOf(context),
                hintText: 'eg. mushrooms, spinach, spicy food...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: r.scale(13, tablet: 14),
                ),
                counterStyle: TextStyle(
                  color: AppColors.textSecondaryOf(context),
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
                  borderSide: BorderSide(
                    color: AppColors.primary,
                    width: 1.6,
                  ),
                ),
              ),
            ),
            SizedBox(height: r.scale(8)),
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: const _DietHeroImage(
                  asset: 'assets/image/eat_plate.png',
                  expand: true,
                ),
              ),
            ),
          ],
        ),
      _DietStep.meals => ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            for (final count in MealsPerDayOptions.values) ...[
              OnboardingOptionCard(
                title: '$count Meals',
                selected: _mealsPerDay == count,
                onTap: () => _selectMeals(count),
              ),
              SizedBox(height: r.scale(12)),
            ],
          ],
        ),
    };
  }
}

class _DietDropdownHeader extends StatelessWidget {
  const _DietDropdownHeader({
    required this.value,
    required this.open,
    required this.onToggle,
  });

  final DietType? value;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final selected = value != null;
    final mintFill = AppColors.primary.withValues(alpha: 0.12);
    final borderColor =
        selected || open ? AppColors.primary : AppColors.borderOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(16),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          height: r.scale(56),
          padding: EdgeInsets.symmetric(horizontal: r.scale(16)),
          decoration: BoxDecoration(
            color: selected ? mintFill : AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: selected || open ? 1.6 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selected
                      ? '${value!.emoji}  ${value!.title}'
                      : 'Select diet type',
                  style: TextStyle(
                    fontSize: r.scale(15, tablet: 16),
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppColors.textPrimaryOf(context)
                        : AppColors.textSecondaryOf(context),
                  ),
                ),
              ),
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: selected || open
                      ? AppColors.primary
                      : AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DietDropdownList extends StatelessWidget {
  const _DietDropdownList({
    super.key,
    required this.value,
    required this.onSelect,
  });

  final DietType? value;
  final ValueChanged<DietType> onSelect;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final mintFill = AppColors.primary.withValues(alpha: 0.12);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderOf(context),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          padding: EdgeInsets.symmetric(vertical: r.scale(6)),
          itemCount: DietType.values.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            indent: r.scale(16),
            endIndent: r.scale(16),
            color: AppColors.borderOf(context).withValues(alpha: 0.7),
          ),
          itemBuilder: (context, index) {
            final diet = DietType.values[index];
            final isSelected = value == diet;
            return Material(
              color: isSelected ? mintFill : Colors.transparent,
              child: InkWell(
                onTap: () => onSelect(diet),
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStatePropertyAll(
                  AppColors.primary.withValues(alpha: 0.06),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.scale(16),
                    vertical: r.scale(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${diet.emoji}  ${diet.title}',
                              style: TextStyle(
                                fontSize: r.scale(15, tablet: 16),
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                            SizedBox(height: r.scale(2)),
                            Text(
                              diet.description,
                              style: TextStyle(
                                fontSize: r.scale(12, tablet: 13),
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondaryOf(context),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected) ...[
                        SizedBox(width: r.scale(8)),
                        Icon(
                          Icons.check_rounded,
                          size: r.scale(18),
                          color: AppColors.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DietHeroImage extends StatelessWidget {
  const _DietHeroImage({
    super.key,
    required this.asset,
    this.expand = false,
  });

  final String asset;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final image = Image.asset(
      asset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    if (expand) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: r.scale(280, tablet: 340),
            maxWidth: r.scale(320, tablet: 380),
          ),
          child: image,
        ),
      );
    }

    return Center(
      child: SizedBox(
        height: r.scale(200, tablet: 240),
        child: image,
      ),
    );
  }
}

class _AllergyChipGrid extends StatelessWidget {
  const _AllergyChipGrid({
    required this.chips,
    required this.selected,
    required this.onToggle,
  });

  final List<String> chips;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final rows = <List<String>>[];
    for (var i = 0; i < chips.length; i += 2) {
      rows.add(
        chips.sublist(i, i + 2 > chips.length ? chips.length : i + 2),
      );
    }

    return Column(
      children: [
        for (final row in rows) ...[
          Row(
            children: [
              for (var i = 0; i < row.length; i++) ...[
                if (i > 0) SizedBox(width: r.scale(12)),
                Expanded(
                  child: _AllergyChip(
                    label: row[i],
                    selected: selected.contains(row[i]),
                    onTap: () => onToggle(row[i]),
                  ),
                ),
              ],
              if (row.length == 1) ...[
                SizedBox(width: r.scale(12)),
                const Expanded(child: SizedBox.shrink()),
              ],
            ],
          ),
          SizedBox(height: r.scale(12)),
        ],
      ],
    );
  }
}

class _AllergyChip extends StatelessWidget {
  const _AllergyChip({
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
    final mintFill = AppColors.primary.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: r.scale(16)),
          decoration: BoxDecoration(
            color: selected ? mintFill : AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderOf(context),
              width: selected ? 1.6 : 1.2,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.scale(15, tablet: 16),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
        ),
      ),
    );
  }
}
