import 'dart:async';

import 'package:get/get.dart';

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
  }

  void changeTab(int index) => tabIndex.value = index;
}
