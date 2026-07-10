import 'dart:async';

import 'package:get/get.dart';

import '../controllers/tracker_controller.dart';
import '../controllers/user_controller.dart';
import '../services/notification_service.dart';

class MainController extends GetxController {
  final RxInt tabIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(_uploadFcmTokenOnHome());
  }

  Future<void> _uploadFcmTokenOnHome() async {
    if (!Get.isRegistered<UserController>()) return;

    final userController = Get.find<UserController>();
    if (!userController.isLoggedIn || userController.accessToken.isEmpty) {
      return;
    }

    await NotificationService.instance.syncTokenWithBackend(
      accessToken: userController.accessToken,
    );

    if (Get.isRegistered<TrackerController>()) {
      await Get.find<TrackerController>().refreshWaterFromApi();
    }
  }

  void changeTab(int index) => tabIndex.value = index;

  void resetToHomeTab() => tabIndex.value = 0;

  static void resetHomeTabIfRegistered() {
    if (Get.isRegistered<MainController>()) {
      Get.find<MainController>().resetToHomeTab();
    }
  }
}
