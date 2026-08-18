import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/responsive.dart';
import '../models/user_model.dart';
import '../theme/app_colors.dart';
import 'app_bottom_sheet.dart';
import 'app_network_image.dart';
import 'media_viewer.dart';

enum ProfilePhotoAction { view, camera, gallery, remove }

/// Profile photo actions: view, camera, gallery, remove.
Future<ProfilePhotoAction?> showProfilePhotoSheet({
  required BuildContext context,
  required UserModel user,
}) async {
  if (!context.mounted) return null;

  final hasPhoto = user.hasProfilePhoto;

  return showAppBottomSheet<ProfilePhotoAction>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) {
      final r = sheetContext.responsive;

      void choose(ProfilePhotoAction action) {
        HapticFeedback.selectionClick();
        Navigator.pop(sheetContext, action);
      }

      return AppSheetScaffold(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _SheetPhotoThumb(
                  user: user,
                  size: r.scale(44),
                  onTap: hasPhoto
                      ? () => choose(ProfilePhotoAction.view)
                      : null,
                ),
                SizedBox(width: r.scale(12)),
                Expanded(
                  child: Text(
                    hasPhoto ? 'Edit profile picture' : 'Add profile picture',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: r.scale(18),
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(sheetContext);
                  },
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.all(r.scale(8)),
                  constraints: BoxConstraints(
                    minWidth: r.scale(40),
                    minHeight: r.scale(40),
                  ),
                  icon: Icon(
                    Icons.close_rounded,
                    size: r.scale(22),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: r.scale(8)),
            _SheetActionRow(
              icon: Icons.photo_camera_outlined,
              label: 'Take photo',
              onTap: () => choose(ProfilePhotoAction.camera),
            ),
            Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)),
            _SheetActionRow(
              icon: Icons.photo_library_outlined,
              label: 'Choose photo',
              onTap: () => choose(ProfilePhotoAction.gallery),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showProfilePhotoViewer({
  required BuildContext context,
  required UserModel user,
}) {
  return showMediaViewer(
    context: context,
    imageBytes: user.profilePhotoBytes,
    imageUrl: user.avatarUrl,
    title: user.name.trim().isEmpty ? 'Profile photo' : user.name,
  );
}

class _SheetPhotoThumb extends StatelessWidget {
  const _SheetPhotoThumb({required this.user, required this.size, this.onTap});

  final UserModel user;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bytes = user.profilePhotoBytes;
    final url = user.avatarUrl?.trim() ?? '';
    final hasBytes = bytes != null && bytes.isNotEmpty;
    final hasUrl = url.isNotEmpty;
    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(1, 256);
    final radius = BorderRadius.circular(size * 0.22);

    final Widget photo;
    if (hasBytes) {
      photo = Image(
        image: ResizeImage(
          MemoryImage(bytes),
          width: cacheSize,
          policy: ResizeImagePolicy.fit,
        ),
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => _ThumbFallback(size: size),
      );
    } else if (hasUrl) {
      photo = AppNetworkImage(
        url,
        width: size,
        height: size,
        cacheWidth: cacheSize,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => _ThumbFallback(size: size),
        placeholder: _ThumbFallback(size: size),
      );
    } else {
      photo = _ThumbFallback(size: size);
    }

    final thumb = ClipRRect(
      borderRadius: radius,
      child: SizedBox(width: size, height: size, child: photo),
    );

    if (onTap == null) return thumb;

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: radius, child: thumb),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Icon(
        Icons.person_rounded,
        size: size * 0.62,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _SheetActionRow extends StatelessWidget {
  const _SheetActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r.scale(12)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: r.scale(14)),
        child: Row(
          children: [
            Icon(icon, size: r.scale(22), color: AppColors.textPrimary),
            SizedBox(width: r.scale(14)),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: r.scale(15),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
