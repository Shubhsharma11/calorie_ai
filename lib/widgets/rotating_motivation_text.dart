import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Cycles through short motivational lines on the home screen.
class RotatingMotivationText extends StatefulWidget {
  const RotatingMotivationText({
    super.key,
    this.interval = const Duration(seconds: 6),
    this.style,
    this.messages = defaultMessages,
  });

  final Duration interval;
  final TextStyle? style;
  final List<String> messages;

  static const defaultMessages = [
    'Believe in yourself every day.',
'Every workout makes you stronger.',
'Healthy habits build a healthy life.',
'Today is a great day to improve.',
'Your future starts with today.',
'Discipline creates lasting success.',
'Choose progress over excuses.',
'Keep moving forward with confidence.',
'Your health is your greatest wealth.',
'Every healthy choice matters.',
'Dream big, work hard, stay healthy.',
'Stronger every single day.',
'Be proud of every small victory.',
'You are capable of amazing things.',
'Never give up on your goals.',
'Fitness is a journey, not a race.',
'Stay active, stay positive.',
'Your body deserves your best.',
'Make today count.',
'Success begins with self-care.',
'Good habits, great results.',
'One step closer every day.',
'Stay committed to your goals.',
'Healthy mind, healthy body.',
'Push yourself beyond your limits.',
'Be better than yesterday.',
'Keep your goals in sight.',
'Great things take consistency.',
'Focus on progress every day.',
'Every effort brings results.',
'Small wins create big changes.',
'You are stronger than your excuses.',
'Take care of yourself first.',
'Keep chasing your healthiest self.',
'Rise stronger every morning.',
'Nothing changes unless you do.',
'Your journey is worth it.',
'Stay determined, stay unstoppable.',
'The best investment is your health.',
'Keep showing up for yourself.',
'Every day is a fresh start.',
'Healthy living is lifelong success.',
'Confidence grows with consistency.',
'You have everything you need.',
'Stay patient and trust the process.',
'One workout at a time.',
'Progress starts with one decision.',
'Your goals are within reach.',
'Strong habits create strong lives.',
'The only limit is you.',
  ];

  @override
  State<RotatingMotivationText> createState() => _RotatingMotivationTextState();
}

class _RotatingMotivationTextState extends State<RotatingMotivationText> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % widget.messages.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ??
        TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.3,
        );

    final lineHeight = (style.fontSize ?? 14) * (style.height ?? 1.3);
    const maxLines = 1;
    final fixedHeight = lineHeight * maxLines;

    return SizedBox(
      height: fixedHeight,
      width: double.infinity,
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 480),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.hardEdge,
              children: [
                ...previousChildren,
                ?currentChild,
              ],
            );
          },
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: FittedBox(
            key: ValueKey<int>(_index),
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              widget.messages[_index],
              style: style,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ),
      ),
    );
  }
}
