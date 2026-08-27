import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:calorie_ai/core/image_downscale.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('avatarUploadFilename detects png magic bytes', () {
    final png = Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47]);
    final jpg = Uint8List.fromList(const [0xFF, 0xD8, 0xFF]);
    expect(avatarUploadFilename(png), 'avatar.png');
    expect(avatarUploadMimeType(png), 'image/png');
    expect(avatarUploadFilename(jpg), 'avatar.jpg');
    expect(avatarUploadMimeType(jpg), 'image/jpeg');
  });

  test('downscaleImageBytes re-encodes oversized images as JPEG', () async {
    final source = img.Image(width: 1600, height: 1200);
    img.fill(source, color: img.ColorRgb8(40, 120, 200));
    final pngBytes = Uint8List.fromList(img.encodePng(source));

    final scaled = await downscaleImageBytes(pngBytes);

    expect(scaled[0], 0xFF);
    expect(scaled[1], 0xD8);
    expect(scaled[2], 0xFF);
    expect(uploadImageFilename(scaled), 'image.jpg');
    expect(scaled.lengthInBytes, lessThan(kUploadMaxBytes));

    final codec = await ui.instantiateImageCodec(scaled);
    final frame = await codec.getNextFrame();
    try {
      expect(frame.image.width, lessThanOrEqualTo(kAvatarMaxEdge));
      expect(frame.image.height, lessThanOrEqualTo(kAvatarMaxEdge));
    } finally {
      frame.image.dispose();
      codec.dispose();
    }
  });

  test('downscaleImageBytes keeps compact JPEG that already fits', () async {
    final source = img.Image(width: 400, height: 300);
    img.fill(source, color: img.ColorRgb8(10, 20, 30));
    final jpeg = Uint8List.fromList(img.encodeJpg(source, quality: 85));

    final scaled = await downscaleImageBytes(jpeg);

    expect(identical(scaled, jpeg), isTrue);
    expect(scaled[0], 0xFF);
    expect(scaled[1], 0xD8);
  });
}
