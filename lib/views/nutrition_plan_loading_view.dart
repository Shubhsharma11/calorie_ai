import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/onboarding_setup_loading_controller.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';
import '../widgets/responsive_page.dart';

class NutritionPlanLoadingView extends GetView<OnboardingSetupLoadingController> {
  const NutritionPlanLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Obx(() {
          final progress = controller.progress.value;
          final activeStep = controller.activeStep.value;
          final error = controller.errorMessage.value;

          return SetupScreenLayout(
            scrollable: true,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: r.scale(24)),
                _HeroGraphic(progress: progress),
                SizedBox(height: r.scale(28)),
                _TitleSection(r: r),
                SizedBox(height: r.scale(28)),
                _ProgressSection(progress: progress, r: r),
                SizedBox(height: r.scale(24)),
                _StepsList(activeStep: activeStep, r: r),
                SizedBox(height: r.scale(20)),
                const _TipCard(),
              ],
            ),
            action: error != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(bottom: r.scale(12)),
                        child: Text(
                          error,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: r.scale(14),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: controller.goBack,
                          child: const Text('Go back'),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          );
        }),
      ),
    );
  }
}

class _HeroGraphic extends StatelessWidget {
  const _HeroGraphic({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final size = r.scale(160, tablet: 180);

    return SizedBox(
      height: size + 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 8,
            right: r.scale(72),
            child: _FloatingLeaf(size: 18, rotation: -0.4),
          ),
          Positioned(
            top: 28,
            left: r.scale(64),
            child: _FloatingLeaf(size: 14, rotation: 0.5),
          ),
          Positioned(
            bottom: 12,
            right: r.scale(58),
            child: _FloatingLeaf(size: 16, rotation: 0.2),
          ),
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    value: progress.clamp(0.05, 1.0),
                    strokeWidth: 3,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    color: AppColors.primary,
                  ),
                ),
                Container(
                  width: size * 0.72,
                  height: size * 0.72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    size: size * 0.34,
                    color: AppColors.primary,
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

class _FloatingLeaf extends StatelessWidget {
  const _FloatingLeaf({required this.size, required this.rotation});

  final double size;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Icon(
        Icons.eco_rounded,
        size: size,
        color: AppColors.primary.withValues(alpha: 0.55),
      ),
    );
  }
}

class _TitleSection extends StatelessWidget {
  const _TitleSection({required this.r});

  final Responsive r;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: r.scale(24, tablet: 26),
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: AppColors.textPrimary,
            ),
            children: const [
              TextSpan(text: 'Generating your '),
              TextSpan(
                text: 'nutrition plan...',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
        SizedBox(height: r.scale(10)),
        Text(
          "We're analyzing your profile and creating a personalized plan just for you.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: r.scale(14),
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.progress, required this.r});

  final double progress;
  final Responsive r;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round().clamp(0, 100);

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surface,
              color: AppColors.primary,
            ),
          ),
        ),
        SizedBox(width: r.scale(12)),
        Text(
          '$percent%',
          style: TextStyle(
            fontSize: r.scale(15),
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _StepsList extends StatelessWidget {
  const _StepsList({required this.activeStep, required this.r});

  final int activeStep;
  final Responsive r;

  static const _labels = [
    'Analyzing your profile',
    'Calculating calorie & macro targets',
    'Building your nutrition plan',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _labels.length; i++)
          _StepRow(
            label: _labels[i],
            index: i,
            activeStep: activeStep,
            isLast: i == _labels.length - 1,
            r: r,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.index,
    required this.activeStep,
    required this.isLast,
    required this.r,
  });

  final String label;
  final int index;
  final int activeStep;
  final bool isLast;
  final Responsive r;

  _StepStatus get _status {
    if (index < activeStep) return _StepStatus.done;
    if (index == activeStep) return _StepStatus.active;
    return _StepStatus.pending;
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                _StepIndicator(status: status),
                if (!isLast)
                  Expanded(
                    child: CustomPaint(
                      painter: _DashedLinePainter(color: AppColors.border),
                      size: const Size(2, double.infinity),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: r.scale(12)),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : r.scale(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: r.scale(15),
                      fontWeight: FontWeight.w600,
                      color: status == _StepStatus.pending
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (status == _StepStatus.active) ...[
                    SizedBox(height: r.scale(4)),
                    Text(
                      'Almost there...',
                      style: TextStyle(
                        fontSize: r.scale(13),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepStatus { pending, active, done }

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.status});

  final _StepStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      _StepStatus.done => Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 16, color: AppColors.onPrimary),
      ),
      _StepStatus.active => SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.primary,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      _StepStatus.pending => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 2),
        ),
      ),
    };
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashHeight = 4.0;
    const gap = 4.0;
    var y = 4.0;

    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + dashHeight),
        paint,
      );
      y += dashHeight + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.all(r.scale(14)),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          SizedBox(width: r.scale(12)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: r.scale(13.5),
                  height: 1.45,
                  color: AppColors.textPrimary,
                ),
                children: const [
                  TextSpan(
                    text: 'Good things take time! ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text:
                        'Your personalized plan will help you reach your goals faster and stay healthier.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
