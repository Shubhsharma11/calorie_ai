import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../models/activity_level.dart';
import '../models/goal_type.dart';
import '../models/user_model.dart';
import '../routes/app_routes.dart';
import '../services/local_storage_service.dart';
import 'dashboard_controller.dart';
import 'tracker_controller.dart';

class UserController extends GetxController {
  UserController({LocalStorageService? storage})
      : _storage = storage ?? LocalStorageService();

  final user = UserModel();
  final _imagePicker = ImagePicker();
  final LocalStorageService _storage;

  static const int calorieStep = 50;
  static const int minDailyCalories = 1200;
  static const int maxDailyCalories = 4000;

  @override
  void onInit() {
    super.onInit();
    _loadCalorieAdjustment();
  }

  Future<void> _loadCalorieAdjustment() async {
    user.manualCalorieAdjustment = await _storage.loadCalorieAdjustment();
    update();
  }

  Future<void> _persistCalorieAdjustment() async {
    await _storage.saveCalorieAdjustment(user.manualCalorieAdjustment);
  }

  Future<void> pickProfilePhoto(ImageSource source) async {
    final file = await _imagePicker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    user.profilePhotoBytes = await file.readAsBytes();
    update();
  }

  void removeProfilePhoto() {
    user.profilePhotoBytes = null;
    update();
  }

  Future<void> showProfilePhotoOptions(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            if (user.profilePhotoBytes != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  removeProfilePhoto();
                },
              ),
          ],
        ),
      ),
    );
    if (source != null) await pickProfilePhoto(source);
  }

  void selectGoal(GoalType goal) {
    user.goal = goal;
    if (goal == GoalType.maintainWeight) {
      user.manualGoalWeightKg = null;
    } else {
      user.manualGoalWeightKg = null;
    }
    update();
  }

  /// Sets [user.goal] from how [targetKg] compares to current weight.
  void inferGoalFromWeight(double targetKg) {
    final current = user.weightKg.toDouble();
    final diff = targetKg - current;
    if (diff.abs() < 0.1) {
      user.goal = GoalType.maintainWeight;
      user.manualGoalWeightKg = null;
    } else if (diff < 0) {
      user.goal = GoalType.loseWeight;
    } else {
      user.goal = GoalType.gainWeight;
    }
    update();
  }

  void setGoalWeight(double kg, {required bool manual}) {
    if (manual) {
      user.manualGoalWeightKg = kg.clamp(40.0, 200.0);
    } else {
      user.manualGoalWeightKg = null;
    }
    update();
  }

  void useRecommendedGoalWeight() {
    user.manualGoalWeightKg = null;
    update();
  }

  void onProfileUpdated() {
    if (user.goal == GoalType.maintainWeight) {
      user.manualGoalWeightKg = null;
    }
    update();
  }

  void syncWeightFromProfile() {
    if (Get.isRegistered<TrackerController>()) {
      Get.find<TrackerController>().updateWeight(user.weightKg.toDouble());
    }
  }

  Future<void> pickTargetDate(BuildContext context) async {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: user.targetDate.isBefore(today) ? today : user.targetDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    user.targetDate = DateTime(picked.year, picked.month, picked.day);
    update();
  }

  void selectActivity(ActivityLevel level) {
    user.activityLevel = level;
    update();
  }

  void adjustCalorieGoal(int delta) {
    final calculated = user.calculatedDailyCalorieGoal;
    final target =
        (user.dailyCalorieGoal + delta).clamp(minDailyCalories, maxDailyCalories);
    user.manualCalorieAdjustment = target - calculated;
    update();
    _persistCalorieAdjustment();
    _notifyDashboard();
  }

  void resetCalorieAdjustment() {
    user.manualCalorieAdjustment = 0;
    update();
    _persistCalorieAdjustment();
    _notifyDashboard();
  }

  void finishSetup() {
    Get.offAllNamed(AppRoutes.dailyCalorieGoal);
  }

  void completeOnboarding() {
    _notifyDashboard();
    Get.offAllNamed(AppRoutes.main);
  }

  void notifyGoalConsumers() => _notifyDashboard();

  void _notifyDashboard() {
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().update();
    }
  }

  void logout() {
    user.profilePhotoBytes = null;
    Get.offAllNamed(AppRoutes.login);
  }
}
