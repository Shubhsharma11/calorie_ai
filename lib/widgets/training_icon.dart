import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Exercise / calories-burn artwork from [training.svg].
class TrainingIcon extends StatelessWidget {
  const TrainingIcon({super.key, this.size = 22});

  static const asset = 'assets/image/training.svg';

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(asset, fit: BoxFit.contain),
    );
  }
}
