import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

const kAvatarMaxEdge = 1080;

/// Stay under typical nginx `client_max_body_size` (often 1 MB).
const kUploadMaxBytes = 900 * 1024;

const kUploadJpegQuality = 85;

/// Decodes [bytes] already scaled so the longest edge is [maxEdge], then
/// re-encodes as JPEG. Compact JPEGs that already fit are returned unchanged
/// so we do not inflate them. Oversized or PNG inputs are always JPEG-encoded
/// so photo uploads stay under nginx body limits (413s).
///
/// [ui.ImageDescriptor] reads dimensions without a full-resolution bitmap,
/// which is what OOMs Android after the system camera returns.
Future<Uint8List> downscaleImageBytes(
  Uint8List bytes, {
  int maxEdge = kAvatarMaxEdge,
  int maxBytes = kUploadMaxBytes,
  int quality = kUploadJpegQuality,
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

    final fits = width <= maxEdge && height <= maxEdge;
    if (fits &&
        bytes.lengthInBytes <= maxBytes &&
        !_isPng(bytes) &&
        _isJpeg(bytes)) {
      return bytes;
    }

    final needsResize = !fits;
    codec = await descriptor.instantiateCodec(
      targetWidth: needsResize && width >= height ? maxEdge : null,
      targetHeight: needsResize && height > width ? maxEdge : null,
    );
    final frame = await codec.getNextFrame();
    image = frame.image;
    // dart:ui only encodes PNG; convert the already-scaled frame to JPEG
    // so meal/avatar uploads stay under nginx body limits.
    final pngData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (pngData == null) return bytes;
    final decoded = img.decodeImage(
      pngData.buffer.asUint8List(
        pngData.offsetInBytes,
        pngData.lengthInBytes,
      ),
    );
    if (decoded == null) return bytes;

    var q = quality.clamp(40, 95);
    var encoded = Uint8List.fromList(img.encodeJpg(decoded, quality: q));
    while (encoded.lengthInBytes > maxBytes && q > 40) {
      q -= 10;
      encoded = Uint8List.fromList(img.encodeJpg(decoded, quality: q));
    }
    return encoded;
  } catch (_) {
    if (bytes.lengthInBytes <= maxBytes) return bytes;
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

bool _isJpeg(Uint8List bytes) =>
    bytes.length >= 3 &&
    bytes[0] == 0xFF &&
    bytes[1] == 0xD8 &&
    bytes[2] == 0xFF;

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
