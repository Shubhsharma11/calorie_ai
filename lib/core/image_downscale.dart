import 'dart:typed_data';
import 'dart:ui' as ui;

const kAvatarMaxEdge = 1080;

/// Decodes [bytes] already scaled so the longest edge is [maxEdge], then
/// re-encodes as PNG. Images that already fit are returned unchanged so a
/// gallery JPEG is not inflated into a large PNG.
///
/// [ui.ImageDescriptor] reads dimensions without a full-resolution bitmap,
/// which is what OOMs Android after the system camera returns.
Future<Uint8List> downscaleImageBytes(
  Uint8List bytes, {
  int maxEdge = kAvatarMaxEdge,
}) async {
  if (bytes.isEmpty) return bytes;

  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final width = descriptor.width;
    final height = descriptor.height;
    if (width <= 0 || height <= 0) return bytes;
    if (width <= maxEdge && height <= maxEdge) return bytes;

    final targetWidth = width >= height ? maxEdge : null;
    final targetHeight = height > width ? maxEdge : null;
    codec = await descriptor.instantiateCodec(
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final frame = await codec.getNextFrame();
    image = frame.image;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) return bytes;
    return png.buffer.asUint8List();
  } catch (_) {
    if (bytes.lengthInBytes <= 1024 * 1024) return bytes;
    rethrow;
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

bool _isPng(Uint8List bytes) =>
    bytes.length >= 4 &&
    bytes[0] == 0x89 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x4E &&
    bytes[3] == 0x47;

String avatarUploadFilename(Uint8List bytes) =>
    uploadImageFilename(bytes, basename: 'avatar');

/// Multipart Content-Type. Without this the http package sends
/// `application/octet-stream`, which S3 stores as-is so admin/browser
/// `<img>` tags cannot display the photo even though upload returned 200.
String avatarUploadMimeType(Uint8List bytes) => uploadImageMimeType(bytes);

String uploadImageFilename(Uint8List bytes, {String basename = 'image'}) =>
    _isPng(bytes) ? '$basename.png' : '$basename.jpg';

String uploadImageMimeType(Uint8List bytes) =>
    _isPng(bytes) ? 'image/png' : 'image/jpeg';

String uploadImageMimeTypeForFilename(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}
