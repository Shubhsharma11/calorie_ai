import 'dart:typed_data';

import 'package:calorie_ai/core/image_downscale.dart';
import 'package:calorie_ai/core/wait_for_resume.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('waitForAppResumed is true in tests', (tester) async {
    final ok = await waitForAppResumed(
      extraDelay: Duration.zero,
      extraFrames: 0,
    );
    expect(ok, isTrue);
    expect(isAppResumed, isTrue);
  });

  test('avatarUploadFilename detects png magic bytes', () {
    final png = Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47]);
    final jpg = Uint8List.fromList(const [0xFF, 0xD8, 0xFF]);
    expect(avatarUploadFilename(png), 'avatar.png');
    expect(avatarUploadMimeType(png), 'image/png');
    expect(avatarUploadFilename(jpg), 'avatar.jpg');
    expect(avatarUploadMimeType(jpg), 'image/jpeg');
  });
}
