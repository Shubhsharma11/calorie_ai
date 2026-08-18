import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/user_controller.dart';
import '../core/api_errors.dart';
import '../core/photo_permission.dart';
import '../core/responsive.dart';
import '../models/problem_report.dart';
import '../services/device_info_service.dart';
import '../services/support_api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_page.dart';

class ReportProblemView extends StatefulWidget {
  const ReportProblemView({super.key});

  @override
  State<ReportProblemView> createState() => _ReportProblemViewState();
}

enum _SubmitErrorKind { network, auth, server }

class _ReportProblemViewState extends State<ReportProblemView> {
  static const _maxScreenshotBytes = 5 * 1024 * 1024;

  final _deviceInfoService = DeviceInfoService();
  final _supportApi = SupportApiService();
  final _imagePicker = ImagePicker();
  final _descriptionController = TextEditingController();
  final _descriptionFocus = FocusNode();

  ProblemCategory? _category;
  String? _screenshotPath;
  AppDeviceInfo? _deviceInfo;
  bool _isSubmitting = false;
  bool _submitted = false;
  bool _showSubmitError = false;
  bool _attemptedSubmit = false;
  _SubmitErrorKind _submitErrorKind = _SubmitErrorKind.network;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_onFormChanged);
    _loadDeviceInfo();
  }

  @override
  void dispose() {
    _descriptionController
      ..removeListener(_onFormChanged)
      ..dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceInfo() async {
    final info = await _deviceInfoService.collect();
    if (!mounted) return;
    setState(() => _deviceInfo = info);
  }

  void _onFormChanged() {
    if (_showSubmitError || _attemptedSubmit) {
      setState(() {});
    }
  }

  bool get _hasDescription => _descriptionController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return Scaffold(
      appBar: const AppAppBar(title: 'Report a Problem'),
      body: _submitted
          ? _SuccessBody(onDone: () => Get.back<void>())
          : _form(r),
    );
  }

  Widget _form(Responsive r) {
    return ResponsivePage(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Help us improve FitBuddy AI',
            style: TextStyle(
              fontSize: r.scale(22, tablet: 24),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          SizedBox(height: r.scale(8)),
          Text(
            'Tell us what went wrong. A little detail can help us investigate '
            'the issue faster.',
            style: TextStyle(
              fontSize: r.scale(14),
              color: AppColors.textSecondaryOf(context),
              height: 1.4,
            ),
          ),
          SizedBox(height: r.scale(28)),
          _sectionLabel(r, 'PROBLEM TYPE'),
          SizedBox(height: r.scale(10)),
          _ProblemTypeField(
            category: _category,
            showError: _attemptedSubmit && _category == null,
            onTap: _pickCategory,
          ),
          if (_attemptedSubmit && _category == null)
            Padding(
              padding: EdgeInsets.only(top: r.scale(6)),
              child: Text(
                'Please select a problem type.',
                style: TextStyle(fontSize: r.scale(12), color: AppColors.error),
              ),
            ),
          SizedBox(height: r.scale(22)),
          _sectionLabel(r, 'WHAT HAPPENED?'),
          SizedBox(height: r.scale(10)),
          TextField(
            controller: _descriptionController,
            focusNode: _descriptionFocus,
            minLines: 5,
            maxLines: 8,
            maxLength: 2000,
            textInputAction: TextInputAction.newline,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            style: TextStyle(
              fontSize: r.scale(15),
              color: AppColors.textPrimaryOf(context),
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: 'Tell us what went wrong...',
              hintStyle: TextStyle(
                color: AppColors.textSecondaryOf(context),
                fontSize: r.scale(14),
              ),
              filled: true,
              fillColor: AppColors.cardOf(context),
              counterStyle: TextStyle(
                color: AppColors.textSecondaryOf(context),
                fontSize: r.scale(12),
              ),
              contentPadding: EdgeInsets.all(r.scale(16)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.borderOf(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: _attemptedSubmit && !_hasDescription
                      ? AppColors.error
                      : AppColors.borderOf(context),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: _attemptedSubmit && !_hasDescription
                      ? AppColors.error
                      : AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          if (_attemptedSubmit && !_hasDescription)
            Padding(
              padding: EdgeInsets.only(top: r.scale(6)),
              child: Text(
                'Please describe what happened.',
                style: TextStyle(fontSize: r.scale(12), color: AppColors.error),
              ),
            ),
          SizedBox(height: r.scale(22)),
          _sectionLabel(r, 'SCREENSHOT (OPTIONAL)'),
          SizedBox(height: r.scale(6)),
          Text(
            'Add a screenshot to help us understand the problem.',
            style: TextStyle(
              fontSize: r.scale(13),
              color: AppColors.textSecondaryOf(context),
              height: 1.35,
            ),
          ),
          SizedBox(height: r.scale(10)),
          if (_screenshotPath == null)
            _AddScreenshotButton(onTap: _addScreenshot)
          else
            _ScreenshotPreview(
              path: _screenshotPath!,
              onRemove: () => setState(() => _screenshotPath = null),
            ),
          if (_showSubmitError) ...[
            SizedBox(height: r.scale(20)),
            _SubmitErrorBanner(r: r, kind: _submitErrorKind),
          ],
          SizedBox(height: r.scale(24)),
          PrimaryButton(
            label: _showSubmitError ? 'Try Again' : 'Submit Report',
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
          SizedBox(height: r.scale(24)),
          Center(
            child: Text(
              'App Information',
              style: TextStyle(
                fontSize: r.scale(12),
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryOf(context),
                letterSpacing: 0.4,
              ),
            ),
          ),
          SizedBox(height: r.scale(4)),
          Center(
            child: Text(
              _deviceInfo?.footerLabel ?? 'FitBuddy AI',
              style: TextStyle(
                fontSize: r.scale(12),
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ),
          SizedBox(
            height: MediaQuery.viewPaddingOf(context).bottom + r.scale(8),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(Responsive r, String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: r.scale(12),
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondaryOf(context),
        letterSpacing: 0.6,
      ),
    );
  }

  Future<void> _pickCategory() async {
    final selected = await showAppOptionsSheet<ProblemCategory>(
      context: context,
      title: 'Select a problem',
      selected: _category,
      options: [
        for (final option in ProblemCategory.values)
          AppSheetOption(value: option, label: option.label),
      ],
    );
    if (selected == null || !mounted) return;
    setState(() => _category = selected);
  }

  Future<void> _addScreenshot() async {
    FocusScope.of(context).unfocus();
    try {
      final allowed = await ensureImageSourcePermission(ImageSource.gallery);
      if (!allowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(photoPermissionDeniedMessage(ImageSource.gallery)),
          ),
        );
        return;
      }

      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null || !mounted) return;

      final file = File(image.path);
      if (!file.existsSync() || file.lengthSync() > _maxScreenshotBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'That screenshot is too large. Please choose a smaller image.',
            ),
          ),
        );
        return;
      }

      setState(() => _screenshotPath = image.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add a screenshot.')),
      );
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_isSubmitting) return;

    final isValid = _category != null && _hasDescription;
    setState(() {
      _attemptedSubmit = true;
      if (isValid) {
        _isSubmitting = true;
        _showSubmitError = false;
      }
    });
    if (!isValid) return;

    try {
      final user = Get.isRegistered<UserController>()
          ? Get.find<UserController>()
          : null;
      final accessToken = (await user?.resolveAccessToken())?.trim() ?? '';
      if (accessToken.isEmpty) {
        _failSubmit(_SubmitErrorKind.auth);
        return;
      }

      final screenshotPath = _screenshotPath;
      if (screenshotPath != null) {
        final file = File(screenshotPath);
        if (!file.existsSync() || file.lengthSync() > _maxScreenshotBytes) {
          if (!mounted) return;
          setState(() {
            _isSubmitting = false;
            _screenshotPath = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'That screenshot is too large. Please choose a smaller image.',
              ),
            ),
          );
          return;
        }
      }

      final deviceInfo = _deviceInfo ?? await _deviceInfoService.collect();
      await _supportApi.submitReport(
        accessToken: accessToken,
        category: _category!,
        description: _descriptionController.text,
        deviceInfo: deviceInfo,
        screenshotPath: screenshotPath,
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitted = true;
      });
    } catch (error) {
      debugPrint('ReportProblemView: submit failed: $error');
      if (!mounted) return;
      _failSubmit(_errorKindFor(error));
    }
  }

  void _failSubmit(_SubmitErrorKind kind) {
    setState(() {
      _isSubmitting = false;
      _showSubmitError = true;
      _submitErrorKind = kind;
    });
  }

  _SubmitErrorKind _errorKindFor(Object error) {
    if (error is SupportApiException && error.statusCode == 401) {
      return _SubmitErrorKind.auth;
    }
    if (error is TimeoutException ||
        (error is SupportApiException && error.message.contains('timed out')) ||
        isApiNetworkError(error)) {
      return _SubmitErrorKind.network;
    }
    return _SubmitErrorKind.server;
  }
}

class _ProblemTypeField extends StatelessWidget {
  const _ProblemTypeField({
    required this.category,
    required this.showError,
    required this.onTap,
  });

  final ProblemCategory? category;
  final bool showError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final hasValue = category != null;
    final borderColor = showError
        ? AppColors.error
        : AppColors.borderOf(context);

    return Material(
      color: AppColors.cardOf(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(16),
            vertical: r.scale(16),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  category?.label ?? 'Select a problem',
                  style: TextStyle(
                    fontSize: r.scale(15),
                    fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
                    color: hasValue
                        ? AppColors.textPrimaryOf(context)
                        : AppColors.textSecondaryOf(context),
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondaryOf(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddScreenshotButton extends StatelessWidget {
  const _AddScreenshotButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return Material(
      color: AppColors.cardOf(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: r.scale(18)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: r.scale(6)),
              Text(
                'Add Screenshot',
                style: TextStyle(
                  fontSize: r.scale(15),
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScreenshotPreview extends StatelessWidget {
  const _ScreenshotPreview({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            File(path),
            width: double.infinity,
            height: r.scale(180, tablet: 220),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: double.infinity,
              height: r.scale(180, tablet: 220),
              color: AppColors.surfaceOf(context),
              alignment: Alignment.center,
              child: Text(
                'Could not load screenshot',
                style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: r.scale(13),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.black.withValues(alpha: 0.55),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmitErrorBanner extends StatelessWidget {
  const _SubmitErrorBanner({required this.r, required this.kind});

  final Responsive r;
  final _SubmitErrorKind kind;

  String get _body {
    switch (kind) {
      case _SubmitErrorKind.auth:
        return 'Your session expired. Please sign in again.';
      case _SubmitErrorKind.network:
        return 'Please check your internet connection and try again.';
      case _SubmitErrorKind.server:
        return 'Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.scale(14)),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Couldn\'t submit your report',
            style: TextStyle(
              fontSize: r.scale(15),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          SizedBox(height: r.scale(4)),
          Text(
            _body,
            style: TextStyle(
              fontSize: r.scale(13),
              color: AppColors.textSecondaryOf(context),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return ResponsivePage(
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.primary,
              size: 40,
            ),
          ),
          SizedBox(height: r.scale(20)),
          Text(
            'Report Submitted',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.scale(22, tablet: 24),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          SizedBox(height: r.scale(10)),
          Text(
            'Thanks for helping us improve FitBuddy AI.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.scale(15),
              color: AppColors.textSecondaryOf(context),
              height: 1.45,
            ),
          ),
          const Spacer(),
          PrimaryButton(label: 'Done', onPressed: onDone),
          SizedBox(
            height: MediaQuery.viewPaddingOf(context).bottom + r.scale(12),
          ),
        ],
      ),
    );
  }
}
