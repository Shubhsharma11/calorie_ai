import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/app_routes.dart';
import 'user_controller.dart';

class AuthController extends GetxController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  void login() {
    final user = Get.find<UserController>();
    user.user.email = emailController.text.trim();
    if (nameController.text.isNotEmpty) {
      user.user.name = nameController.text.trim();
    }
    Get.offAllNamed(AppRoutes.personalDetails);
  }

  void register() {
    final user = Get.find<UserController>();
    user.user.name = nameController.text.trim();
    user.user.email = emailController.text.trim();
    user.update();
    Get.offAllNamed(AppRoutes.personalDetails);
  }

  void loginWithGoogle() => login();

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose(); 
    nameController.dispose();
    super.onClose();
  }
}
