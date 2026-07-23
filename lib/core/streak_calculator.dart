import '../models/meal_entry.dart';

/// A single day in the streak calendar.
class StreakDay {
  const StreakDay({
    required this.date,
    required this.logged,
    required this.partOfCurrentStreak,
    this.isMissed = false,
  });

  final DateTime date;
  final bool logged;
  final bool partOfCurrentStreak;
  final bool isMissed;

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

  /// True when the user had past logs but the streak is currently broken.
  bool get streakBroken =>
      currentStreak == 0 &&
      recentDays.any((day) => day.logged && day.date.isBefore(_yesterday));

  static DateTime get _yesterday =>
      MealEntry.normalizeDate(DateTime.now())
          .subtract(const Duration(days: 1));

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

  /// Reconstructs logged days when the API returns counts without a date list.
  static Set<DateTime> inferLoggedDatesFromStreak({
    required int currentStreak,
    required bool hasLoggedToday,
    DateTime? asOf,
  }) {
    if (currentStreak <= 0) return {};

    final today = MealEntry.normalizeDate(asOf ?? DateTime.now());
    final end = hasLoggedToday
        ? today
        : today.subtract(const Duration(days: 1));

    return {
      for (var i = 0; i < currentStreak; i++)
        end.subtract(Duration(days: i)),
    };
  }

  static bool computeStreakBroken(
    Set<DateTime> loggedDates, {
    DateTime? asOf,
  }) {
    if (loggedDates.isEmpty) return false;
    if (computeCurrentStreak(loggedDates, asOf: asOf) > 0) return false;

    final today = MealEntry.normalizeDate(asOf ?? DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    return loggedDates.any((day) => day.isBefore(yesterday));
  }

  static List<StreakDay> buildRecentDays(
    Set<DateTime> loggedDates, {
    int dayCount = 30,
    DateTime? asOf,
    int? currentStreakOverride,
  }) {
    final today = MealEntry.normalizeDate(asOf ?? DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final currentStreak = currentStreakOverride ??
        computeCurrentStreak(loggedDates, asOf: today);

    DateTime? streakEnd;
    if (currentStreak > 0) {
      if (loggedDates.contains(today)) {
        streakEnd = today;
      } else if (loggedDates.contains(yesterday) ||
          currentStreakOverride != null) {
        streakEnd = yesterday;
      }
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
        isMissed: !logged && day.isBefore(today),
      );
    });
  }

  static StreakStats compute(
    Iterable<MealEntry> entries, {
    int calendarDays = 30,
    int storedLongest = 0,
    DateTime? asOf,
  }) { 
    return computeFromDates(
      loggedDatesFrom(entries),
      calendarDays: calendarDays,
      storedLongest: storedLongest,
      asOf: asOf,
    );
  }

  static StreakStats computeFromDates(
    Set<DateTime> dates, {
    int calendarDays = 30,
    int storedLongest = 0,
    DateTime? asOf,
  }) {
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
