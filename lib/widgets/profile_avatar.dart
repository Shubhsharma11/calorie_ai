import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../models/user_model.dart';
/// Circular profile photo — tap to change (no visible camera badge).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.user,
    required this.onTap,
    this.radius,
  });

  final UserModel user;
  final VoidCallback onTap;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final size = radius ?? r.scale(32);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: CircleAvatar(
          radius: size,
          backgroundColor: const Color(0xFFE8ECF0),
          backgroundImage: user.profilePhotoBytes != null
              ? MemoryImage(user.profilePhotoBytes!)
              : null,
          child: user.profilePhotoBytes == null
              ? Icon(
                  Icons.person_rounded,
                  size: size * 1.1,
                  color: const Color(0xFF5C6F8C),
                )
              : null,
        ),
      ),
    );
  }
}
