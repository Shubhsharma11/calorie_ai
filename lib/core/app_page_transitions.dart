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

  /// Builds a [GetPage] with the app's default forward/back animation.
  static GetPage<T> getPage<T>({
    required String name,
    required GetPageBuilder page,
    Bindings? binding,
    bool popGesture = true,
    Transition? pageTransition,
    Duration? pageDuration,
  }) {
    return GetPage<T>(
      name: name,
      page: page,
      binding: binding,
      transition: pageTransition ?? transition,
      transitionDuration: pageDuration ?? duration,
      curve: curve,
      popGesture: popGesture,
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
