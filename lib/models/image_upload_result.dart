import '../core/media_url.dart';

/// Response from `POST /api/v1/uploads/image`.
///
/// Persist and send [key] (`uploads/<file>`) on my-meals / my-foods — not
/// the signed [url], which expires.
class ImageUploadResult {
  const ImageUploadResult({
    required this.key,
    this.url,
    this.expiresIn,
    this.contentType,
    this.size,
  });

  final String key;
  final String? url;
  final int? expiresIn;
  final String? contentType;
  final int? size;

  factory ImageUploadResult.fromJson(Map<String, dynamic> json) {
    final key = keyFromResponse(json);
    if (key == null || key.isEmpty) {
      throw const FormatException('Image upload response missing key');
    }
    return ImageUploadResult(
      key: key,
      url: urlFromResponse(json),
      expiresIn: _readInt(json, const ['expiresIn', 'expires_in']),
      contentType: _readString(json, const ['contentType', 'content_type']),
      size: _readInt(json, const ['size']),
    );
  }

  static String? keyFromResponse(Map<String, dynamic>? json) {
    if (json == null) return null;
    for (final map in _maps(json)) {
      for (final field in [map['key'], map['objectKey'], map['object_key'], map['url']]) {
        if (field is! String) continue;
        final key = MediaUrl.uploadObjectKey(field);
        if (key != null) return key;
      }
    }
    for (final map in _maps(json)) {
      final key = MediaUrl.uploadObjectKey(MediaUrl.fromJson(map));
      if (key != null) return key;
    }
    return null;
  }

  static String? urlFromResponse(Map<String, dynamic>? json) {
    if (json == null) return null;
    for (final map in _maps(json)) {
      final raw = map['url'];
      if (raw is String && raw.trim().startsWith('http')) {
        return MediaUrl.resolve(raw.trim());
      }
    }
    for (final map in _maps(json)) {
      final fromKey = MediaUrl.resolve(
        map['key'] is String ? map['key'] as String : null,
      );
      if (fromKey != null) return fromKey;
    }
    for (final map in _maps(json)) {
      final resolved = MediaUrl.fromJson(map);
      if (resolved != null) return resolved;
    }
    return null;
  }

  static Iterable<Map<String, dynamic>> _maps(Map<String, dynamic> json) sync* {
    yield json;
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      yield data;
    } else if (data is Map) {
      yield Map<String, dynamic>.from(data);
    }
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final map in _maps(json)) {
      for (final key in keys) {
        final value = map[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
    return null;
  }

  static int? _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final map in _maps(json)) {
      for (final key in keys) {
        final value = map[key];
        if (value is int) return value;
        if (value is num) return value.round();
        if (value is String) return int.tryParse(value.trim());
      }
    }
    return null;
  }
}
