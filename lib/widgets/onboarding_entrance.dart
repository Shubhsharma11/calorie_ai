import 'package:flutter/material.dart';

/// Staggered fade + slide entrance for onboarding asking pages.
///
/// Uses [FadeTransition] + [SlideTransition] under one controller so title,
/// body, and actions enter one after another.
class OnboardingEntrance extends StatefulWidget {
  const OnboardingEntrance({
    super.key,
    required this.builder,
    this.replayToken,
    this.duration = const Duration(milliseconds: 520),
    this.stagger = const Duration(milliseconds: 70),
    this.itemDuration = const Duration(milliseconds: 360),
    this.beginOffset = const Offset(0, 0.055),
    this.curve = Curves.easeOutCubic,
  });

  /// Rebuild/restart when this changes (e.g. current onboarding sub-step).
  final Object? replayToken;

  final Duration duration;
  final Duration stagger;
  final Duration itemDuration;
  final Offset beginOffset;
  final Curve curve;

  final Widget Function(
    BuildContext context,
    OnboardingEntranceScope scope,
  ) builder;

  @override
  State<OnboardingEntrance> createState() => _OnboardingEntranceState();
}

class OnboardingEntranceScope {
  OnboardingEntranceScope._(this._state);

  final _OnboardingEntranceState _state;

  /// Fade + slide a child at [index] (0 = first).
  Widget item({
    required int index,
    required Widget child,
  }) {
    return _state._buildItem(index: index, child: child);
  }
}

class _OnboardingEntranceState extends State<OnboardingEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late OnboardingEntranceScope _scope;

  @override
  void initState() {
    super.initState();
    _scope = OnboardingEntranceScope._(this);
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant OnboardingEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replayToken != widget.replayToken) {
      _controller
        ..duration = widget.duration
        ..forward(from: 0);
    } else if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildItem({required int index, required Widget child}) {
    final totalMs = widget.duration.inMilliseconds.toDouble().clamp(1, 100000);
    final staggerMs = widget.stagger.inMilliseconds.toDouble();
    final itemMs = widget.itemDuration.inMilliseconds.toDouble();
    final start = (index * staggerMs / totalMs).clamp(0.0, 0.85);
    final end = ((index * staggerMs + itemMs) / totalMs).clamp(start + 0.05, 1.0);

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: widget.curve),
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: widget.beginOffset,
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _scope);
  }
}

/// Lightweight one-shot fade/slide for a single block (no stagger needed).
class OnboardingFadeSlide extends StatefulWidget {
  const OnboardingFadeSlide({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 380),
    this.beginOffset = const Offset(0, 0.04),
    this.curve = Curves.easeOutCubic,
    this.replayToken,
  });

  final Widget child;
  final Duration duration;
  final Offset beginOffset;
  final Curve curve;
  final Object? replayToken;

  @override
  State<OnboardingFadeSlide> createState() => _OnboardingFadeSlideState();
}

class _OnboardingFadeSlideState extends State<OnboardingFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: widget.curve);
    _slide = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant OnboardingFadeSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replayToken != widget.replayToken) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
