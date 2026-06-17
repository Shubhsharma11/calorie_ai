import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:calorie_ai/main.dart';

void main() {
  testWidgets('App loads log screen', (WidgetTester tester) async {
    await tester.pumpWidget(const CalorieAiApp());
    await tester.pumpAndSettle();

    expect(find.text('Log'), findsOneWidget);
    expect(find.text('Calories'), findsOneWidget);

    Get.reset();
  });
}
