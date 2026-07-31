import 'package:flutter/material.dart';

/// Exercise / calories-burn icon.
class TrainingIcon extends StatelessWidget {
  const TrainingIcon({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.local_fire_department_rounded,
      size: size,
      color: color ?? const Color(0xFFFF9500),
    );
  }
}
