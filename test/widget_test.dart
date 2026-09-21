import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:calorie_ai/controllers/onboarding_controller.dart';
import 'package:calorie_ai/controllers/theme_controller.dart';
import 'package:calorie_ai/theme/app_theme.dart';
import 'package:calorie_ai/views/onboarding_view.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('App opens onboarding when logged out', (WidgetTester tester) async {
    Get.put(ThemeController(), permanent: true);
    Get.put(OnboardingController());

    // Pump OnboardingView directly — FitBuddyAiApp requires Firebase in tests.
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        home: const OnboardingView(),
      ),
    );
    await tester.pump();

    // Current onboarding hero copy (first page).
    expect(find.textContaining('Meet Your'), findsOneWidget);
    expect(find.textContaining('Smart Coach'), findsOneWidget);
    expect(find.text('Next →'), findsOneWidget);
  });
}
