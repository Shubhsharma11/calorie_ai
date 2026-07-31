import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_colors.dart';

/// Shared delete Lottie (`Delete_message.json`) used across delete flows.
abstract final class DeleteLottie {
  static const asset = 'assets/image/Delete_message.json';
}

/// In-place delete Lottie that fills a meal row card.
class DeleteLottieBox extends StatefulWidget {
  const DeleteLottieBox({
    super.key,
    required this.onCompleted,
    this.height = 72,
    this.size = 72,
  });

  final VoidCallback onCompleted;
  final double height;
  final double size;

  @override
  State<DeleteLottieBox> createState() => _DeleteLottieBoxState();
}

class _DeleteLottieBoxState extends State<DeleteLottieBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _done = false;
  Timer? _fallback;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    // Fallback if composition never loads — still long enough to see.
    _fallback = Timer(const Duration(milliseconds: 1400), _finish);
  }

  @override
  void dispose() {
    _fallback?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _fallback?.cancel();
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    // Many delete Lotties include empty padding — scale up so the trash
    // fills the same-height row without growing the box.
    final lottieSize = widget.size * 1.55;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ColoredBox(
        color: AppColors.error.withValues(alpha: 0.06),
        child: ClipRect(
          child: Center(
            child: Lottie.asset(
              DeleteLottie.asset,
              controller: _controller,
              width: lottieSize,
              height: lottieSize,
              fit: BoxFit.contain,
              onLoaded: (composition) {
                _controller
                  ..duration = composition.duration
                  ..forward().whenComplete(_finish);
              },
              errorBuilder: (context, error, stackTrace) {
                debugPrint('DeleteLottie error: $error');
                // Keep icon visible briefly — do not finish on the next frame.
                Future<void>.delayed(
                  const Duration(milliseconds: 900),
                  _finish,
                );
                return Icon(
                  Icons.delete_outline_rounded,
                  size: widget.size * 0.7,
                  color: AppColors.error,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
