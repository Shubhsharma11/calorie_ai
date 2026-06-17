import 'package:get/get.dart';

import '../core/streak_calculator.dart';
import '../services/local_storage_service.dart';
import '../widgets/streak_milestone_dialog.dart';
import 'food_controller.dart';

class StreakController extends GetxController {
  StreakController({LocalStorageService? storage})
      : _storage = storage ?? LocalStorageService();

  final LocalStorageService _storage;

  final RxInt storedLongestStreak = 0.obs;
  final RxSet<int> celebratedMilestones = <int>{}.obs;
  final RxInt revision = 0.obs;

  late final Future<void> _ready;

  FoodController get _food => Get.find<FoodController>();

  StreakStats get stats {
    revision.value;
    return StreakCalculator.compute(
      _food.entries,
      storedLongest: storedLongestStreak.value,
    );
  }

  int get currentStreak => stats.currentStreak;
  int get longestStreak => stats.longestStreak;
  bool get hasLoggedToday => stats.hasLoggedToday;
  bool get isAtRisk => stats.isAtRisk;
  List<StreakDay> get recentDays => stats.recentDays;

  String get statusMessage {
    if (currentStreak == 0) {
      return 'Log a meal today to start your streak.';
    }
    if (hasLoggedToday) {
      return 'You logged today — streak secured!';
    }
    return 'Log a meal today to keep your $currentStreak-day streak alive.';
  }

  @override
  void onInit() {
    super.onInit();
    _ready = _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    storedLongestStreak.value = await _storage.loadLongestStreak();
    celebratedMilestones
      ..clear()
      ..addAll(await _storage.loadCelebratedMilestones());
    revision.value++;
  }

  Future<void> onMealsChanged() async {
    await _ready;

    final current = StreakCalculator.compute(
      _food.entries,
      storedLongest: storedLongestStreak.value,
    );

    if (current.longestStreak > storedLongestStreak.value) {
      storedLongestStreak.value = current.longestStreak;
      await _storage.saveLongestStreak(current.longestStreak);
    }

    revision.value++;
    await _maybeCelebrateMilestone(current.currentStreak);
  }

  Future<void> _maybeCelebrateMilestone(int streak) async {
    if (streak <= 0) return;

    for (final milestone in StreakMilestones.values) {
      if (streak < milestone) continue;
      if (celebratedMilestones.contains(milestone)) continue;

      celebratedMilestones.add(milestone);
      await _storage.saveCelebratedMilestones(celebratedMilestones);

      if (Get.isDialogOpen != true) {
        await StreakMilestoneDialog.show(days: milestone);
      }
      break;
    }
  }
}
