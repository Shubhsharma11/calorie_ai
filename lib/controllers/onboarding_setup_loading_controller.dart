import 'dart:async';

import 'package:get/get.dart';

import '../routes/app_routes.dart';
import 'user_controller.dart';

class OnboardingSetupLoadingController extends GetxController {
  final progress = 0.0.obs;
  final activeStep = 0.obs;
  final errorMessage = RxnString();

  Timer? _progressTimer;
  static const _steps = 3;

  @override
  void onInit() {
    super.onInit();
    unawaited(_runSetup());
  }

  @override
  void onClose() {
    _progressTimer?.cancel();
    super.onClose();
  }

  Future<void> _runSetup() async {
    final user = Get.find<UserController>();
    final error = await user.completeOnboardingWithProgress(
      onProgress: _handleProgress,
    );

    if (error != null) {
      errorMessage.value = error;
      return;
    }

    progress.value = 1;
    activeStep.value = _steps;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    Get.offNamed(AppRoutes.dailyCalorieGoal);
  }

  void _handleProgress(double value, int step) {
    _progressTimer?.cancel();
    progress.value = value.clamp(0.0, 1.0);
    activeStep.value = step.clamp(0, _steps);

    if (step < _steps && value < 1) {
      final stepStart = step / _steps;
      final stepEnd = (step + 1) / _steps;
      _animateWithinStep(stepStart, stepEnd);
    }
  }

  void _animateWithinStep(double from, double to) {
    final startedAt = DateTime.now();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      final t = (elapsedMs / 4000).clamp(0.0, 1.0);
      final creep = from + (to - from) * t * 0.85;
      if (creep > progress.value && creep < to) {
        progress.value = creep;
      }
    });
  }

  void goBack() => Get.back();
}
