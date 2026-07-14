import 'package:calorie_ai/core/goal_progress_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isGoalReached is true at exact goal', () {
    expect(
      GoalProgressMessage.isGoalReached(consumed: 2000, goal: 2000),
      isTrue,
    );
  });

  test('isGoalReached is true when rounded progress hits 100%', () {
    expect(
      GoalProgressMessage.isGoalReached(consumed: 1999, goal: 2000),
      isTrue,
    );
  });

  test('isGoalReached is false below rounded 100%', () {
    expect(
      GoalProgressMessage.isGoalReached(consumed: 1980, goal: 2000),
      isFalse,
    );
  });
}
