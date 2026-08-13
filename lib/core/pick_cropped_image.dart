import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';

const _maxEdge = 1280;

/// Picks a photo already downscaled, then crops. Falls back to the
/// resized original if the native cropper fails so the UI never hangs
/// on a full-resolution decode.
Future<Uint8List?> pickAndCropPhoto({
  required ImagePicker picker,
  required ImageSource source,
  required String cropTitle,
}) async {
  final image = await picker.pickImage(
    source: source,
    maxWidth: _maxEdge.toDouble(),
    maxHeight: _maxEdge.toDouble(),
    imageQuality: 85,
    requestFullMetadata: false,
  );
  if (image == null) return null;

  try {
    final cropped = await ImageCropper().cropImage(
      sourcePath: image.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 80,
      maxWidth: _maxEdge,
      maxHeight: _maxEdge,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: cropTitle,
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          statusBarLight: false,
          activeControlsWidgetColor: AppColors.primary,
          backgroundColor: Colors.black,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          aspectRatioPresets: const [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
          ],
        ),
        IOSUiSettings(
          title: cropTitle,
          aspectRatioPresets: const [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
          ],
        ),
      ],
    );
    if (cropped == null) return null;
    return cropped.readAsBytes();
  } catch (_) {
    return image.readAsBytes();
  }
}

/// Decodes [bytes] at display size so meal/food photos don't freeze the UI.
class CappedMemoryImage extends StatelessWidget {
  const CappedMemoryImage({
    super.key,
    required this.bytes,
    this.fit = BoxFit.cover,
  });

  final Uint8List bytes;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final cacheWidth = (width * dpr).round().clamp(1, _maxEdge);

    return Image(
      image: ResizeImage(
        MemoryImage(bytes),
        width: cacheWidth,
        policy: ResizeImagePolicy.fit,
      ),
      fit: fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFFE5E5EA),
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}
