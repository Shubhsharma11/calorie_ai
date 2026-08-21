import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/responsive.dart';
import '../models/user_model.dart';
import '../theme/app_colors.dart';
import 'app_network_image.dart';

/// Circular profile photo. Optional pencil badge shows it can be changed.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.user,
    this.onTap,
    this.radius,
    this.isUploading = false,
    this.showEditBadge = false,
    this.onEditBadgeTap,
    this.tooltip,
  });

  final UserModel user;
  final VoidCallback? onTap;
  final double? radius;
  final bool isUploading;
  final bool showEditBadge;
  final VoidCallback? onEditBadgeTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final size = radius ?? r.scale(32);
    final diameter = size * 2;
    final bytes = user.profilePhotoBytes;
    final url = user.avatarUrl?.trim() ?? '';
    final hasBytes = bytes != null && bytes.isNotEmpty;
    final hasUrl = url.isNotEmpty;
    final cacheSize = (diameter * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(1, 1024);
    final badgeSize = (size * 0.52).clamp(24.0, 32.0);

    final Widget photo;
    if (hasBytes) {
      photo = Image(
        image: ResizeImage(
          MemoryImage(bytes),
          width: cacheSize,
          policy: ResizeImagePolicy.fit,
        ),
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => _PersonFallback(size: size),
      );
    } else if (hasUrl) {
      photo = AppNetworkImage(
        url,
        width: diameter,
        height: diameter,
        cacheWidth: cacheSize,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, _) {
          debugPrint('ProfileAvatar failed for $url: $error');
          return _PersonFallback(size: size);
        },
        placeholder: _PersonFallback(size: size),
      );
    } else {
      photo = _PersonFallback(size: size);
    }

    Widget avatar = SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: ColoredBox(
              color: AppColors.surface,
              child: SizedBox(width: diameter, height: diameter, child: photo),
            ),
          ),
          if (isUploading)
            Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.35),
              ),
              alignment: Alignment.center,
              child: SizedBox(
                width: size * 0.7,
                height: size * 0.7,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          if ((showEditBadge || onEditBadgeTap != null) && !isUploading)
            Positioned(
              right: -2,
              bottom: -2,
              child: _EditBadge(
                size: badgeSize,
                onTap: onEditBadgeTap,
              ),
            ),
        ],
      ),
    );

    if (onTap != null) {
      avatar = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: avatar,
        ),
      );
    }

    final labeled = tooltip == null
        ? avatar
        : Tooltip(message: tooltip!, child: avatar);
    return Semantics(
      button: onTap != null,
      label: tooltip ?? 'Profile photo',
      child: labeled,
    );
  }
}

class _PersonFallback extends StatelessWidget {
  const _PersonFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.person_rounded,
        size: size * 1.1,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _EditBadge extends StatelessWidget {
  const _EditBadge({required this.size, this.onTap});

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SvgPicture.asset(
        'assets/image/pencil.svg',
        fit: BoxFit.contain,
      ),
    );

    if (onTap == null) {
      return IgnorePointer(child: badge);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: badge,
      ),
    );
  }
}
