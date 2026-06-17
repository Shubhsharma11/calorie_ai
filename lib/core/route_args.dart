import 'package:get/get.dart';

/// Route argument helpers for edit vs onboarding flows.
abstract final class RouteArgs {
  static const fromProfile = 'fromProfile';
  static const returnToDailyGoal = 'returnToDailyGoal';

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

  static Map<String, bool> get fromProfileMap => {fromProfile: true};

  static Map<String, bool> get returnToDailyGoalMap => {
        returnToDailyGoal: true,
      };
}
