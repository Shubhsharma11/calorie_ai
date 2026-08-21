import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';
import 'app_bottom_sheet.dart';
import 'primary_button.dart';
import 'profile_avatar.dart';
import 'profile_photo_sheet.dart';

/// Edit name + photo. Photo uploads through the existing avatar API;
/// name is saved to `PATCH /auth/me` when the user taps Save.
Future<void> showEditProfileBottomSheet({
  required BuildContext context,
  required UserController controller,
}) {
  return showAppBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => _EditProfileSheet(
      controller: controller,
    ),
  );
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.controller});

  final UserController controller;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameController;
  var _saving = false;

  UserController get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _ctrl.user.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    HapticFeedback.selectionClick();
    await _ctrl.showProfilePhotoOptions(context);
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackbar.error('Enter your name.', title: 'Name required');
      return;
    }

    setState(() => _saving = true);
    final error = await _ctrl.updateDisplayName(name);
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      AppSnackbar.error(error, title: 'Save failed');
      return;
    }

    Navigator.of(context).pop();
    AppSnackbar.success('Profile updated.', title: 'Saved');
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return AppSheetScaffold(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit profile',
              style: TextStyle(
                fontSize: r.scale(18),
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: r.scale(20)),
            GetBuilder<UserController>(
              builder: (ctrl) {
                return Column(
                  children: [
                    Center(
                      child: ProfileAvatar(
                        user: ctrl.user,
                        onTap: _saving
                            ? null
                            : () {
                                if (Platform.isIOS) {
                                  if (!ctrl.user.hasProfilePhoto) return;
                                  HapticFeedback.selectionClick();
                                  showProfilePhotoViewer(
                                    context: context,
                                    user: ctrl.user,
                                  );
                                  return;
                                }
                                _changePhoto();
                              },
                        radius: r.scale(42, tablet: 46),
                        isUploading: ctrl.isUploadingAvatar,
                        showEditBadge: !Platform.isIOS,
                        tooltip: Platform.isIOS
                            ? (ctrl.user.hasProfilePhoto
                                ? 'View photo'
                                : 'Profile photo')
                            : 'Change photo',
                      ),
                    ),
                    SizedBox(height: r.scale(10)),
                    TextButton(
                      onPressed: _saving ? null : _changePhoto,
                      child: Text(
                        ctrl.user.hasProfilePhoto
                            ? 'Change photo'
                            : 'Add photo',
                        style: TextStyle(
                          fontSize: r.scale(14),
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: r.scale(8)),
            Text(
              'Name',
              style: TextStyle(
                fontSize: r.scale(13),
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: r.scale(8)),
            TextField(
              controller: _nameController,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                hintText: 'Your name',
              ),
            ),
            SizedBox(height: r.scale(20)),
            GetBuilder<UserController>(
              builder: (ctrl) {
                final busy = _saving || ctrl.isUploadingAvatar;
                return PrimaryButton(
                  label: 'Save',
                  isLoading: busy,
                  onPressed: busy ? null : _save,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
