import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../controllers/user_controller.dart';

/// App-wide binding (user profile survives all routes).
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(UserController(), permanent: true);
    if (!Get.isRegistered<ThemeController>()) {
      Get.put(ThemeController(), permanent: true);
    }
  }
}
