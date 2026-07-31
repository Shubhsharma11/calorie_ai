import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ScreenSize { mobile, tablet, desktop }

/// Adaptive sizing driven by [MediaQuery], similar to common Flutter apps /
/// ScreenUtil-style scaling:
/// - Phones: sizes scale with screen width vs a design baseline
/// - Tablet / desktop: modest bump only + [contentMaxWidth] (not full blow-up)
class Responsive {
  Responsive(this.context);

  final BuildContext context;

  /// Phone / tablet / desktop breakpoints (Material-style).
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;

  /// Narrow phones (e.g. iPhone SE).
  static const double compactBreakpoint = 360;

  /// Design reference width (common ~iPhone 14 logical width).
  static const double designWidth = 390;

  /// How far phone UI may shrink / grow vs the design width.
  static const double minPhoneScale = 0.85;
  static const double maxPhoneScale = 1.30;

  static Responsive of(BuildContext context) => Responsive(context);

  MediaQueryData get _mq => MediaQuery.of(context);

  double get width => _mq.size.width;
  double get height => _mq.size.height;
  double get shortSide => math.min(width, height);
  double get longSide => math.max(width, height);

  /// System accessibility text scale (Flutter [Text] still applies this too).
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

  /// Narrow phones where horizontal space is tight.
  bool get isCompact => shortSide < compactBreakpoint;

  /// Width used for phone scaling. In landscape, use the short side so the UI
  /// does not jump to “tablet-sized” type when the phone is rotated.
  double get _scaleWidth {
    if (isMobile && isLandscape) return shortSide;
    if (isMobile) return width;
    return designWidth;
  }

  /// Uniform scale factor for spacing, icons, and fonts.
  ///
  /// Phones track width linearly (clamped). Larger devices keep a mild fixed
  /// scale and rely on max content width — same pattern as most production apps.
  double get widthFactor => switch (screenSize) {
        ScreenSize.mobile =>
          (_scaleWidth / designWidth).clamp(minPhoneScale, maxPhoneScale),
        ScreenSize.tablet => 1.10,
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

  /// Scale a design-px value (fonts, spacing, icons) for the current device.
  double sp(double value) => value * widthFactor;

  /// Size that can differ by breakpoint (optional tablet / desktop overrides).
  double scale(double mobile, {double? tablet, double? desktop}) =>
      switch (screenSize) {
        ScreenSize.mobile => sp(mobile),
        ScreenSize.tablet => tablet ?? mobile * 1.10,
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
