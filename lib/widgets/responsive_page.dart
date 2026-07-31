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
    this.scrollController,
  });

  final Widget child;
  final bool scrollable;
  final EdgeInsets? padding;
  final double? maxWidth;
  final Alignment alignment;
  final ScrollController? scrollController;

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
      final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
      return SingleChildScrollView(
        controller: scrollController,
        clipBehavior: Clip.hardEdge,
        padding: EdgeInsets.only(
          bottom: r.scale(24) + (keyboardInset > 0 ? r.scale(12) : 0),
        ),
        child: content,
      );
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
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

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
      return SingleChildScrollView(
        clipBehavior: Clip.hardEdge,
        padding: EdgeInsets.only(
          bottom: r.scale(28) + (keyboardInset > 0 ? r.scale(12) : 0),
        ),
        child: content,
      );
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

    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    if (scrollable) {
      body = SingleChildScrollView(
        // Keep content from painting over the sticky bottom action.
        clipBehavior: Clip.hardEdge,
        padding: EdgeInsets.only(
          bottom: r.scale(36) + (keyboardInset > 0 ? r.scale(16) : 0),
        ),
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
            Expanded(
              child: ClipRect(child: body),
            ),
            SizedBox(height: r.scale(16)),
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
