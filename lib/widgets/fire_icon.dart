import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Calories eaten artwork from [fire01.svg].
class FireIcon extends StatelessWidget {
  const FireIcon({super.key, this.size = 22});

  static const asset = 'assets/image/fire01.svg';

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
