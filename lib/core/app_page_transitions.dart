import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shared route transition settings used across GetX navigation.
abstract final class AppPageTransitions {
  static const Duration duration = Duration(milliseconds: 320);
  static const Duration reverseDuration = Duration(milliseconds: 280);

  static const Curve curve = Curves.easeOutCubic;
  static const Curve reverseCurve = Curves.easeInCubic;

  static const Transition transition = Transition.rightToLeftWithFade;

  /// Soft vertical fade for onboarding setup steps (goal → weight → activity).
  static const Duration onboardingDuration = Duration(milliseconds: 450);

  /// Builds a [GetPage] with the app's default forward/back animation.
  static GetPage<T> getPage<T>({
    required String name,
    required GetPageBuilder page,
    Bindings? binding,
    bool popGesture = true,
    Transition? pageTransition,
    Duration? pageDuration,
    CustomTransition? customTransition,
  }) {
    return GetPage<T>(
      name: name,
      page: page,
      binding: binding,
      customTransition: customTransition,
      transition: pageTransition ?? transition,
      transitionDuration: pageDuration ?? duration,
      curve: curve,
      popGesture: popGesture,
    );
  }

  /// Onboarding step pages — same soft up/fade feel as Personal Details.
  static GetPage<T> onboardingPage<T>({
    required String name,
    required GetPageBuilder page,
    Bindings? binding,
    bool popGesture = true,
  }) {
    return getPage<T>(
      name: name,
      page: page,
      binding: binding,
      popGesture: popGesture,
      customTransition: OnboardingStepTransition(),
      pageDuration: onboardingDuration,
      pageTransition: Transition.fade,
    );
  }

  /// Tab/content switch animation for in-shell navigation (e.g. bottom nav).
  static Widget tabTransition(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(parent: animation, curve: curve);

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  /// Material [ThemeData.pageTransitionsTheme] for any native [Navigator] routes.
  static PageTransitionsTheme get pageTransitionsTheme {
    return PageTransitionsTheme(
      builders: {
        TargetPlatform.android: const FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
      },
    );
  }
}

/// Incoming page fades in and drifts up from below (and reverses on back).
class OnboardingStepTransition extends CustomTransition {
  OnboardingStepTransition();

  static const _drift = 0.035;

  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final primary = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );

    // When another onboarding page is pushed on top, ease this one up & out.
    final secondary = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );

    final incomingSlide = Tween<Offset>(
      begin: const Offset(0, _drift),
      end: Offset.zero,
    ).animate(primary);

    final outgoingSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -_drift),
    ).animate(secondary);

    final outgoingFade = Tween<double>(begin: 1, end: 0).animate(secondary);

    return SlideTransition(
      position: outgoingSlide,
      child: FadeTransition(
        opacity: outgoingFade,
        child: FadeTransition(
          opacity: primary,
          child: SlideTransition(
            position: incomingSlide,
            child: child,
          ),
        ),
      ),
    );
  }
}
