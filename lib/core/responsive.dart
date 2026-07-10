import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ScreenSize { mobile, tablet, desktop }

/// Breakpoint helpers for adaptive layouts driven by [MediaQuery].
class Responsive {
  Responsive(this.context);

  final BuildContext context;

  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
  static const double compactBreakpoint = 360;
  static const double designWidth = 390;

  static Responsive of(BuildContext context) => Responsive(context);

  MediaQueryData get _mq => MediaQuery.of(context);

  double get width => _mq.size.width;
  double get height => _mq.size.height;
  double get shortSide => math.min(width, height);
  double get textScaleFactor => _mq.textScaler.scale(1).clamp(0.85, 1.3);

  bool get isLandscape => width > height;

  ScreenSize get screenSize {
    if (width >= tabletBreakpoint) return ScreenSize.desktop;
    if (width >= mobileBreakpoint) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }

  bool get isMobile => screenSize == ScreenSize.mobile;
  bool get isTablet => screenSize == ScreenSize.tablet;
  bool get isDesktop => screenSize == ScreenSize.desktop;
  bool get isWide => width >= mobileBreakpoint;

  /// Narrow phones (e.g. iPhone SE) where horizontal space is tight.
  bool get isCompact => width < compactBreakpoint;

  /// Width factor relative to the design reference (390 logical px).
  double get widthFactor => switch (screenSize) {
        ScreenSize.mobile => (width / designWidth).clamp(0.82, 1.12),
        ScreenSize.tablet => 1.08,
        ScreenSize.desktop => 1.15,
      };

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
        horizontal: sp(switch (screenSize) {
          ScreenSize.mobile => isCompact ? 16 : 20,
          ScreenSize.tablet => 32,
          ScreenSize.desktop => 48,
        }),
        vertical: sp(switch (screenSize) {
          ScreenSize.mobile => 16,
          ScreenSize.tablet => 24,
          ScreenSize.desktop => 28,
        }),
      );

  /// Fluid size from [MediaQuery] width — preferred for spacing, icons, and fonts.
  double sp(double value) => value * widthFactor;

  double scale(double mobile, {double? tablet, double? desktop}) =>
      switch (screenSize) {
        ScreenSize.mobile => sp(mobile),
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
