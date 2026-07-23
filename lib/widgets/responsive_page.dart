import 'package:flutter/material.dart';

import '../core/responsive.dart';

/// Centers content and applies responsive padding with a max width.
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.child,
    this.scrollable = false,
    this.padding,
    this.maxWidth,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final bool scrollable;
  final EdgeInsets? padding;
  final double? maxWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    Widget content = Padding(
      padding: padding ?? r.pagePadding,
      child: child,
    );

    content = Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? r.contentMaxWidth,
        ),
        child: content,
      ),
    );

    if (scrollable) {
      return SingleChildScrollView(child: content);
    }
    return content;
  }
}

/// Constrains auth/onboarding forms on wide screens.
class ResponsiveForm extends StatelessWidget {
  const ResponsiveForm({
    super.key,
    required this.child,
    this.scrollable = true,
  });

  final Widget child;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    Widget content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.formMaxWidth),
        child: Padding(
          padding: r.pagePadding,
          child: child,
        ),
      ),
    );

    if (scrollable) {
      return SingleChildScrollView(child: content);
    }
    return content;
  }
}

/// Setup/onboarding-style layout: scrollable content + anchored action button.
class SetupScreenLayout extends StatelessWidget {
  const SetupScreenLayout({
    super.key,
    required this.content,
    required this.action,
    this.scrollable = true,
    this.contentAlignment = Alignment.topCenter,
  });

  final Widget content;
  final Widget action;
  final bool scrollable;
  final Alignment contentAlignment;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final horizontalPadding = r.pagePadding.left;

    Widget body = Padding(
      padding: EdgeInsets.only(top: r.scale(8)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.formMaxWidth),
        child: content,
      ),
    );

    if (scrollable) {
      body = SingleChildScrollView(
        clipBehavior: Clip.none,
        child: body,
      );
    } else {
      body = Align(alignment: contentAlignment, child: body);
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: body),
            SizedBox(height: r.scale(20)),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: r.formMaxWidth),
              child: action,
            ),
            SizedBox(height: r.scale(12)),
          ],
        ),
      ),
    );
  }
}

/// Picks mobile, tablet, or desktop layout.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    if (r.isDesktop && desktop != null) return desktop!;
    if (r.isTablet && tablet != null) return tablet!;
    if (r.isTablet && desktop != null) return desktop!;
    return mobile;
  }
}
