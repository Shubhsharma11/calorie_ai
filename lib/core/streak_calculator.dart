import '../models/meal_entry.dart';

/// A single day in the streak calendar.
class StreakDay {
  const StreakDay({
    required this.date,
    required this.logged,
    required this.partOfCurrentStreak,
  });

  final DateTime date;
  final bool logged;
  final bool partOfCurrentStreak;

  bool get isToday {
    final today = MealEntry.normalizeDate(DateTime.now());
    return date == today;
  }
}

/// Aggregated streak metrics derived from logged meal dates.
class StreakStats {
  const StreakStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.hasLoggedToday,
    required this.isAtRisk,
    required this.recentDays,
  });

  final int currentStreak;
  final int longestStreak;
  final bool hasLoggedToday;
  final bool isAtRisk;
  final List<StreakDay> recentDays;

  static const empty = StreakStats(
    currentStreak: 0,
    longestStreak: 0,
    hasLoggedToday: false,
    isAtRisk: false,
    recentDays: [],
  );
}

/// Milestone thresholds that trigger celebrations.
abstract final class StreakMilestones {
  static const values = [3, 7, 14, 30, 60, 100];

  static int? reachedBy(int streak) {
    for (final milestone in values.reversed) {
      if (streak >= milestone) return milestone;
    }
    return null;
  }
}

/// Pure streak logic — no side effects, easy to unit test.
abstract final class StreakCalculator {
  static Set<DateTime> loggedDatesFrom(Iterable<MealEntry> entries) {
    return entries.map((e) => e.date).toSet();
  }

  static int computeCurrentStreak(
    Set<DateTime> loggedDates, {
    DateTime? asOf,
  }) {
    if (loggedDates.isEmpty) return 0;

    final today = MealEntry.normalizeDate(asOf ?? DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));

    final DateTime? anchor;
    if (loggedDates.contains(today)) {
      anchor = today;
    } else if (loggedDates.contains(yesterday)) {
      anchor = yesterday;
    } else {
      return 0;
    }

    var streak = 0;
    var day = anchor;
    while (loggedDates.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static int computeLongestStreak(Set<DateTime> loggedDates) {
    if (loggedDates.isEmpty) return 0;

    final sorted = loggedDates.toList()..sort();
    var longest = 1;
    var current = 1;

    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].difference(sorted[i - 1]).inDays == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  static bool hasLoggedOn(
    Set<DateTime> loggedDates, {
    required DateTime day,
  }) =>
      loggedDates.contains(MealEntry.normalizeDate(day));

  static List<StreakDay> buildRecentDays(
    Set<DateTime> loggedDates, {
    int dayCount = 30,
    DateTime? asOf,
  }) {
    final today = MealEntry.normalizeDate(asOf ?? DateTime.now());
    final currentStreak = computeCurrentStreak(loggedDates, asOf: today);

    DateTime? streakEnd;
    if (loggedDates.contains(today)) {
      streakEnd = today;
    } else if (loggedDates.contains(
      today.subtract(const Duration(days: 1)),
    )) {
      streakEnd = today.subtract(const Duration(days: 1));
    }

    final streakStart = streakEnd != null && currentStreak > 0
        ? streakEnd.subtract(Duration(days: currentStreak - 1))
        : null;

    return List.generate(dayCount, (index) {
      final day = today.subtract(Duration(days: dayCount - 1 - index));
      final logged = loggedDates.contains(day);
      final inStreak = streakStart != null &&
          streakEnd != null &&
          !day.isBefore(streakStart) &&
          !day.isAfter(streakEnd);

      return StreakDay(
        date: day,
        logged: logged,
        partOfCurrentStreak: logged && inStreak,
      );
    });
  }

  static StreakStats compute(
    Iterable<MealEntry> entries, {
    int calendarDays = 30,
    int storedLongest = 0,
    DateTime? asOf,
  }) {
    final dates = loggedDatesFrom(entries);
    if (dates.isEmpty) {
      return StreakStats(
        currentStreak: 0,
        longestStreak: storedLongest,
        hasLoggedToday: false,
        isAtRisk: false,
        recentDays: buildRecentDays(dates, dayCount: calendarDays, asOf: asOf),
      );
    }

    final today = MealEntry.normalizeDate(asOf ?? DateTime.now());
    final current = computeCurrentStreak(dates, asOf: today);
    final computedLongest = computeLongestStreak(dates);
    final longest = computedLongest > storedLongest
        ? computedLongest
        : storedLongest;
    final hasLoggedToday = dates.contains(today);
    final isAtRisk = current > 0 && !hasLoggedToday;

    return StreakStats(
      currentStreak: current,
      longestStreak: longest,
      hasLoggedToday: hasLoggedToday,
      isAtRisk: isAtRisk,
      recentDays: buildRecentDays(dates, dayCount: calendarDays, asOf: asOf),
    );
  }
}
