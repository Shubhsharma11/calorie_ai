enum GoalType { loseWeight, maintainWeight, gainWeight }

extension GoalTypeLabel on GoalType {
  String get title {
    switch (this) {
      case GoalType.loseWeight:
        return 'Lose Weight';
      case GoalType.maintainWeight:
        return 'Maintain Weight';
      case GoalType.gainWeight:
        return 'Gain Weight';
    }
  }

  String get summaryLabel {
    switch (this) {
      case GoalType.loseWeight:
        return 'Weight loss';
      case GoalType.maintainWeight:
        return 'Maintenance';
      case GoalType.gainWeight:
        return 'Weight gain';
    }
  }

  String get statusLabel {
    switch (this) {
      case GoalType.loseWeight:
        return 'Losing weight';
      case GoalType.maintainWeight:
        return 'Maintaining weight';
      case GoalType.gainWeight:
        return 'Gaining weight';
    }
  }

  String get description {
    switch (this) {
      case GoalType.loseWeight:
        return 'Reduce body fat and achieve a healthier you.';
      case GoalType.maintainWeight:
        return 'Stay healthy by maintaining your current weight.';
      case GoalType.gainWeight:
        return 'Build muscle and gain healthy weight.';
    }
  }
}
