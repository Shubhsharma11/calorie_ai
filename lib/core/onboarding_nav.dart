import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Tracks direction and plays a shared content exit before route swaps.
///
/// Set [isForward] before in-page step changes. Prefer [offNamed] for
/// cross-route hops so exit + enter always share one motion language.
abstract final class OnboardingNav {
  static bool isForward = true;

  /// When false, mounted [OnboardingQuestionTransition]s animate content out.
  static final ValueNotifier<bool> contentVisible = ValueNotifier<bool>(true);

  /// Must match [OnboardingMotion.duration].
  static const Duration handoffDuration = Duration(milliseconds: 320);

  static bool _navigating = false;

  static void markForward() => isForward = true;

  static void markBackward() => isForward = false;

  /// Animate question content out (chrome stays). Safe to call when already hidden.
  static Future<void> playExit({bool? forward}) async {
    if (forward != null) isForward = forward;
    if (!contentVisible.value) {
      await Future<void>.delayed(handoffDuration);
      return;
    }
    contentVisible.value = false;
    await Future<void>.delayed(handoffDuration);
  }

  /// Content exit → replace route → new screen content entrance.
  static Future<void> offNamed(
    String route, {
    dynamic arguments,
    bool forward = true,
    bool animate = true,
  }) async {
    if (_navigating) return;
    _navigating = true;
    isForward = forward;
    try {
      if (animate) {
        await playExit();
      }
      Get.offNamed(route, arguments: arguments);
      contentVisible.value = true;
    } finally {
      _navigating = false;
    }
  }
}
