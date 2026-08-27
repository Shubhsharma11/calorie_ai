import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Always false: Android gallery uses the system Photo Picker (no storage grant).
bool galleryNeedsStoragePermission(int _) => false;

String photoPermissionDeniedMessage(ImageSource source) {
  if (source == ImageSource.camera) {
    return 'Camera permission is required to take a photo.';
  }
  return 'Photo access is required to choose an image.';
}

/// Requests camera or (on iOS) photos permission for [source].
///
/// Android gallery uses the system Photo Picker and does not need a grant.
Future<bool> ensureImageSourcePermission(
  ImageSource source, {
  Future<PermissionStatus> Function(Permission permission)? request,
}) async {
  Future<PermissionStatus> requestPermission(Permission permission) {
    if (request != null) return request(permission);
    return permission.request();
  }

  if (source == ImageSource.camera) {
    final status = await requestPermission(Permission.camera);
    return status.isGranted;
  }

  if (kIsWeb) return true;

  if (defaultTargetPlatform == TargetPlatform.iOS) {
    final status = await requestPermission(Permission.photos);
    return status.isGranted || status.isLimited;
  }

  // Android: Photo Picker — no READ_MEDIA_* / storage permission needed.
  return true;
}
