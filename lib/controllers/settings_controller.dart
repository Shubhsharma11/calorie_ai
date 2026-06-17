import 'package:get/get.dart';

class SettingsController extends GetxController {
  final RxBool pushNotifications = true.obs;
  final RxBool mealReminders = true.obs;
  final RxBool waterReminders = true.obs;
  final RxBool weeklyReport = false.obs;
  final RxBool useMetricUnits = true.obs;

  void togglePushNotifications(bool value) => pushNotifications.value = value;

  void toggleMealReminders(bool value) => mealReminders.value = value;

  void toggleWaterReminders(bool value) => waterReminders.value = value;

  void toggleWeeklyReport(bool value) => weeklyReport.value = value;

  void toggleUseMetricUnits(bool value) => useMetricUnits.value = value;
}
