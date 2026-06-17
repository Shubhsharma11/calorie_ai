import 'package:flutter/material.dart';

enum ScreenSize { mobile, tablet, desktop }

/// Breakpoint helpers for adaptive layouts.
class Responsive {
  Responsive(this.context);

  final BuildContext context;

  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;

  static Responsive of(BuildContext context) => Responsive(context);

  double get width => MediaQuery.sizeOf(context).width;
  double get height => MediaQuery.sizeOf(context).height;

  ScreenSize get screenSize {
    if (width >= tabletBreakpoint) return ScreenSize.desktop;
    if (width >= mobileBreakpoint) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }

  bool get isMobile => screenSize == ScreenSize.mobile;
  bool get isTablet => screenSize == ScreenSize.tablet;
  bool get isDesktop => screenSize == ScreenSize.desktop;
  bool get isWide => width >= mobileBreakpoint;

  double get contentMaxWidth => switch (screenSize) {
        ScreenSize.mobile => width,
        ScreenSize.tablet => 720,
        ScreenSize.desktop => 1100,
      };

  double get formMaxWidth => switch (screenSize) {
        ScreenSize.mobile => width,
        ScreenSize.tablet => 480,
        ScreenSize.desktop => 520,
      };

  EdgeInsets get pagePadding => EdgeInsets.symmetric(
        horizontal: switch (screenSize) {
          ScreenSize.mobile => 20,
          ScreenSize.tablet => 32,
          ScreenSize.desktop => 48,
        },
        vertical: switch (screenSize) {
          ScreenSize.mobile => 16,
          ScreenSize.tablet => 24,
          ScreenSize.desktop => 28,
        },
      );

  double scale(double mobile, {double? tablet, double? desktop}) =>
      switch (screenSize) {
        ScreenSize.mobile => mobile,
        ScreenSize.tablet => tablet ?? mobile * 1.08,
        ScreenSize.desktop => desktop ?? mobile * 1.15,
      };

  int get gridColumns => switch (screenSize) {
        ScreenSize.mobile => 1,
        ScreenSize.tablet => 2,
        ScreenSize.desktop => 2,
      };
}

extension ResponsiveContext on BuildContext {
  Responsive get responsive => Responsive.of(this);
}
