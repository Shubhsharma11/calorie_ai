import '../core/api_timezone.dart';
import '../services/coins_api_service.dart';
import 'claimable_result.dart';
import 'meal_entry.dart';
import 'step_log_entry.dart';

/// Maps backend steps payloads to [StepLogEntry] and daily totals.
abstract final class ApiStepsMapper {
  static List<StepLogEntry> entriesFromResponse(
    Map<String, dynamic> json, {
    DateTime? fallbackDate,
  }) {
    final rawData = json['data'];
    if (rawData is List) {
      return _entriesFromMaps(rawData, fallbackDate: fallbackDate);
    }

    final data = _unwrapData(json);
    final items = _readEntryMaps(data);
    if (items.isNotEmpty) {
      return _entriesFromMaps(items, fallbackDate: fallbackDate);
    }

    final nested = data['stepEntry'] ?? data['entry'];
    if (nested is Map) {
      final parsed = entryFromApiJson(
        Map<String, dynamic>.from(nested),
        fallbackDate: fallbackDate,
      );
      if (parsed != null) return [parsed];
    }

    final single = entryFromApiJson(data, fallbackDate: fallbackDate);
    if (single != null) return [single];
    return const [];
  }

  static StepsFetchResult fetchResultFromResponse(
    Map<String, dynamic> json, {
    DateTime? fallbackDate,
  }) {
    final data = _unwrapData(json);
    final entries = entriesFromResponse(json, fallbackDate: fallbackDate);
    final totals = <DateTime, int>{};
    final calories = <DateTime, int>{};

    for (final entry in entries) {
      totals[entry.normalizedDate] = entry.steps;
      final cals = entry.caloriesBurned;
      if (cals != null && cals > 0) {
        calories[entry.normalizedDate] = cals;
      }
    }

    final dailySteps = _readInt(
      data['steps'] ??
          data['dailySteps'] ??
          data['daily_steps'] ??
          data['totalSteps'] ??
          data['total_steps'],
    );
    final dateKey =
        _readDate(data['date']) ?? _readDate(data['day']) ?? fallbackDate;
    if (dailySteps != null && dateKey != null && entries.isEmpty) {
      final day = MealEntry.normalizeDate(dateKey);
      totals[day] = dailySteps;
      final cals = _readInt(
        data['caloriesBurned'] ??
            data['calories_burned'] ??
            data['totalCaloriesBurned'],
      );
      if (cals != null && cals > 0) {
        calories[day] = cals;
      }
    }

    final meta = data['meta'];
    if (meta is Map) {
      final metaMap = Map<String, dynamic>.from(meta);
      final metaDate =
          _readDate(metaMap['date']) ??
          _readDate(metaMap['day']) ??
          fallbackDate;
      final metaSteps = _readInt(
        metaMap['totalSteps'] ?? metaMap['total_steps'] ?? metaMap['steps'],
      );
      final metaCals = _readInt(
        metaMap['totalCaloriesBurned'] ??
            metaMap['total_calories_burned'] ??
            metaMap['caloriesBurned'] ??
            metaMap['calories_burned'],
      );
      if (metaDate != null) {
        final day = MealEntry.normalizeDate(metaDate);
        if (metaSteps != null && !totals.containsKey(day)) {
          totals[day] = metaSteps;
        }
        if (metaCals != null && metaCals > 0) {
          calories[day] = metaCals;
        }
      }
    }

    return StepsFetchResult(
      entries: entries,
      stepsByDate: totals,
      caloriesByDate: calories,
    );
  }

  static StepLogResponse logResponseFromJson(Map<String, dynamic> json) {
    final data = _unwrapData(json);
    final nested = data['stepEntry'] ?? data['entry'];
    final entry = nested is Map
        ? entryFromApiJson(Map<String, dynamic>.from(nested))
        : entryFromApiJson(data);

    ClaimableResult? coins;
    final coinsRaw = data['coins'];
    if (coinsRaw is Map) {
      coins = CoinsApiService.claimableFromMap(
        Map<String, dynamic>.from(coinsRaw),
      );
    } else if (data.containsKey('earnableCoins') ||
        data.containsKey('canClaim') ||
        data.containsKey('totalClaimable') ||
        data['claimable'] is List) {
      coins = CoinsApiService.claimableFromMap(data);
    }

    return StepLogResponse(entry: entry, coins: coins);
  }

  static Map<String, dynamic> requestBody({
    required int steps,
    required int caloriesBurned,
    DateTime? date,
    String? timezone,
  }) {
    final body = <String, dynamic>{
      'steps': steps,
      'caloriesBurned': caloriesBurned,
      'timezone': timezone ?? resolveApiTimezone(),
    };
    if (date != null) {
      body['date'] = MealEntry.dateToKey(date);
    }
    return body;
  }

  static List<StepLogEntry> _entriesFromMaps(
    Iterable<dynamic> items, {
    DateTime? fallbackDate,
  }) {
    return items
        .whereType<Map>()
        .map(
          (item) => entryFromApiJson(
            Map<String, dynamic>.from(item),
            fallbackDate: fallbackDate,
          ),
        )
        .whereType<StepLogEntry>()
        .toList();
  }

  static StepLogEntry? entryFromApiJson(
    Map<String, dynamic> json, {
    DateTime? fallbackDate,
  }) {
    final nested = json['stepEntry'] ?? json['entry'];
    if (nested is Map) {
      return entryFromApiJson(
        Map<String, dynamic>.from(nested),
        fallbackDate: fallbackDate,
      );
    }

    final steps = _readInt(
      json['steps'] ?? json['stepCount'] ?? json['step_count'] ?? json['count'],
    );
    if (steps == null || steps < 0) return null;

    final date =
        _readDate(json['recordedAt']) ??
        _readDate(json['recorded_at']) ??
        _readDate(json['date']) ??
        fallbackDate;
    if (date == null) return null;

    final parsedCalories = _readInt(
      json['caloriesBurned'] ?? json['calories_burned'] ?? json['calories'],
    );

    return StepLogEntry(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      date: MealEntry.normalizeDate(date),
      steps: steps,
      caloriesBurned: (parsedCalories != null && parsedCalories > 0)
          ? parsedCalories
          : null,
    );
  }

  static List<dynamic> _readEntryMaps(Map<String, dynamic> data) {
    final items =
        data['entries'] ??
        data['stepEntries'] ??
        data['step_entries'] ??
        data['stepsLogs'] ??
        data['steps_logs'] ??
        data['history'] ??
        data['items'] ??
        data['logs'];
    if (items is List) return items;

    if (data.containsKey('steps') || data.containsKey('stepCount')) {
      return [data];
    }

    return const [];
  }

  static Map<String, dynamic> _unwrapData(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return json;
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _readDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
  }
}
