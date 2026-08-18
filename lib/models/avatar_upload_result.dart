import '../core/media_url.dart';

class AvatarUploadResult {
  const AvatarUploadResult({
    required this.avatarUrl,
    this.expiresIn,
  });

  final String avatarUrl;
  final int? expiresIn;

  factory AvatarUploadResult.fromJson(Map<String, dynamic> json) {
    final url = urlFromResponse(json);
    if (url == null || url.isEmpty) {
      throw const FormatException('Avatar upload response missing avatarUrl');
    }
    return AvatarUploadResult(
      avatarUrl: url,
      expiresIn: expiresInFromResponse(json),
    );
  }

  static const _avatarKeys = ['avatarUrl', 'avatar_url', 'avatar'];
  static const _fallbackPhotoKeys = [
    'picture',
    'photoUrl',
    'photo_url',
    'photo',
  ];

  static String? urlFromResponse(Map<String, dynamic>? json) {
    if (json == null) return null;
    final candidates = <String>[];

    void addCandidate(Object? value) {
      if (value is! String) return;
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) candidates.add(trimmed);
    }

    for (final map in _maps(json)) {
      for (final key in _avatarKeys) {
        addCandidate(map[key]);
      }
    }
    for (final map in _maps(json)) {
      for (final key in _fallbackPhotoKeys) {
        addCandidate(map[key]);
      }
    }
    return MediaUrl.preferAvatar(candidates);
  }

  static int? expiresInFromResponse(Map<String, dynamic>? json) {
    if (json == null) return null;
    for (final map in _maps(json)) {
      final value = map['expiresIn'] ?? map['expires_in'];
      if (value is int) return value;
      if (value is num) return value.round();
      if (value is String) return int.tryParse(value);
    }
    return null;
  }

  static Iterable<Map<String, dynamic>> _maps(Map<String, dynamic> json) sync* {
    yield json;

    final data = json['data'];
    if (data is Map<String, dynamic>) {
      yield data;
      final nestedUser = data['user'];
      if (nestedUser is Map<String, dynamic>) yield nestedUser;
    }

    final user = json['user'];
    if (user is Map<String, dynamic>) yield user;
  }
}
