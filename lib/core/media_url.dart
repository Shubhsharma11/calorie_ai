import '../services/api_endpoints.dart';

/// Reads a photo URL from common API shapes and makes it loadable.
abstract final class MediaUrl {
  static const _keys = [
    'image',
    'imageUrl',
    'image_url',
    'signedUrl',
    'signed_url',
    'presignedUrl',
    'presigned_url',
    'photo',
    'photoUrl',
    'photo_url',
    'avatar',
    'avatarUrl',
    'avatar_url',
    'thumbnail',
    'thumbnailUrl',
    'thumbnail_url',
    'img',
    'picture',
    'foodImage',
    'food_image',
    'image_front_url',
    'image_front_small_url',
    'icon',
    'images',
    'media',
    'cover',
    'coverUrl',
    'cover_url',
  ];

  /// True for a server photo path/URL — not an emoji or other label.
  static bool looksLikeImageRef(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return false;
    final lower = value.toLowerCase();
    if (lower.startsWith('data:image/')) return true;
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('//')) {
      return true;
    }
    if (lower.startsWith('/') ||
        lower.startsWith('uploads/') ||
        lower.startsWith('avatars/')) {
      return true;
    }
    return RegExp(
      r'\.(png|jpe?g|webp|gif|avif|svg)(\?|$)',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  static String? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return preferLoadable([for (final key in _keys) _extract(json[key])]);
  }

  /// Picks a URL that can actually load from a private S3 bucket.
  ///
  /// GET payloads often send both `image: uploads/file.jpg` (persist key)
  /// and a signed `imageUrl`. The key must not win — rewriting it to an
  /// unsigned S3 URL 403s and the meal photo disappears.
  static String? preferLoadable(Iterable<String?> candidates) {
    String? signed;
    String? httpUrl;
    String? other;
    for (final candidate in candidates) {
      final raw = candidate?.trim() ?? '';
      if (raw.isEmpty) continue;
      final resolved = resolve(raw);
      if (resolved == null) continue;
      if (_isSignedS3Url(raw) || _isSignedS3Url(resolved)) {
        signed ??= resolved;
      } else if (_isHttpUrl(resolved)) {
        httpUrl ??= resolved;
      } else {
        other ??= resolved;
      }
    }
    return signed ?? httpUrl ?? other;
  }

  static String? resolve(String? raw) {
    final url = raw?.trim() ?? '';
    if (url.isEmpty) return null;
    if (url.startsWith('data:')) return url;

    final value = url.startsWith('//') ? 'https:$url' : url;
    final uploadKey = uploadObjectKey(value);
    if (uploadKey != null) {
      // Keep a signed S3 URL. The bucket is private; stripping the query
      // to an unsigned URL 403s and the photo vanishes after login.
      if (_isHttpUrl(value) && _isS3Host(value)) return value;
      return '${ApiEndpoints.s3PublicBaseUrl}/$uploadKey';
    }

    final key = avatarObjectKey(value);
    if (key != null) {
      // Keep a signed S3 URL as-is so it still loads while the signature is valid.
      if (_isHttpUrl(value) && _isS3Host(value)) return value;
      // Only rewrite API-host or relative `avatars/…` keys. Leave other CDNs.
      if (_isHttpUrl(value) && !_isApiHost(value)) return value;
      return '${ApiEndpoints.s3PublicBaseUrl}/$key';
    }

    if (_isHttpUrl(value)) return upgradeGooglePhoto(value);
    final base = ApiEndpoints.baseUrl;
    if (value.startsWith('/')) return '$base$value';
    return '$base/$value';
  }

  /// Google Sign-In pictures ship as `=s96-c`. Stretching that on a phone
  /// looks blurry; request a size that fills a typical screen instead.
  static String upgradeGooglePhoto(String url, {int size = 1024}) {
    if (!isGooglePhoto(url) || size <= 0) return url;

    final sized = url.replaceAllMapped(
      RegExp(r'(=s|=w|=h)\d+', caseSensitive: false),
      (match) => '${match[1]}$size',
    );
    if (sized != url) return sized;

    final sz = url.replaceAllMapped(
      RegExp(r'([?&]sz=)\d+', caseSensitive: false),
      (match) => '${match[1]}$size',
    );
    if (sz != url) return sz;

    if (url.contains('=')) return url;
    return '$url=s$size-c';
  }

  /// S3 object key (`uploads/file.jpg`) for a user-uploaded food/meal photo.
  ///
  /// Matches bare keys and S3 URLs. API-relative `/uploads/…` catalog images
  /// stay on the API host.
  static String? uploadObjectKey(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;

    if (!_isHttpUrl(value) && !value.startsWith('/')) {
      return _objectKeyFromPath(value, prefix: 'uploads/');
    }

    if (!_isHttpUrl(value) || !_isS3Host(value)) return null;

    var path = value;
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.hasScheme || uri.host.isNotEmpty)) {
      path = uri.path;
    } else {
      path = value.split('?').first;
    }
    return _objectKeyFromPath(path, prefix: 'uploads/');
  }

  /// Value to persist on my-meals / my-foods / email: `uploads/<file>`.
  static String? apiImageKey(String? raw) => uploadObjectKey(raw);

  /// S3 object key (`avatars/file.png`) if [url] points at an uploaded avatar.
  static String? avatarObjectKey(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;

    var path = value;
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.hasScheme || uri.host.isNotEmpty)) {
      path = uri.path;
    } else {
      path = value.split('?').first;
    }
    if (path.startsWith('/')) path = path.substring(1);

    return _objectKeyFromPath(path, prefix: 'avatars/');
  }

  static String? _objectKeyFromPath(String path, {required String prefix}) {
    var normalized = path.trim();
    if (normalized.startsWith('/')) normalized = normalized.substring(1);
    final index = normalized.indexOf(prefix);
    if (index < 0) return null;
    final rest = normalized.substring(index + prefix.length);
    final file = rest.split('/').first.trim();
    if (file.isEmpty) return null;
    return '$prefix$file';
  }

  /// Stable unsigned S3 URL for a custom upload (survives logout; no expiry).
  static String? canonicalUploadedAvatarUrl(String? url) {
    final key = avatarObjectKey(url);
    if (key == null) return null;
    return '${ApiEndpoints.s3PublicBaseUrl}/$key';
  }

  /// True when [url] is a file we uploaded to FitBuddy (S3 `/avatars/…`).
  static bool isUploadedAvatar(String? url) {
    final value = url?.trim().toLowerCase() ?? '';
    if (value.isEmpty) return false;
    final path = value.split('?').first;
    return path.contains('/avatars/') ||
        path.startsWith('avatars/') ||
        value.contains('.s3.') ||
        value.contains('.s3.amazonaws.com');
  }

  /// Google Sign-In `picture` URLs. These must not replace a custom upload.
  static bool isGooglePhoto(String? url) {
    final value = url?.trim().toLowerCase() ?? '';
    if (value.isEmpty) return false;
    return value.contains('googleusercontent.com') ||
        value.contains('lh3.google');
  }

  /// Keep a custom uploaded avatar instead of falling back to Google's photo.
  static bool shouldReplaceAvatar(String? current, String? incoming) {
    final next = incoming?.trim() ?? '';
    if (next.isEmpty) return false;
    final existing = current?.trim() ?? '';
    if (existing.isEmpty || existing == next) return true;
    if (isUploadedAvatar(existing) && !isUploadedAvatar(next)) return false;
    return true;
  }

  /// Prefers an uploaded S3 avatar over a Google profile photo.
  static String? preferAvatar(Iterable<String?> candidates) {
    String? uploaded;
    String? other;
    String? google;
    for (final candidate in candidates) {
      final raw = candidate?.trim() ?? '';
      if (raw.isEmpty) continue;
      final resolved = resolve(raw);
      if (resolved == null) continue;
      if (isUploadedAvatar(raw) || isUploadedAvatar(resolved)) {
        uploaded ??= resolved;
      } else if (isGooglePhoto(resolved)) {
        google ??= resolved;
      } else {
        other ??= resolved;
      }
    }
    return uploaded ?? other ?? google;
  }

  static bool _isHttpUrl(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

  static bool _isS3Host(String value) {
    final host = Uri.tryParse(value)?.host.toLowerCase() ?? '';
    return host.contains('.s3.') || host.contains('.s3.amazonaws.com');
  }

  static bool _isApiHost(String value) {
    final host = Uri.tryParse(value)?.host.toLowerCase() ?? '';
    final apiHost =
        Uri.tryParse(ApiEndpoints.baseUrl)?.host.toLowerCase() ?? '';
    return host.isNotEmpty && apiHost.isNotEmpty && host == apiHost;
  }

  static String? _extract(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      final trimmed = value.trim();
      return looksLikeImageRef(trimmed) ? trimmed : null;
    }
    if (value is List && value.isNotEmpty) return _extract(value.first);
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final candidates = <String>[];
      for (final key in [
        'url',
        'src',
        'path',
        'href',
        'secure_url',
        'signedUrl',
        'signed_url',
        'presignedUrl',
        'presigned_url',
        'downloadUrl',
        'download_url',
        'imageUrl',
        'image_url',
        'image',
        'icon',
        'avatarUrl',
        'avatar_url',
        'avatar',
        'key',
      ]) {
        final nested = _extract(map[key]);
        if (nested != null) candidates.add(nested);
      }
      return preferLoadable(candidates);
    }
    return null;
  }

  static bool _isSignedS3Url(String value) {
    if (!_isHttpUrl(value) || !_isS3Host(value)) return false;
    final query = value.split('?').skip(1).join('?').toLowerCase();
    if (query.isEmpty) return false;
    return query.contains('x-amz-signature=') ||
        query.contains('signature=') ||
        query.contains('awsaccesskeyid=');
  }
}
