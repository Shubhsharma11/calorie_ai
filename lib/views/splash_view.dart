import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/theme_controller.dart';
import '../controllers/user_controller.dart';
import '../core/startup_route.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

/// Fallback only — startup normally resolves the route in [main] so the
/// native launch screen is the single FitBuddy brand moment.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _go());
  }

  Future<void> _go() async {
    if (!mounted) return;

    late final String next;
    try {
      next = await resolveStartupRoute(user: Get.find<UserController>());
    } catch (_) {
      next = AppRoutes.login;
    }

    if (!mounted) return;
    Get.offAllNamed(next);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Get.isRegistered<ThemeController>()
        ? Get.find<ThemeController>().effectiveBrightness == Brightness.dark
        : AppColors.isDark(context);
    // Match native splash: white in light, black in dark (logo12 canvas).
    final bg = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

    return Scaffold(
      backgroundColor: bg,
      body: const SizedBox.expand(),
    );
  }
}
