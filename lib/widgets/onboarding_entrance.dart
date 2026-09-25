import 'package:flutter/material.dart';

/// Directional staggered entrance for in-page onboarding questions
/// (e.g. gender → age on the same route).
///
/// Forward: slides in from the right. Backward: from the left.
class OnboardingEntrance extends StatefulWidget {
  const OnboardingEntrance({
    super.key,
    required this.builder,
    this.replayToken,
    this.forward = true,
    this.duration = const Duration(milliseconds: 300),
    this.stagger = const Duration(milliseconds: 50),
    this.itemDuration = const Duration(milliseconds: 260),
    this.curve = Curves.easeOutCubic,
  });

  /// Rebuild/restart when this changes (e.g. current onboarding sub-step).
  final Object? replayToken;

  /// `true` = forward (from right), `false` = back (from left).
  final bool forward;

  final Duration duration;
  final Duration stagger;
  final Duration itemDuration;
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

  /// Noticeable horizontal travel — same language as route push.
  Offset get _beginOffset =>
      widget.forward ? const Offset(0.22, 0) : const Offset(-0.22, 0);

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
    if (oldWidget.replayToken != widget.replayToken ||
        oldWidget.forward != widget.forward) {
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
    final start = (index * staggerMs / totalMs).clamp(0.0, 0.7);
    final end =
        ((index * staggerMs + itemMs) / totalMs).clamp(start + 0.08, 1.0);

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: widget.curve),
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, (start + 0.45).clamp(0.0, 1.0),
              curve: Curves.easeOut),
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: _beginOffset,
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
