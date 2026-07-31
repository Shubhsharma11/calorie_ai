import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:calorie_ai/controllers/theme_controller.dart';
import 'package:calorie_ai/main.dart';
import 'package:calorie_ai/routes/app_routes.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('App opens onboarding when logged out', (WidgetTester tester) async {
    Get.put(ThemeController(), permanent: true);
    await tester.pumpWidget(
      const FitBuddyAiApp(initialRoute: AppRoutes.onboarding),
    );
    await tester.pump();

    expect(find.text('Eat Healthy Live Healthy'), findsOneWidget);
  });
}
