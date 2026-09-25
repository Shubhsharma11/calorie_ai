import 'package:flutter/material.dart';

import '../core/onboarding_nav.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';

/// Shared motion language for every onboarding handoff (in-page + route).
///
/// Matches common health-app onboarding: chrome stays put, question content
/// slides with a soft fade in the navigation direction.
abstract final class OnboardingMotion {
  static const Duration duration = OnboardingNav.handoffDuration;
  static const Curve inCurve = Curves.easeOutCubic;
  static const Curve outCurve = Curves.easeInCubic;

  /// Horizontal travel (~28px) — readable direction without a full-page push.
  static double slideFraction(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= 0) return 0.07;
    return (28 / width).clamp(0.05, 0.09);
  }

  static double direction({bool? forward}) =>
      (forward ?? OnboardingNav.isForward) ? 1.0 : -1.0;

  /// Enter from [direction] side; exit toward the opposite side.
  static Widget buildHandoff({
    required BuildContext context,
    required Animation<double> animation,
    required Widget child,
    bool? forward,
  }) {
    final dx = slideFraction(context);
    final dir = direction(forward: forward);

    return DualTransitionBuilder(
      animation: animation,
      forwardBuilder: (context, anim, child) {
        final curved = CurvedAnimation(parent: anim, curve: inCurve);
        final fade = CurvedAnimation(
          parent: anim,
          curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
        );
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(dx * dir, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child!,
          ),
        );
      },
      reverseBuilder: (context, anim, child) {
        final curved = CurvedAnimation(parent: anim, curve: outCurve);
        final fade = CurvedAnimation(
          parent: anim,
          curve: const Interval(0.0, 0.75, curve: Curves.easeIn),
        );
        return FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0).animate(fade),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: Offset(-dx * dir, 0),
            ).animate(curved),
            child: child!,
          ),
        );
      },
      child: child,
    );
  }
}

/// Question/answer swap for onboarding.
///
/// Progress / section label / Continue stay outside this widget.
/// Same handoff on first mount (route change) and on in-page step changes.
class OnboardingQuestionTransition extends StatefulWidget {
  const OnboardingQuestionTransition({
    super.key,
    required this.stepKey,
    required this.question,
    required this.answer,
    this.description,
    this.forward,
    this.duration = OnboardingMotion.duration,
  });

  /// Changes when the question changes (drives the transition).
  final Object stepKey;

  /// Question title (and optional error).
  final Widget question;

  /// Optional supporting copy under the title (“why this matters”).
  final Widget? description;

  final Widget answer;

  /// Defaults to [OnboardingNav.isForward].
  final bool? forward;

  final Duration duration;

  @override
  State<OnboardingQuestionTransition> createState() =>
      _OnboardingQuestionTransitionState();
}

class _OnboardingQuestionTransitionState
    extends State<OnboardingQuestionTransition> {
  late bool _forward;

  /// False until the first frame so route arrivals get the same entrance.
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _forward = widget.forward ?? OnboardingNav.isForward;
    OnboardingNav.contentVisible.addListener(_onContentVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    OnboardingNav.contentVisible.removeListener(_onContentVisibility);
    super.dispose();
  }

  void _onContentVisibility() {
    if (!mounted) return;
    _forward = widget.forward ?? OnboardingNav.isForward;
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant OnboardingQuestionTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stepKey != widget.stepKey ||
        oldWidget.forward != widget.forward) {
      _forward = widget.forward ?? OnboardingNav.isForward;
    }
  }

  @override
  Widget build(BuildContext context) {
    final show = _ready && OnboardingNav.contentVisible.value;

    return AnimatedSwitcher(
      duration: widget.duration,
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          fit: StackFit.expand,
          children: <Widget>[...previousChildren, ?currentChild],
        );
      },
      transitionBuilder: (child, animation) {
        return OnboardingMotion.buildHandoff(
          context: context,
          animation: animation,
          forward: _forward,
          child: child,
        );
      },
      child: !show
          ? const SizedBox.shrink(key: ValueKey<String>('__onboarding_boot'))
          : _QuestionContent(
              key: ValueKey(widget.stepKey),
              question: widget.question,
              description: widget.description,
              answer: widget.answer,
            ),
    );
  }
}

class _QuestionContent extends StatelessWidget {
  const _QuestionContent({
    super.key,
    required this.question,
    required this.answer,
    this.description,
  });

  final Widget question;
  final Widget? description;
  final Widget answer;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final hasDescription = description != null;

    return Column(
      children: [
        question,
        if (hasDescription) ...[SizedBox(height: r.scale(10)), description!],
        SizedBox(height: r.scale(hasDescription ? 18 : 22)),
        Expanded(child: answer),
      ],
    );
  }
}

/// Supporting “why this matters” copy under the question title.
class OnboardingQuestionDescription extends StatelessWidget {
  const OnboardingQuestionDescription(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final fontFamily = Theme.of(context).textTheme.bodyMedium?.fontFamily;
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: const ['sans-serif', 'Roboto'],
        fontSize: r.scale(15, tablet: 16),
        fontWeight: FontWeight.w400,
        height: 1.35,
        letterSpacing: -0.2,
        color: AppColors.textSecondaryOf(context),
        decoration: TextDecoration.none,
      ),
    );
  }
}
