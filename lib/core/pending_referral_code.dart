import 'referral_link_parser.dart';

/// In-memory holder for an invite code captured before login/signup completes.
///
/// Not persisted to SharedPreferences / Hive / SQLite — survives only for the
/// current app process until claimed or cleared.
class PendingReferralCode {
  PendingReferralCode._();

  static final PendingReferralCode instance = PendingReferralCode._();

  String? _code;

  String? get code => _code;

  bool get hasCode => _code != null && _code!.isNotEmpty;

  /// Stores a raw code (normalized). Returns false if invalid.
  bool setCode(String? raw) {
    final normalized = ReferralLinkParser.codeFromString(raw ?? '');
    if (normalized == null) return false;
    _code = normalized;
    return true;
  }

  /// Parses a deep link / URI and stores the code when present.
  bool captureFromUri(Uri uri) {
    final code = ReferralLinkParser.codeFromUri(uri);
    if (code == null) return false;
    _code = code;
    return true;
  }

  void clear() {
    _code = null;
  }

  /// Test-only reset.
  void debugReset() => clear();
}
