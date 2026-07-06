class HealthConcern {
  const HealthConcern({
    required this.category,
    required this.description,
    this.duration,
    this.severity,
    this.medication,
  });

  static const noneCategory = 'None';

  final String category;
  final String description;
  final String? duration;
  final String? severity;
  final String? medication;

  bool get isNone => category == noneCategory;

  bool get isComplete =>
      isNone ||
      (description.trim().isNotEmpty &&
          duration != null &&
          severity != null &&
          medication != null);

  HealthConcern copyWith({
    String? category,
    String? description,
    String? duration,
    String? severity,
    String? medication,
  }) {
    return HealthConcern(
      category: category ?? this.category,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      severity: severity ?? this.severity,
      medication: medication ?? this.medication,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'category': category,
      'description': description,
    };
    if (duration != null) json['duration'] = duration;
    if (severity != null) json['severity'] = severity;
    if (medication != null) json['medication'] = medication;
    return json;
  }

  factory HealthConcern.fromJson(Map<String, dynamic> json) {
    return HealthConcern(
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      duration: json['duration'] as String?,
      severity: json['severity'] as String?,
      medication: json['medication'] as String?,
    );
  }

  factory HealthConcern.none() {
    return const HealthConcern(category: noneCategory, description: '');
  }
}
