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
}
