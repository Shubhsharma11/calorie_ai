import 'package:calorie_ai/models/onboarding_journey.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses 5 milestones with 4 fill segments', () {
    expect(OnboardingMilestones.count, 5);
    expect(OnboardingMilestones.segments, 4);
    expect(OnboardingMilestones.labels.last, 'Create Plan');
  });

  test('lifestyle includes eating habits and living area', () {
    final lifestyle = OnboardingJourney.sections.firstWhere(
      (s) => s.id == OnboardingSectionId.lifestyle,
    );
    expect(lifestyle.steps, contains(OnboardingFlowProgress.eatingHabits));
    expect(lifestyle.steps, contains(OnboardingFlowProgress.livingArea));
    expect(OnboardingFlowProgress.totalSteps, 19);
  });

  test('fill advances through Preferences toward Create Plan', () {
    expect(
      OnboardingJourney.fillProgressForStep(OnboardingFlowProgress.gender),
      0.0,
    );
    expect(
      OnboardingJourney.fillProgressForStep(
        OnboardingFlowProgress.currentWeight,
      ),
      closeTo(0.25, 0.001),
    );

    expect(
      OnboardingJourney.fillProgressForStep(OnboardingFlowProgress.goalSetup),
      closeTo(0.25, 0.001),
    );
    expect(
      OnboardingJourney.fillProgressForStep(
        OnboardingFlowProgress.targetWeight,
      ),
      closeTo(0.5, 0.001),
    );

    expect(
      OnboardingJourney.fillProgressForStep(OnboardingFlowProgress.activity),
      closeTo(0.5, 0.001),
    );
    expect(
      OnboardingJourney.fillProgressForStep(OnboardingFlowProgress.medications),
      closeTo(0.75, 0.001),
    );

    final prefFirst = OnboardingJourney.fillProgressForStep(
      OnboardingFlowProgress.dietPlanInterest,
    );
    final prefMid = OnboardingJourney.fillProgressForStep(
      OnboardingFlowProgress.meatPreferences,
    );
    final prefLast = OnboardingJourney.fillProgressForStep(
      OnboardingFlowProgress.foodsToAvoid,
    );

    expect(prefFirst, closeTo(0.75, 0.001));
    expect(prefMid, greaterThan(prefFirst));
    expect(prefLast, closeTo(1.0, 0.001));
  });

  test('Create Plan dot lights only at end of Preferences', () {
    expect(
      OnboardingJourney.isMilestoneCompleted(
        4,
        OnboardingFlowProgress.foodPreferences,
      ),
      isFalse,
    );
    expect(
      OnboardingJourney.isMilestoneCompleted(
        4,
        OnboardingFlowProgress.foodsToAvoid,
      ),
      isTrue,
    );
  });
}
