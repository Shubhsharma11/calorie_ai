import 'meal_entry.dart';
import 'claimable_result.dart';

/// One day's step total (and derived calories burned).
class StepLogEntry {
  const StepLogEntry({
    this.id,
    required this.date,
    required this.steps,
    this.caloriesBurned,
  });

  final String? id;
  final DateTime date;
  final int steps;
  final int? caloriesBurned;

  DateTime get normalizedDate => MealEntry.normalizeDate(date);

  int get resolvedCaloriesBurned =>
      caloriesBurned ?? caloriesFromSteps(steps);

  static int caloriesFromSteps(int steps) => (steps * 0.04).round();
}

class StepLogResponse {
  const StepLogResponse({this.entry, this.coins});

  final StepLogEntry? entry;
  final ClaimableResult? coins;
}

/// Parsed GET /api/v1/steps response — daily step totals keyed by date.
class StepsFetchResult {
  const StepsFetchResult({
    this.entries = const [],
    this.stepsByDate = const {},
    this.caloriesByDate = const {},
  });

  final List<StepLogEntry> entries;
  final Map<DateTime, int> stepsByDate;
  final Map<DateTime, int> caloriesByDate;

  int stepsFor(DateTime date) =>
      stepsByDate[MealEntry.normalizeDate(date)] ?? 0;

  int caloriesFor(DateTime date) {
    final day = MealEntry.normalizeDate(date);
    final stored = caloriesByDate[day];
    if (stored != null && stored > 0) return stored;
    return StepLogEntry.caloriesFromSteps(stepsFor(day));
  }

  bool hasServerCalories(DateTime date) {
    final stored = caloriesByDate[MealEntry.normalizeDate(date)];
    return stored != null && stored > 0;
  }
}
