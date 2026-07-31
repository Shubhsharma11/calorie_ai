class RepeatCardService {
  static bool _dismissedThisSession = false;

  static Future<bool> shouldShowCard() async {
    return !_dismissedThisSession;
  }

  static Future<void> dismissForToday() async {
    _dismissedThisSession = true;
  }
}
