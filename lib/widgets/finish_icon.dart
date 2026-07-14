import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Goal / finish-line artwork from [finish.svg].
class FinishIcon extends StatelessWidget {
  const FinishIcon({super.key, this.size = 22});

  static const asset = 'assets/image/finish.svg';

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
