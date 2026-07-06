import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../controllers/user_controller.dart';

/// App-wide binding (user profile survives all routes).
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<UserController>()) {
      Get.put(UserController(), permanent: true);
    }
    if (!Get.isRegistered<ThemeController>()) {
      Get.put(ThemeController(), permanent: true);
    }
  }
}
