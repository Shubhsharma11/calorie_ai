import 'package:get/get.dart';

/// Route argument helpers for edit vs onboarding flows.
abstract final class RouteArgs {
  static const fromProfile = 'fromProfile';
  static const returnToDailyGoal = 'returnToDailyGoal';
  static const onboardingStep = 'onboardingStep';
  static const stepAge = 'age';
  static const stepHeight = 'height';
  static const stepWeight = 'weight';
  static const stepMeals = 'meals';

  /// Diet preferences phase for the split Lifestyle / Preferences flow.
  static const dietPhase = 'dietPhase';
  static const dietPhaseLifestyle = 'lifestyle'; // eating habits + meals
  static const dietPhaseAvoid = 'avoid'; // foods to avoid only
  static const dietPhaseDietType = 'dietType'; // legacy → lifestyle   
       
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

  static Map<String, String> get onboardingWeightMap => {
        onboardingStep: stepWeight,
      };

  static String? get dietPreferencesPhase {
    final args = Get.arguments;
    if (args is Map) {
      final phase = args[dietPhase];
      if (phase is String) return phase;
    }
    return null;
  }

  static Map<String, String> get dietLifestyleMap => {
        dietPhase: dietPhaseLifestyle,
      };

  static Map<String, String> get dietLifestyleMealsMap => {
        dietPhase: dietPhaseLifestyle,
        onboardingStep: stepMeals,
      };

  static Map<String, String> get dietAvoidMap => {
        dietPhase: dietPhaseAvoid,
      };

  /// Profile → “Don’t eat” only (avoid phase + save & pop).
  static Map<String, Object> get fromProfileDietAvoidMap => {
        fromProfile: true,
        dietPhase: dietPhaseAvoid,
      };

  static Map<String, String> get dietTypeOnlyMap => dietLifestyleMap;
}
