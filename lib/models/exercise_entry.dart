import 'meal_entry.dart';

class ExerciseEntry {
  const ExerciseEntry({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.calories,
    required this.date,
    this.typeId,
    this.intensityLabel,
  });

  final String id;
  final String name;
  final int durationMinutes;
  final int calories;
  final DateTime date;
  final String? typeId;
  final String? intensityLabel;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'durationMinutes': durationMinutes,
    'calories': calories,
    'date': date.toIso8601String(),
    if (typeId != null) 'typeId': typeId,
    if (intensityLabel != null) 'intensityLabel': intensityLabel,
  };

  factory ExerciseEntry.fromJson(Map<String, dynamic> json) {
    return ExerciseEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      durationMinutes: (json['durationMinutes'] as num).round(),
      calories: (json['calories'] as num).round(),
      date: DateTime.parse(json['date'] as String),
      typeId: json['typeId'] as String?,
      intensityLabel: json['intensityLabel'] as String?,
    );
  }

  DateTime get normalizedDate => MealEntry.normalizeDate(date);
}
