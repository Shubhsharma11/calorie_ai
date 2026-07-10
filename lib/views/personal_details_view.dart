import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/body_measurement_units.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../models/onboarding_request_model.dart';
import '../models/profile_sync_snapshot.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_page.dart';

class PersonalDetailsView extends StatefulWidget {
  const PersonalDetailsView({super.key});

  @override
  State<PersonalDetailsView> createState() => _PersonalDetailsViewState();
}

class _PersonalDetailsViewState extends State<PersonalDetailsView> {
  late final UserController _user = Get.find<UserController>();
  late final TextEditingController _ageCtrl;
  late final TextEditingController _heightCmCtrl;
  late final TextEditingController _heightFeetCtrl;
  late final TextEditingController _heightInchesCtrl;
  late final TextEditingController _weightCtrl;
  late String _gender;
  late ProfileSyncSnapshot _baseline;

  bool _heightUseCm = true;
  bool _weightUseKg = true;

  String? _ageError;
  String? _genderError;
  String? _heightError;
  String? _weightError;

  static const _genders = ['Male', 'Female'];
  static const _ageIconAsset = 'assets/image/age.svg';
  static const _genderIconAsset = 'assets/image/gemder.svg';
  static const _heightIconAsset = 'assets/image/height.svg';
  static const _weightIconAsset = 'assets/image/weight2.2.svg';

  @override
  void initState() {
    super.initState();
    final fromProfile = RouteArgs.isEditingFromProfile;
    final u = _user.user;

    if (fromProfile) {
      _gender = u.gender;
      _ageCtrl = TextEditingController(text: '${u.age}');
      _heightCmCtrl = TextEditingController(text: '${u.heightCm}');
      final feetInches = BodyMeasurementUnits.feetInchesFromCm(u.heightCm);
      _heightFeetCtrl = TextEditingController(text: '${feetInches.feet}');
      _heightInchesCtrl = TextEditingController(text: '${feetInches.inches}');
      _weightCtrl = TextEditingController(text: '${u.weightKg}');
    } else {
      _gender = '';
      _ageCtrl = TextEditingController();
      _heightCmCtrl = TextEditingController();
      _heightFeetCtrl = TextEditingController();
      _heightInchesCtrl = TextEditingController();
      _weightCtrl = TextEditingController();
    }

    _ageCtrl.addListener(_clearAgeError);
    _heightCmCtrl.addListener(_clearHeightError);
    _heightFeetCtrl.addListener(_clearHeightError);
    _heightInchesCtrl.addListener(_clearHeightError);
    _weightCtrl.addListener(_clearWeightError);

    _baseline = _user.captureProfileSyncSnapshot();
  }

  void _clearAgeError() {
    if (_ageError != null) setState(() => _ageError = null);
  }

  void _clearHeightError() {
    if (_heightError != null) setState(() => _heightError = null);
  }

  void _clearWeightError() {
    if (_weightError != null) setState(() => _weightError = null);
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCmCtrl.dispose();
    _heightFeetCtrl.dispose();
    _heightInchesCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _toggleHeightUnit(bool useCm) {
    if (useCm == _heightUseCm) return;

    if (useCm) {
      final feet = int.tryParse(_heightFeetCtrl.text.trim());
      final inches = int.tryParse(_heightInchesCtrl.text.trim());
      if (feet != null &&
          inches != null &&
          _heightFeetCtrl.text.trim().isNotEmpty &&
          _heightInchesCtrl.text.trim().isNotEmpty) {
        _heightCmCtrl.text =
            '${BodyMeasurementUnits.cmFromFeetInches(feet, inches)}';
      } else {
        _heightCmCtrl.clear();
      }
    } else {
      final cm = int.tryParse(_heightCmCtrl.text.trim());
      if (cm != null && _heightCmCtrl.text.trim().isNotEmpty) {
        final converted = BodyMeasurementUnits.feetInchesFromCm(cm);
        _heightFeetCtrl.text = '${converted.feet}';
        _heightInchesCtrl.text = '${converted.inches}';
      } else {
        _heightFeetCtrl.clear();
        _heightInchesCtrl.clear();
      }
    }

    setState(() {
      _heightUseCm = useCm;
      _heightError = null;
    });
  }

  void _toggleWeightUnit(bool useKg) {
    if (useKg == _weightUseKg) return;

    final text = _weightCtrl.text.trim();
    if (text.isNotEmpty) {
      final parsed = int.tryParse(text);
      if (parsed != null) {
        _weightCtrl.text = useKg
            ? '${BodyMeasurementUnits.kgFromLbs(parsed.toDouble())}'
            : '${BodyMeasurementUnits.lbsFromKg(parsed)}';
      }
    }

    setState(() {
      _weightUseKg = useKg;
      _weightError = null;
    });
  }

  int? _parseHeightCm() {
    if (_heightUseCm) {
      return int.tryParse(_heightCmCtrl.text.trim());
    }

    final feet = int.tryParse(_heightFeetCtrl.text.trim());
    final inches = int.tryParse(_heightInchesCtrl.text.trim());
    if (feet == null || inches == null) return null;
    return BodyMeasurementUnits.cmFromFeetInches(feet, inches);
  }

  int? _parseWeightKg() {
    final parsed = int.tryParse(_weightCtrl.text.trim());
    if (parsed == null) return null;
    return _weightUseKg
        ? parsed
        : BodyMeasurementUnits.kgFromLbs(parsed.toDouble());
  }

  bool _validateFields() {
    final ageText = _ageCtrl.text.trim();

    String? ageError;
    String? genderError;
    String? heightError;
    String? weightError;

    if (ageText.isEmpty) {
      ageError = 'Enter your age';
    } else {
      final age = int.tryParse(ageText);
      if (age == null || age < 1 || age > 100) {
        ageError = 'Use an age between 1 and 100';
      }
    }

    if (_gender.isEmpty) {
      genderError = 'Select your gender';
    }

    if (_heightUseCm) {
      final heightText = _heightCmCtrl.text.trim();
      if (heightText.isEmpty) {
        heightError = 'Enter your height';
      } else {
        final height = int.tryParse(heightText);
        if (height == null || !BodyMeasurementUnits.isValidCm(height)) {
          heightError = 'Use a height between 100 and 250 cm';
        }
      }
    } else {
      final feetText = _heightFeetCtrl.text.trim();
      final inchesText = _heightInchesCtrl.text.trim();
      if (feetText.isEmpty || inchesText.isEmpty) {
        heightError = 'Enter your height in feet and inches';
      } else {
        final feet = int.tryParse(feetText);
        final inches = int.tryParse(inchesText);
        if (feet == null ||
            inches == null ||
            !BodyMeasurementUnits.isValidFeetInches(feet, inches)) {
          heightError = 'Use a valid height (e.g. 5 ft 7 in)';
        }
      }
    }

    final weightText = _weightCtrl.text.trim();
    if (weightText.isEmpty) {
      weightError = 'Enter your weight';
    } else {
      final weight = int.tryParse(weightText);
      if (weight == null) {
        weightError = _weightUseKg
            ? 'Use a weight between 30 and 300 kg'
            : 'Use a weight between 66 and 661 lbs';
      } else if (_weightUseKg) {
        if (!BodyMeasurementUnits.isValidKg(weight)) {
          weightError = 'Use a weight between 30 and 300 kg';
        }
      } else if (!BodyMeasurementUnits.isValidLbs(weight)) {
        weightError = 'Use a weight between 66 and 661 lbs';
      }
    }

    setState(() {
      _ageError = ageError;
      _genderError = genderError;
      _heightError = heightError;
      _weightError = weightError;
    });

    return ageError == null &&
        genderError == null &&
        heightError == null &&
        weightError == null;
  }

  Future<void> _save() async {
    if (!_validateFields()) return;

    final age = int.parse(_ageCtrl.text.trim());
    final height = _parseHeightCm()!;
    final weight = _parseWeightKg()!;

    final u = _user.user;
    u.age = age;
    u.gender = _gender;
    u.heightCm = height;
    u.weightKg = weight;

    if (RouteArgs.isEditingFromProfile) {
      final patch = OnboardingPatchModel.personalDetailsDiff(u, _baseline);
      if (patch.isEmpty) {
        AppSnackbar.info('No changes to save.', title: 'Nothing changed');
        return;
      }

      final error = await _user.patchOnboarding(patch);
      if (!mounted) return;
      if (error != null) {
        AppSnackbar.error(error);
        return;
      }

      _baseline = _user.captureProfileSyncSnapshot();
      _user.onProfileUpdated();
      _user.syncWeightFromProfile();
      Get.back();
      AppSnackbar.success('Personal details updated.');
    } else {
      _user.onProfileUpdated();
      _user.syncWeightFromProfile();
      Get.toNamed(AppRoutes.goalSetup);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final fromProfile = RouteArgs.isEditingFromProfile;
    final compact = r.height < 720;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SetupScreenLayout(
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: r.scale(60, tablet: 68)),
            _HeroSection(r: r, compact: compact),
            SizedBox(height: r.scale(20)),
            _DetailCard(
              iconWidget: SvgPicture.asset(_ageIconAsset, fit: BoxFit.contain),
              label: 'Age',
              subtitle: 'Enter your age',
              errorText: _ageError,
              child: _NumberInput(
                controller: _ageCtrl,
                unit: 'years',
                maxLength: 3,
                hasError: _ageError != null,
              ),
            ),
            SizedBox(height: r.scale(12)),
            _DetailCard(
              iconWidget: SvgPicture.asset(
                _genderIconAsset,
                fit: BoxFit.contain,
              ),
              label: 'Gender',
              subtitle: 'Select your gender',
              errorText: _genderError,
              child: _GenderToggle(
                value: _gender,
                options: _genders,
                hasError: _genderError != null,
                onChanged: (g) => setState(() {
                  _gender = g;
                  _genderError = null;
                }),
              ),
            ),
            SizedBox(height: r.scale(12)),
            _DetailCard(
              iconWidget: SvgPicture.asset(
                _heightIconAsset,
                fit: BoxFit.contain,
              ),
              label: 'Height',
              subtitle: 'Enter your height',
              errorText: _heightError,
              child: _HeightInput(
                useCm: _heightUseCm,
                cmController: _heightCmCtrl,
                feetController: _heightFeetCtrl,
                inchesController: _heightInchesCtrl,
                hasError: _heightError != null,
                onUnitTap: () => _toggleHeightUnit(!_heightUseCm),
              ),
            ),
            SizedBox(height: r.scale(12)),
            _DetailCard(
              iconWidget: SvgPicture.asset(
                _weightIconAsset,
                fit: BoxFit.contain,
              ),
              label: 'Weight',
              subtitle: 'Enter your current weight',
              errorText: _weightError,
              child: _NumberInput(
                controller: _weightCtrl,
                unit: _weightUseKg ? 'kg' : 'lbs',
                maxLength: 3,
                hasError: _weightError != null,
                onUnitTap: () => _toggleWeightUnit(!_weightUseKg),
              ),
            ),
          ],
        ),
        action: PrimaryButton(
          label: fromProfile ? 'Save' : 'Continue',
          onPressed: _save,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: r.scale(compact ? 26 : 28, tablet: 30),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                  children: const [
                    TextSpan(text: 'Tell us about '),
                    TextSpan(
                      text: 'yourself',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.scale(compact ? 6 : 8)),
              Text(
                'This helps us personalize your calorie goal and recommendations.',
                style: TextStyle(
                  fontSize: r.scale(compact ? 13 : 14, tablet: 15),
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: r.scale(8)),
        const _HeroIllustration(),
      ],
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final size = r.scale(88, tablet: 96);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 8,
            right: 0,
            child: Icon(
              Icons.eco_rounded,
              size: r.scale(24),
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
          Positioned(
            top: 28,
            left: 4,
            child: Icon(
              Icons.spa_rounded,
              size: r.scale(18),
              color: AppColors.primary.withValues(alpha: 0.45),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 10,
            child: Container(
              width: r.scale(48),
              height: r.scale(48),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.25),
                    AppColors.primary.withValues(alpha: 0.55),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.person_rounded,
                size: r.scale(30),
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.subtitle,
    required this.child,
    this.errorText,
  }) : assert(icon != null || iconWidget != null);

  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final String subtitle;
  final Widget child;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final hasError = errorText != null;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(14),
        vertical: r.scale(14),
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? AppColors.error.withValues(alpha: 0.45)
              : AppColors.border.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: r.scale(2)),
            child: iconWidget != null
                ? SizedBox(width: 40, height: 40, child: iconWidget)
                : Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 20, color: AppColors.primary),
                  ),
          ),
          SizedBox(width: r.scale(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: r.scale(14, tablet: 15),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasError ? errorText! : subtitle,
                  style: TextStyle(
                    fontSize: r.scale(11, tablet: 12),
                    color: hasError ? AppColors.error : AppColors.textSecondary,
                    height: 1.3,
                    fontWeight: hasError ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: r.scale(8)),
          Padding(
            padding: EdgeInsets.only(top: r.scale(2)),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _HeightInput extends StatelessWidget {
  const _HeightInput({
    required this.useCm,
    required this.cmController,
    required this.feetController,
    required this.inchesController,
    required this.hasError,
    required this.onUnitTap,
  });

  final bool useCm;
  final TextEditingController cmController;
  final TextEditingController feetController;
  final TextEditingController inchesController;
  final bool hasError;
  final VoidCallback onUnitTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    if (useCm) {
      return _NumberInput(
        controller: cmController,
        unit: 'cm',
        maxLength: 3,
        hasError: hasError,
        onUnitTap: onUnitTap,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _NumberInput(
          controller: feetController,
          maxLength: 1,
          hasError: hasError,
          showUnitLabel: false,
          width: r.scale(40),
        ),
        SizedBox(width: r.scale(4)),
        _NumberInput(
          controller: inchesController,
          maxLength: 2,
          hasError: hasError,
          showUnitLabel: false,
          width: r.scale(46),
        ),
        const SizedBox(width: 6),
        _UnitLabel(
          label: 'ft/in',
          onTap: onUnitTap,
        ),
      ],
    );
  }
}

class _UnitLabel extends StatelessWidget {
  const _UnitLabel({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    final text = Text(
      label,
      style: TextStyle(
        fontSize: r.scale(11, tablet: 12),
        color: onTap != null ? AppColors.primary : AppColors.textSecondary,
        fontWeight: onTap != null ? FontWeight.w600 : FontWeight.w500,
      ),
    );

    if (onTap == null) return text;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.scale(10),
          vertical: r.scale(10),
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: text,
      ),
    );
  }
}

class _NumberInput extends StatelessWidget {
  const _NumberInput({
    required this.controller,
    required this.maxLength,
    this.unit = '',
    this.hasError = false,
    this.showUnitLabel = true,
    this.width,
    this.onUnitTap,
  });

  final TextEditingController controller;
  final String unit;
  final int maxLength;
  final bool hasError;
  final bool showUnitLabel;
  final double? width;
  final VoidCallback? onUnitTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    const fieldRadius = 10.0;
    final borderColor =
        hasError ? AppColors.error.withValues(alpha: 0.65) : AppColors.border;
    final fieldWidth = width ?? r.scale(52);

    final field = SizedBox(
      width: fieldWidth,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: maxLength,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: r.scale(14, tablet: 15),
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 10,
          ),
          counterText: '',
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(fieldRadius),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(fieldRadius),
            borderSide: BorderSide(
              color: hasError ? AppColors.error : AppColors.primary,
              width: 1.5,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(fieldRadius),
            borderSide: BorderSide(color: borderColor),
          ),
        ),
      ),
    );

    if (!showUnitLabel || unit.isEmpty) return field;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        field,
        const SizedBox(width: 6),
        _UnitLabel(label: unit, onTap: onUnitTap),
      ],
    );
  }
}

class _GenderToggle extends StatelessWidget {
  const _GenderToggle({
    required this.value,
    required this.options,
    required this.onChanged,
    this.hasError = false,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final idleBorder = hasError
        ? AppColors.error.withValues(alpha: 0.65)
        : AppColors.border;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((option) {
        final selected = value == option;
        return Padding(
          padding: EdgeInsets.only(left: option == options.first ? 0 : 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onChanged(option),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r.scale(12),
                  vertical: r.scale(8),
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? AppColors.primary : idleBorder,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: r.scale(12, tablet: 13),
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
