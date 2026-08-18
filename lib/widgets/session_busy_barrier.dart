import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../theme/app_colors.dart';

/// Blocks taps and the system back button while logout / account deletion
/// waits on the server — same as a typical production auth flow.
class SessionBusyBarrier extends StatelessWidget {
  const SessionBusyBarrier({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = Get.find<UserController>();
      final busy = user.isSessionBusy.value;
      final deleting = user.isDeletingAccount;

      return PopScope(
        canPop: !busy,
        child: Stack(
          children: [
            child,
            if (busy) _Scrim(deleting: deleting),
          ],
        ),
      );
    });
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim({required this.deleting});

  final bool deleting;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);

    return AbsorbPointer(
      child: Material(
        color: Colors.black.withValues(alpha: 0.48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      deleting ? 'Deleting account…' : 'Signing out…',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please wait a moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
