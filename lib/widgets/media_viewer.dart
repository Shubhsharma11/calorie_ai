import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/media_url.dart';
import '../core/responsive.dart';
import 'app_network_image.dart';

bool canViewMedia({Uint8List? imageBytes, String? imageUrl}) {
  if (imageBytes != null && imageBytes.isNotEmpty) return true;
  final url = MediaUrl.resolve(imageUrl);
  return url != null && url.isNotEmpty;
}

VoidCallback? mediaViewerOpener({
  required BuildContext context,
  Uint8List? imageBytes,
  String? imageUrl,
  String title = 'Photo',
}) {
  if (!canViewMedia(imageBytes: imageBytes, imageUrl: imageUrl)) return null;
  return () => showMediaViewer(
    context: context,
    imageBytes: imageBytes,
    imageUrl: imageUrl,
    title: title,
  );
}

Future<void> showMediaViewer({
  required BuildContext context,
  Uint8List? imageBytes,
  String? imageUrl,
  String title = 'Photo',
  VoidCallback? onDelete,
}) {
  if (!canViewMedia(imageBytes: imageBytes, imageUrl: imageUrl)) {
    return Future<void>.value();
  }

  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Close photo',
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _MediaViewer(
        imageBytes: imageBytes,
        imageUrl: imageUrl,
        title: title,
        onDelete: onDelete,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _MediaViewer extends StatelessWidget {
  const _MediaViewer({
    this.imageBytes,
    this.imageUrl,
    required this.title,
    this.onDelete,
  });

  final Uint8List? imageBytes;
  final String? imageUrl;
  final String title;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final topInset = MediaQuery.paddingOf(context).top;
    final bytes = imageBytes;
    final url = MediaUrl.resolve(imageUrl) ?? '';
    final hasBytes = bytes != null && bytes.isNotEmpty;

    final Widget photo;
    if (hasBytes) {
      photo = Image.memory(
        bytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => const _ViewerFallback(),
      );
    } else {
      photo = AppNetworkImage(
        url,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, _) {
          debugPrint('Media viewer failed for $url: $error');
          return const _ViewerFallback();
        },
        placeholder: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: photo,
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  r.scale(8),
                  topInset + r.scale(4),
                  r.scale(16),
                  r.scale(12),
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCC000000), Color(0x00000000)],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: r.scale(4)),
                    Expanded(
                      child: Text(
                        title.trim().isEmpty ? 'Photo' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.scale(17),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (onDelete != null)
                      IconButton(
                        tooltip: 'Delete photo',
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.of(context, rootNavigator: true).pop();
                          onDelete!();
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerFallback extends StatelessWidget {
  const _ViewerFallback();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.broken_image_outlined,
      size: 120,
      color: Colors.white54,
    );
  }
}
