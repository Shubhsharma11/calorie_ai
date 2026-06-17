import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _ringController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _checkScale;
  late final Animation<double> _ringScale;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0, 0.7, curve: Curves.elasticOut),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.25, 1, curve: Curves.easeOut),
    );

    _checkScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.35, 0.85, curve: Curves.elasticOut),
      ),
    );

    _ringScale = Tween<double>(begin: 0.6, end: 1.35).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOut),
    );

    _entryController.forward();
    _ringController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _ringController.dispose();
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
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
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
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _ringController,
                          builder: (_, child) {
                            return Transform.scale(
                              scale: _ringScale.value,
                              child: Opacity(
                                opacity:
                                    (1.1 - _ringScale.value).clamp(0.0, 0.5),
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(alpha: 0.18),
                            ),
                          ),
                        ),
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ScaleTransition(
                            scale: _checkScale,
                            child: Icon(
                              Icons.check_rounded,
                              color: AppColors.card,
                              size: 48,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 8,
                          child: ScaleTransition(
                            scale: _checkScale,
                            child: const Text(
                              '🎉',
                              style: TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Daily Calorie Goal Achieved!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _dismiss,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
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
