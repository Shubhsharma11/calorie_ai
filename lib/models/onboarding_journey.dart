/// Data-driven onboarding journey — sections + global step indices.
///
/// Encounter order (source of truth for progress chrome):
/// Personal → Goals → Lifestyle → Preferences → Create Plan
///
/// Indexing is **0-based**. There is no Target Date question.
library;

/// Flat step indices used across onboarding screens (progress + drafts).
abstract final class OnboardingFlowProgress {
  static const totalSteps = 19;

  // Personal (0–3)
  static const gender = 0;
  static const age = 1;
  static const height = 2;
  static const currentWeight = 3;

  // Goals (4–5)
  static const goalSetup = 4;
  static const targetWeight = 5;

  // Lifestyle (6–13)
  static const activity = 6;
  static const eatingHabits = 7;
  static const livingArea = 8;
  static const dietType = 9;
  static const mealsPerDay = 10;
  static const cookingSkills = 11;
  static const health = 12;
  static const medications = 13;

  // Preferences (14–18)
  static const dietPlanInterest = 14;
  static const foodPreferences = 15;
  static const meatPreferences = 16;
  static const habitFoodAllergies = 17;
  static const foodsToAvoid = 18;

  /// Legacy aliases kept for older call sites.
  static const goalWeight = targetWeight;
  static const dietPreferences = dietType;
}

enum OnboardingSectionId { personal, goals, lifestyle, preferences }

/// Progress chrome milestones (fixed dots on the track).
///
/// Content lives in 4 sections; the 5th milestone is **Create Plan**
/// (end of Preferences → plan generation), like other health apps.
abstract final class OnboardingMilestones {
  static const count = 5;
  static const labels = <String>[
    'Personal',
    'Goals',
    'Lifestyle',
    'Preferences',
    'Create Plan',
  ];

  /// Segments between the 5 dots (= content section count).
  static int get segments => count - 1;
}

class OnboardingSection {
  const OnboardingSection({
    required this.id,
    required this.label,
    required this.steps,
  });

  final OnboardingSectionId id;
  final String label;
  final List<int> steps;
}

/// Manual step → section mapping. This is the only source of truth for
/// [labelForStep], [sectionIndexForStep], [progressWithinSection], and
/// [OnboardingSectionProgress].
abstract final class OnboardingJourney {
  static const sections = <OnboardingSection>[
    OnboardingSection(
      id: OnboardingSectionId.personal,
      label: 'Personal',
      steps: [
        OnboardingFlowProgress.gender, // 0
        OnboardingFlowProgress.age, // 1
        OnboardingFlowProgress.height, // 2
        OnboardingFlowProgress.currentWeight, // 3
      ],
    ),
    OnboardingSection(
      id: OnboardingSectionId.goals,
      label: 'Goals',
      steps: [
        OnboardingFlowProgress.goalSetup, // 4
        OnboardingFlowProgress.targetWeight, // 5
      ],
    ),
    OnboardingSection(
      id: OnboardingSectionId.lifestyle,
      label: 'Lifestyle',
      steps: [
        OnboardingFlowProgress.activity, // 6
        OnboardingFlowProgress.eatingHabits, // 7
        OnboardingFlowProgress.livingArea, // 8
        OnboardingFlowProgress.dietType, // 9
        OnboardingFlowProgress.mealsPerDay, // 10
        OnboardingFlowProgress.cookingSkills, // 11
        OnboardingFlowProgress.health, // 12
        OnboardingFlowProgress.medications, // 13
      ],
    ),
    OnboardingSection(
      id: OnboardingSectionId.preferences,
      label: 'Preferences',
      steps: [
        OnboardingFlowProgress.dietPlanInterest, // 14
        OnboardingFlowProgress.foodPreferences, // 15
        OnboardingFlowProgress.meatPreferences, // 16
        OnboardingFlowProgress.habitFoodAllergies, // 17
        OnboardingFlowProgress.foodsToAvoid, // 18
      ],
    ),
  ];

  static OnboardingSection sectionForStep(int stepIndex) {
    for (final section in sections) {
      if (section.steps.contains(stepIndex)) return section;
    }
    return sections.first;
  }

  static int sectionIndexForStep(int stepIndex) {
    for (var i = 0; i < sections.length; i++) {
      if (sections[i].steps.contains(stepIndex)) return i;
    }
    return 0;
  }

  /// 0..1 progress through the current section (from the manual step lists).
  ///
  /// First question in a section = 0, last question = 1 (smooth within-section
  /// fill). Single-question sections report 1.
  static double progressWithinSection(int stepIndex) {
    final section = sectionForStep(stepIndex);
    final idx = section.steps.indexOf(stepIndex);
    if (idx < 0 || section.steps.isEmpty) return 0;
    if (section.steps.length == 1) return 1;
    return (idx / (section.steps.length - 1)).clamp(0.0, 1.0);
  }

  /// Fill position 0..1 along the **5-dot** track.
  ///
  /// 5 milestones → 4 segments. Each content section owns one segment so
  /// Preferences grows into the final “Create Plan” dot (never clamps early).
  static double fillProgressForStep(int stepIndex) {
    final segments = OnboardingMilestones.segments;
    if (segments <= 0) return 0;
    final sectionIndex = sectionIndexForStep(
      stepIndex,
    ).clamp(0, sections.length - 1);
    final within = progressWithinSection(stepIndex).clamp(0.0, 1.0);
    return ((sectionIndex + within) / segments).clamp(0.0, 1.0);
  }

  /// Whether milestone dot [milestoneIndex] (0..4) should be solid.
  static bool isMilestoneCompleted(int milestoneIndex, int stepIndex) {
    if (milestoneIndex < 0 || milestoneIndex >= OnboardingMilestones.count) {
      return false;
    }
    final sectionIndex = sectionIndexForStep(stepIndex);
    final within = progressWithinSection(stepIndex);

    // First 4 dots = content sections (light when that section is reached).
    if (milestoneIndex < sections.length) {
      return milestoneIndex <= sectionIndex;
    }

    // Final “Create Plan” dot — solid only at the end of Preferences.
    return sectionIndex >= sections.length - 1 && within >= 1.0;
  }

  static String labelForStep(int stepIndex) =>
      sectionForStep(stepIndex).label.toUpperCase();

  static String labelForSection(OnboardingSectionId id) {
    for (final section in sections) {
      if (section.id == id) return section.label.toUpperCase();
    }
    return 'PERSONAL';
  }

  static bool isLastInSection(int stepIndex) {
    final section = sectionForStep(stepIndex);
    return section.steps.isNotEmpty && section.steps.last == stepIndex;
  }

  static OnboardingSectionId? nextSectionAfter(int stepIndex) {
    if (!isLastInSection(stepIndex)) return null;
    final i = sectionIndexForStep(stepIndex);
    if (i < 0 || i >= sections.length - 1) return null;
    return sections[i + 1].id;
  }

  static String? bridgeCopy(OnboardingSectionId completed) {
    return switch (completed) {
      OnboardingSectionId.personal => 'Great — now let’s set your goals.',
      OnboardingSectionId.goals => 'Next, a few lifestyle questions.',
      OnboardingSectionId.lifestyle => 'Almost done — your food preferences.',
      OnboardingSectionId.preferences => null,
    };
  }
}
