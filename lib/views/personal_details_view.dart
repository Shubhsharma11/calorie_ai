import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
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
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  late String _gender;

  static const _genders = ['Male', 'Female'];
  static const _ageIconAsset = 'assets/image/age.svg';
  static const _genderIconAsset = 'assets/image/gemder.svg';
  static const _heightIconAsset = 'assets/image/height.svg';
  static const _weightIconAsset = 'assets/image/weight2.2.svg';

  @override
  void initState() {
    super.initState();
    final u = _user.user;
    _gender = u.gender;
    _ageCtrl = TextEditingController(text: '${u.age}');
    _heightCtrl = TextEditingController(text: '${u.heightCm}');
    _weightCtrl = TextEditingController(text: '${u.weightKg}');
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final u = _user.user;
    final age = int.tryParse(_ageCtrl.text);
    final height = int.tryParse(_heightCtrl.text);
    final weight = int.tryParse(_weightCtrl.text);

    if (age == null || age < 1 || age > 100) {
      _showError('Please enter a valid age between 1 and 100.');
      return;
    }
    if (height == null || height < 100 || height > 250) {
      _showError('Please enter a valid height between 100 and 250 cm.');
      return;
    }
    if (weight == null || weight < 30 || weight > 300) {
      _showError('Please enter a valid weight between 30 and 300 kg.');
      return;
    }

    u.age = age;
    u.gender = _gender;
    u.heightCm = height;
    u.weightKg = weight;
    _user.onProfileUpdated();
    _user.syncWeightFromProfile();

    if (RouteArgs.isEditingFromProfile) {
      Get.back();
    } else {
      Get.toNamed(AppRoutes.goalSetup);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
              iconWidget: SvgPicture.asset(
                _ageIconAsset,
                fit: BoxFit.contain,
              ),
              label: 'Age',
              subtitle: 'Enter your age',
              child: _NumberInput(
                controller: _ageCtrl,
                unit: 'years',
                maxLength: 3,
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
              child: _GenderToggle(
                value: _gender,
                options: _genders,
                onChanged: (g) => setState(() => _gender = g),
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
              child: _NumberInput(
                controller: _heightCtrl,
                unit: 'cm',
                maxLength: 3,
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
              child: _NumberInput(
                controller: _weightCtrl,
                unit: 'kg',
                maxLength: 3,
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
  const _HeroSection({
    required this.r,
    required this.compact,
  });

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
  }) : assert(icon != null || iconWidget != null);

  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(14),
        vertical: r.scale(14),
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (iconWidget != null)
            SizedBox(
              width: 40,
              height: 40,
              child: iconWidget,
            )
          else
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
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
                  subtitle,
                  style: TextStyle(
                    fontSize: r.scale(11, tablet: 12),
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: r.scale(8)),
          child,
        ],
      ),
    );
  }
}

class _NumberInput extends StatelessWidget {
  const _NumberInput({
    required this.controller,
    required this.unit,
    required this.maxLength,
  });

  final TextEditingController controller;
  final String unit;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    const fieldRadius = 10.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: r.scale(52),
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
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(fieldRadius),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(fieldRadius),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          unit,
          style: TextStyle(
            fontSize: r.scale(11, tablet: 12),
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _GenderToggle extends StatelessWidget {
  const _GenderToggle({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

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
                    color: selected ? AppColors.primary : AppColors.border,
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
