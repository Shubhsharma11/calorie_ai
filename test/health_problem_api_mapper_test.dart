import 'package:calorie_ai/models/health_problem_api_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps UI health concern values to API enums', () {
    expect(
      HealthProblemApiMapper.category('High Cholesterol'),
      'highCholesterol',
    );
    expect(HealthProblemApiMapper.category('Stress / Anxiety'), 'stress');
    expect(HealthProblemApiMapper.duration('1-4 weeks'), 'oneToFourWeeks');
    expect(HealthProblemApiMapper.duration('1-6 months'), 'oneToSixMonths');
    expect(HealthProblemApiMapper.severity('Moderate'), 'moderate');
    expect(HealthProblemApiMapper.medication('No'), 'no');
  });
}
