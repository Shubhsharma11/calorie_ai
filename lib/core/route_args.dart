import 'package:get/get.dart';

/// Route argument helpers for edit vs onboarding flows.
abstract final class RouteArgs {
  static const fromProfile = 'fromProfile';
  static const returnToDailyGoal = 'returnToDailyGoal';
  static const onboardingStep = 'onboardingStep';
  static const stepAge = 'age';
  static const stepHeight = 'height';

  /// True when a setup screen was opened from Profile (save & go back).
  static bool get isEditingFromProfile {
    final args = Get.arguments;
    if (args == true) return true;
    if (args is Map && args[fromProfile] == true) return true;
    return false;
  }

  /// True when a setup screen should return to the daily goal screen.
  static bool get shouldReturnToDailyGoal {
    final args = Get.arguments;
    return args is Map && args[returnToDailyGoal] == true;
  }

  /// Onboarding-only: open personal details on a specific sub-step.
  static String? get onboardingStartStep {
    final args = Get.arguments;
    if (args is Map) {
      final step = args[onboardingStep];
      if (step is String) return step;
    }
    return null;
  }

  static Map<String, bool> get fromProfileMap => {fromProfile: true};

  static Map<String, bool> get returnToDailyGoalMap => {
        returnToDailyGoal: true,
      };

  static Map<String, String> get onboardingAgeMap => {
        onboardingStep: stepAge,
      };

  static Map<String, String> get onboardingHeightMap => {
        onboardingStep: stepHeight,
      };
}
