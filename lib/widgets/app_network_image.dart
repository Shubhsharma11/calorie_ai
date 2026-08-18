import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/media_url.dart';
import '../services/platform_http_client.dart';

/// Network photo that uses the same HTTP stack as the API (Cronet on Android).
///
/// [Image.network] goes through dart:io, which 403s private S3 objects on
/// some Android versions even when the signed URL is valid.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.gaplessPlayback = false,
    this.errorBuilder,
    this.placeholder,
    this.cacheWidth,
    this.filterQuality = FilterQuality.medium,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final bool gaplessPlayback;
  final ImageErrorWidgetBuilder? errorBuilder;
  final Widget? placeholder;
  final int? cacheWidth;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    final resolved = MediaUrl.resolve(url) ?? url;
    ImageProvider provider = PlatformNetworkImage(resolved);
    if (cacheWidth != null) {
      provider = ResizeImage.resizeIfNeeded(cacheWidth, null, provider);
    }
    return Image(
      image: provider,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: gaplessPlayback,
      filterQuality: filterQuality,
      errorBuilder: errorBuilder,
      frameBuilder: placeholder == null
          ? null
          : (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) return child;
              return placeholder!;
            },
    );
  }
}

@immutable
class PlatformNetworkImage extends ImageProvider<PlatformNetworkImage> {
  const PlatformNetworkImage(this.url, {this.scale = 1.0});

  final String url;
  final double scale;

  @override
  Future<PlatformNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<PlatformNetworkImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    PlatformNetworkImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<String>('URL', url),
      ],
    );
  }

  static Future<ui.Codec> _loadAsync(
    PlatformNetworkImage key,
    ImageDecoderCallback decode,
  ) async {
    final uri = Uri.parse(key.url);
    final response = await createPlatformHttpClient().get(uri);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        response.bodyBytes.isEmpty) {
      throw NetworkImageLoadException(
        statusCode: response.statusCode,
        uri: uri,
      );
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(response.bodyBytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is PlatformNetworkImage &&
        other.url == url &&
        other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'PlatformNetworkImage')}("$url", scale: $scale)';
}
