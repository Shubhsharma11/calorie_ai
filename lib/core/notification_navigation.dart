import 'package:get/get.dart';

import '../controllers/food_controller.dart';
import '../models/notification_model.dart';
import '../routes/app_routes.dart';

/// Applies route-specific state before opening a notification destination.
void prepareNotificationNavigation(NotificationModel model) {
  if (model.route != AppRoutes.addFood) return;

  final meal = model.targetMeal;
  if (!Get.isRegistered<FoodController>()) return;

  final food = Get.find<FoodController>();
  food.prepareForNewMeal();
  if (meal != null) {
    food.setSelectedMeal(meal);
  }
}
