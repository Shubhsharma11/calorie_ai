import 'package:flutter/material.dart';

/// Goal / finish flag icon.
class FinishIcon extends StatelessWidget {
  const FinishIcon({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.flag_rounded,
      size: size,
      color: color ?? const Color(0xFF4CAF50),
    );
  }
}
