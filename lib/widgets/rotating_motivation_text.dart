import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Cycles through short motivational lines on the home screen.
class RotatingMotivationText extends StatefulWidget {
  const RotatingMotivationText({
    super.key,
    this.interval = const Duration(seconds: 4),
    this.style,
    this.messages = defaultMessages,
  });

  final Duration interval;
  final TextStyle? style;
  final List<String> messages;

  static const defaultMessages = [
    'Stay focused, stay healthy!',
    'Small steps lead to big results.',
    'Fuel your body, fuel your goals.',
    'Consistency beats perfection.',
    'You are stronger than you think.',
    'One healthy choice at a time.',
    'Progress, not perfection.',
    'Keep going — you have got this!',
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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Text(
        widget.messages[_index],
        key: ValueKey<int>(_index),
        style: style,
      ),
    );
  }
}
