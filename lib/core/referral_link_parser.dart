/// Parses invite / referral deep links into a short uppercase code.
///
/// Supported shapes (host optional for custom schemes):
/// - `https://mycaloriepal.com/r/AB12CD`
/// - `https://www.mycaloriepal.com/invite/AB12CD`
/// - `mycaloriepal://r/AB12CD`
/// - Query: `?ref=AB12CD` / `?code=AB12CD` / `?referral=AB12CD`
abstract final class ReferralLinkParser {
  static const _codePattern = r'^[A-Za-z0-9]{4,16}$';

  /// Returns a normalized code or `null` if the URI is not a referral link.
  static String? codeFromUri(Uri uri) {
    final queryCode = _firstQuery(
      uri,
      const ['ref', 'code', 'referral', 'invite', 'inviteCode'],
    );
    if (queryCode != null) return queryCode;

    final segments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) return null;

    for (var i = 0; i < segments.length - 1; i++) {
      final marker = segments[i].toLowerCase();
      if (marker == 'r' ||
          marker == 'ref' ||
          marker == 'referral' ||
          marker == 'invite') {
        return _normalize(segments[i + 1]);
      }
    }

    // Bare path `/AB12CD` on known hosts only.
    if (segments.length == 1 && _isMyCaloriePalHost(uri.host)) {
      return _normalize(segments.first);
    }
    return null;
  }

  static String? codeFromString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final asUri = Uri.tryParse(trimmed);
    if (asUri != null &&
        (asUri.hasScheme || trimmed.contains('/') || trimmed.contains('?'))) {
      final fromUri = codeFromUri(asUri);
      if (fromUri != null) return fromUri;
    }
    return _normalize(trimmed);
  }

  static bool _isMyCaloriePalHost(String host) {
    final h = host.toLowerCase();
    return h == 'mycaloriepal.com' ||
        h == 'www.mycaloriepal.com' ||
        h.endsWith('.mycaloriepal.com');
  }

  static String? _firstQuery(Uri uri, List<String> keys) {
    for (final key in keys) {
      final value = uri.queryParameters[key];
      final normalized = _normalize(value);
      if (normalized != null) return normalized;
    }
    return null;
  }

  static String? _normalize(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().toUpperCase();
    if (value.isEmpty) return null;
    if (!RegExp(_codePattern).hasMatch(value)) return null;
    return value;
  }
}
