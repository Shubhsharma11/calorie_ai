import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_colors.dart';

/// Success popup when the daily calorie goal is reached.
class CalorieGoalSuccessDialog extends StatefulWidget {
  const CalorieGoalSuccessDialog({
    super.key,
    required this.consumed,
    required this.goal,
  });

  final int consumed;
  final int goal;

  static const _lottieAsset = 'assets/image/success.json';

  static Future<void> show({
    required int consumed,
    required int goal,
  }) {
    return Get.dialog<void>(
      CalorieGoalSuccessDialog(consumed: consumed, goal: goal),
      barrierDismissible: true,
      barrierColor: Colors.black54,
    );
  }

  @override
  State<CalorieGoalSuccessDialog> createState() =>
      _CalorieGoalSuccessDialogState();
}

class _CalorieGoalSuccessDialogState extends State<CalorieGoalSuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _dismiss() => Get.back<void>();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 320,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 120,
                    height: 96,
                    child: ClipRect(
                      child: Center(
                        child: Transform.scale(
                          scale: 1.45,
                          child: Lottie.asset(
                            CalorieGoalSuccessDialog._lottieAsset,
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,    
                            repeat: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Daily Calorie Goal Achieved!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Congratulations! You hit your daily calorie goal of '
                    '${widget.goal} kcal with ${widget.consumed} kcal logged today. '
                    'Great work staying on track!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _dismiss,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Awesome!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
