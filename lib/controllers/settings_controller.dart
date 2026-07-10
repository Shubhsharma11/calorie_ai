import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MealReminderSlot { breakfast, lunch, dinner }

class SettingsController extends GetxController {
  static const _pushNotificationsKey = 'settings_push_notifications';
  static const _mealRemindersKey = 'settings_meal_reminders';
  static const _waterRemindersKey = 'settings_water_reminders';
  static const _goalProgressAlertsKey = 'settings_goal_progress_alerts';
  static const _streakRemindersKey = 'settings_streak_reminders';
  static const _weeklyReportKey = 'settings_weekly_report';
  static const _appUpdatesKey = 'settings_app_updates';
  static const _useMetricUnitsKey = 'settings_use_metric_units';
  static const _breakfastReminderKey = 'settings_breakfast_reminder';
  static const _lunchReminderKey = 'settings_lunch_reminder';
  static const _dinnerReminderKey = 'settings_dinner_reminder';
  static const _waterIntervalHoursKey = 'settings_water_interval_hours';
  static const _waterGoalGlassesKey = 'settings_water_goal_glasses';
  static const _waterGoalMlKey = 'settings_water_goal_ml';

  static const int mlPerGlass = 250;
  static const int defaultWaterGoalMl = 2000;
  static const List<int> waterGoalMlOptions = [1500, 2000, 2500, 3000];

  final RxBool pushNotifications = true.obs;
  final RxBool mealReminders = true.obs;
  final RxBool waterReminders = true.obs;
  final RxBool goalProgressAlerts = true.obs;
  final RxBool streakReminders = true.obs;
  final RxBool weeklyReport = false.obs;
  final RxBool appUpdates = false.obs;
  final RxBool useMetricUnits = true.obs;

  final Rx<TimeOfDay> breakfastReminder = const TimeOfDay(
    hour: 8,
    minute: 0,
  ).obs;
  final Rx<TimeOfDay> lunchReminder = const TimeOfDay(hour: 13, minute: 0).obs;
  final Rx<TimeOfDay> dinnerReminder = const TimeOfDay(
    hour: 19,
    minute: 30,
  ).obs;
  final RxInt waterReminderIntervalHours = 2.obs;
  final RxInt waterGoalMl = defaultWaterGoalMl.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    pushNotifications.value = prefs.getBool(_pushNotificationsKey) ?? true;
    mealReminders.value = prefs.getBool(_mealRemindersKey) ?? true;
    waterReminders.value = prefs.getBool(_waterRemindersKey) ?? true;
    goalProgressAlerts.value = prefs.getBool(_goalProgressAlertsKey) ?? true;
    streakReminders.value = prefs.getBool(_streakRemindersKey) ?? true;
    weeklyReport.value = prefs.getBool(_weeklyReportKey) ?? false;
    appUpdates.value = prefs.getBool(_appUpdatesKey) ?? false;
    useMetricUnits.value = prefs.getBool(_useMetricUnitsKey) ?? true;
    breakfastReminder.value = _timeFromMinutes(
      prefs.getInt(_breakfastReminderKey),
      fallback: breakfastReminder.value,
    );
    lunchReminder.value = _timeFromMinutes(
      prefs.getInt(_lunchReminderKey),
      fallback: lunchReminder.value,
    );
    dinnerReminder.value = _timeFromMinutes(
      prefs.getInt(_dinnerReminderKey),
      fallback: dinnerReminder.value,
    );
    waterReminderIntervalHours.value =
        (prefs.getInt(_waterIntervalHoursKey) ?? 2).clamp(1, 4);
    waterGoalMl.value = _resolveWaterGoalMl(prefs);
  }

  /// Reads the ml goal, migrating from the legacy glasses setting if needed.
  int _resolveWaterGoalMl(SharedPreferences prefs) {
    final storedMl = prefs.getInt(_waterGoalMlKey);
    if (storedMl != null) return _normalizeWaterGoalMl(storedMl);

    final legacyGlasses = prefs.getInt(_waterGoalGlassesKey);
    if (legacyGlasses != null) {
      return _normalizeWaterGoalMl(legacyGlasses * mlPerGlass);
    }
    return defaultWaterGoalMl;
  }

  Future<void> togglePushNotifications(bool value) async {
    pushNotifications.value = value;
    await _saveBool(_pushNotificationsKey, value);
  }

  Future<void> toggleMealReminders(bool value) async {
    mealReminders.value = value;
    await _saveBool(_mealRemindersKey, value);
  }

  Future<void> toggleWaterReminders(bool value) async {
    waterReminders.value = value;
    await _saveBool(_waterRemindersKey, value);
  }

  Future<void> toggleGoalProgressAlerts(bool value) async {
    goalProgressAlerts.value = value;
    await _saveBool(_goalProgressAlertsKey, value);
  }

  Future<void> toggleStreakReminders(bool value) async {
    streakReminders.value = value;
    await _saveBool(_streakRemindersKey, value);
  }

  Future<void> toggleWeeklyReport(bool value) async {
    weeklyReport.value = value;
    await _saveBool(_weeklyReportKey, value);
  }

  Future<void> toggleAppUpdates(bool value) async {
    appUpdates.value = value;
    await _saveBool(_appUpdatesKey, value);
  }

  Future<void> toggleUseMetricUnits(bool value) async {
    useMetricUnits.value = value;
    await _saveBool(_useMetricUnitsKey, value);
  }

  Future<void> setMealReminderTime(
    MealReminderSlot slot,
    TimeOfDay time,
  ) async {
    final key = switch (slot) {
      MealReminderSlot.breakfast => _breakfastReminderKey,
      MealReminderSlot.lunch => _lunchReminderKey,
      MealReminderSlot.dinner => _dinnerReminderKey,
    };
    switch (slot) {
      case MealReminderSlot.breakfast:
        breakfastReminder.value = time;
      case MealReminderSlot.lunch:
        lunchReminder.value = time;
      case MealReminderSlot.dinner:
        dinnerReminder.value = time;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, _minutesFromTime(time));
  }

  Future<void> setWaterReminderInterval(int hours) async {
    waterReminderIntervalHours.value = hours.clamp(1, 4);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _waterIntervalHoursKey,
      waterReminderIntervalHours.value,
    );
  }

  Future<void> setWaterGoalMl(int ml) async {
    waterGoalMl.value = _normalizeWaterGoalMl(ml);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_waterGoalMlKey, waterGoalMl.value);
  }

  String get waterGoalSummary {
    final ml = waterGoalMl.value;
    final glasses = (ml / mlPerGlass).round();
    return '$ml ml per day (~$glasses glasses)';
  }

  String formatTime(BuildContext context, TimeOfDay time) {
    return time.format(context);
  }

  String get mealReminderSummary {
    final breakfast = _formatTimeValue(breakfastReminder.value);
    final lunch = _formatTimeValue(lunchReminder.value);
    final dinner = _formatTimeValue(dinnerReminder.value);
    return '$breakfast, $lunch, $dinner';
  }

  String get waterIntervalSummary {
    final hours = waterReminderIntervalHours.value;
    return hours == 1 ? 'Every hour' : 'Every $hours hours';
  }

  int _normalizeWaterGoalMl(int ml) {
    if (waterGoalMlOptions.contains(ml)) return ml;
    // Snap unknown values to the closest preset.
    var closest = defaultWaterGoalMl;
    var bestDistance = (ml - closest).abs();
    for (final option in waterGoalMlOptions) {
      final distance = (ml - option).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        closest = option;
      }
    }
    return closest;
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  TimeOfDay _timeFromMinutes(int? minutes, {required TimeOfDay fallback}) {
    if (minutes == null) return fallback;
    final clamped = minutes.clamp(0, 1439);
    return TimeOfDay(hour: clamped ~/ 60, minute: clamped % 60);
  }

  int _minutesFromTime(TimeOfDay time) => time.hour * 60 + time.minute;

  String _formatTimeValue(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
