import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../routes/app_routes.dart';
import '../services/local_storage_service.dart';

/// Fallback only — startup normally resolves the route in [main] so the
/// native launch screen is the single FitBuddy brand moment.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  static const _bg = Color(0xFFF4FAF6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _go());
  }

  Future<void> _go() async {
    if (!mounted) return;

    late final String next;
    try {
      final user = Get.find<UserController>();
      final storage = LocalStorageService();

      if (user.isLoggedIn && user.accessToken.isNotEmpty) {
        await storage.saveWelcomeIntroSeen(seen: true);
        next = await user.resolveSetupResumeRoute();
      } else if (await storage.isWelcomeIntroSeen()) {
        next = AppRoutes.login;
      } else {
        next = AppRoutes.onboarding;
      }
    } catch (_) {
      next = AppRoutes.login;
    }

    if (!mounted) return;
    Get.offAllNamed(next);
  }

  @override
  Widget build(BuildContext context) {
    // Match native splash background only — no second logo.
    return const Scaffold(
      backgroundColor: _bg,
      body: SizedBox.expand(),
    );
  }
}
