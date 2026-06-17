import 'package:get/get.dart';

import '../models/daily_water_intake.dart';
import '../models/meal_entry.dart';
import '../models/water_period.dart';
import '../widgets/water_goal_success_dialog.dart';

class TrackerController extends GetxController {
  TrackerController({double? initialWeight}) {
    if (initialWeight != null) {
      currentWeight.value = initialWeight;
    }
  }

  final RxMap<DateTime, int> waterByDate = <DateTime, int>{}.obs;
  final Rx<WaterPeriod> waterPeriod = WaterPeriod.week.obs;

  final RxDouble currentWeight = 70.0.obs;
  final RxInt steps = 0.obs;
  final RxInt caloriesBurned = 0.obs;

  static const int waterGoal = 8;

  bool _waterGoalCelebrationShown = false;

  DateTime get _today => MealEntry.normalizeDate(DateTime.now());

  int get waterGlasses => waterForDate(_today);

  double get waterProgress =>
      (waterGlasses / waterGoal).clamp(0.0, 1.0);

  bool get isWaterGoalComplete => waterGlasses >= waterGoal;

  int waterForDate(DateTime date) =>
      waterByDate[MealEntry.normalizeDate(date)] ?? 0;

  List<DailyWaterIntake> waterForLastDays(int dayCount) {
    final today = _today;
    return List.generate(dayCount, (index) {
      final day = today.subtract(Duration(days: dayCount - 1 - index));
      return DailyWaterIntake(date: day, glasses: waterForDate(day));
    });
  }

  List<DailyWaterIntake> get activeWaterDays => switch (waterPeriod.value) {
        WaterPeriod.today => [
            DailyWaterIntake(date: _today, glasses: waterGlasses),
          ],
        WaterPeriod.yesterday => [
            DailyWaterIntake(
              date: _today.subtract(const Duration(days: 1)),
              glasses: waterForDate(
                _today.subtract(const Duration(days: 1)),
              ),
            ),
          ],
        WaterPeriod.week => waterForLastDays(7),
        WaterPeriod.month => waterForLastDays(30),
      };

  void setWaterPeriod(WaterPeriod period) => waterPeriod.value = period;

  String periodLabelFor(WaterPeriod period) => switch (period) {
        WaterPeriod.today => 'Today',
        WaterPeriod.yesterday => 'Yesterday',
        WaterPeriod.week => '7 Days',
        WaterPeriod.month => '30 Days',
      };

  void addWater() {
    final today = _today;
    final current = waterForDate(today);
    if (current >= waterGoal) return;

    waterByDate[today] = current + 1;
    waterByDate.refresh();

    if (isWaterGoalComplete && !_waterGoalCelebrationShown) {
      _waterGoalCelebrationShown = true;
      WaterGoalSuccessDialog.show();
    }
  }

  void removeWater() {
    final today = _today;
    final current = waterForDate(today);
    if (current <= 0) return;

    final next = current - 1;
    if (next <= 0) {
      waterByDate.remove(today);
    } else {
      waterByDate[today] = next;
    }
    waterByDate.refresh();

    if (!isWaterGoalComplete) {
      _waterGoalCelebrationShown = false;
    }
  }

  void updateWeight(double kg) => currentWeight.value = kg;

  void syncActivity() {
    // Placeholder for Google Fit / Apple Health integration.
    steps.value = 6420;
    caloriesBurned.value = 320;
  }
}
