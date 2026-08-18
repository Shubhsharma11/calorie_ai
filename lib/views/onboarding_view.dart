import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../controllers/onboarding_controller.dart';
import '../core/responsive.dart';
import '../routes/app_routes.dart';
import '../services/local_storage_service.dart';
import '../theme/app_colors.dart';

/// Welcome carousel matching the FitBuddy onboarding design:
/// hero → logo → title → body → 3 feature columns → dots → Next.
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();

  late final OnboardingController _controller =
      Get.find<OnboardingController>();

  static const List<_OnboardPage> _pages = [
    _OnboardPage(
      image: 'assets/image/onboarding1.png',
      darkImage: 'assets/image/onbording1_dark.png',
      title: 'Eat Healthy',
      titleAccent: 'Live Healthy',
      body: 'Track meals and build better eating habits every day.',
      features: [
        _FeatureItem(
          asset: 'assets/image/profile_heart.png',
          darkAsset: 'assets/image/profile_heart_dark.png',
          title: 'Personalized',
        ),
        _FeatureItem(
          asset: 'assets/image/run.png',
          darkAsset: 'assets/image/run_dark.png',
          title: 'Activity Tracking',
        ),
        _FeatureItem(
          asset: 'assets/image/drop_water.png',
          darkAsset: 'assets/image/drop_water_dark.png',
          title: 'Hydration',
        ),
      ],
    ),
    _OnboardPage(
      image: 'assets/image/onboarding2.png',
      darkImage: 'assets/image/onboarding2_dark.png',
      title: 'AI-Powered',
      titleAccent: 'Tracking',
      body: 'Scan a barcode or search — FitBuddy fills in calories for you.',
      features: [
        _FeatureItem(
          asset: 'assets/image/barcode.png',
          darkAsset: 'assets/image/barcode_dark.png',
          title: 'Scan & Log',
        ),
        _FeatureItem(
          asset: 'assets/image/search.png',
          darkAsset: 'assets/image/search_dark.png',
          title: 'Smart Search',
        ),
        _FeatureItem(
          asset: 'assets/image/progress.png',
          darkAsset: 'assets/image/progress_dark.png',
          title: 'Track Progress',
        ),
      ],
    ),
    _OnboardPage(
      image: 'assets/image/onboarding3.png',
      darkImage: 'assets/image/onboarding3_dark.png',
      title: 'Personalized',
      titleAccent: 'For You',
      body: 'Goals, macros, and reminders tailored to your lifestyle.',
      features: [
        _FeatureItem(
          asset: 'assets/image/nutrition.png',
          darkAsset: 'assets/image/nutrition_dark.png',
          title: 'Nutrition Measure',
        ),
        _FeatureItem(
          asset: 'assets/image/Weight_progress.png',
          darkAsset: 'assets/image/Weight_progress_dark.png',
          title: 'Weight Progress',
        ),
        _FeatureItem(
          asset: 'assets/image/drop_water.png',
          darkAsset: 'assets/image/drop_water_dark.png',
          title: 'Water Reminder',
        ),
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await LocalStorageService().saveWelcomeIntroSeen(seen: true);
    Get.offNamed(AppRoutes.login);
  }

  Future<void> _handleNext() async {
    final isLast = _controller.pageIndex.value == _pages.length - 1;
    if (isLast) {
      await _finish();
      return;
    }
    _controller.nextPage(_pages.length);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final isDark = AppColors.isDark(context);
    final bg = isDark ? const Color(0xFF080B0E) : Colors.white;
    final horizontal = r.scale(22, tablet: 40, desktop: 48);
    final buttonHeight = r.scale(54, tablet: 56, desktop: 58);
    final short = r.height < 720;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: bg,
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.white,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Obx(() {
                    final isLast =
                        _controller.pageIndex.value == _pages.length - 1;
                    if (isLast) return SizedBox(height: r.scale(40));
                    return _SkipButton(onPressed: _finish);
                  }),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: _controller.goToPage,
                    itemBuilder: (_, index) {
                      return _OnboardSlide(
                        page: _pages[index],
                        responsive: r,
                        short: short,
                      );
                    },
                  ),
                ),
                SizedBox(height: r.scale(short ? 10 : 14)),
                Obx(() {
                  final current = _controller.pageIndex.value;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        margin: EdgeInsets.symmetric(horizontal: r.scale(4)),
                        width: current == i
                            ? r.scale(28, tablet: 32)
                            : r.scale(8),
                        height: r.scale(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: current == i
                              ? AppColors.primary
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.22)
                                    : const Color(0xFFD8E0D8)),
                        ),
                      ),
                    ),
                  );
                }),
                SizedBox(height: r.scale(short ? 16 : 22)),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: r.formMaxWidth),
                  child: Obx(() {
                    final isLast =
                        _controller.pageIndex.value == _pages.length - 1;
                    return SizedBox(
                      height: buttonHeight,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          textStyle: TextStyle(
                            fontSize: r.scale(16, tablet: 17),
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              r.scale(16, tablet: 18),
                            ),
                          ),
                        ),
                        child: Text(isLast ? 'Get Started →' : 'Next →'),
                      ),
                    );
                  }),
                ),
                SizedBox(height: r.scale(short ? 12 : 18)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final isDark = AppColors.isDark(context);

    return Padding(
      padding: EdgeInsets.only(top: r.scale(4), bottom: r.scale(4)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: EdgeInsets.symmetric(
              horizontal: r.scale(14),
              vertical: r.scale(7),
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Skip',
              style: TextStyle(
                fontSize: r.scale(14, tablet: 15),
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFE8E8ED)
                    : AppColors.textSecondaryOf(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardSlide extends StatelessWidget {
  const _OnboardSlide({
    required this.page,
    required this.responsive,
    required this.short,
  });

  final _OnboardPage page;
  final Responsive responsive;
  final bool short;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = responsive;
    final isDark = AppColors.isDark(context);
    final titleSize = r.scale(short ? 28 : 32, tablet: 36, desktop: 40);
    final bodySize = r.scale(short ? 14 : 15, tablet: 16, desktop: 17);
    final heroFit = isDark ? BoxFit.fitWidth : BoxFit.contain;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: r.scale(420, tablet: 520, desktop: 560),
        ),
        child: Column(
          children: [
            Expanded(
              flex: short ? 6 : 7,
              child: Align(
                alignment: Alignment.topCenter,
                child: _OnboardImage(
                  assetPath: isDark
                      ? (page.darkImage ?? page.image)
                      : page.image,
                  fit: heroFit,
                ),
              ),
            ),
            SizedBox(height: r.scale(short ? 4 : 8)),
            Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.textPrimaryOf(context)
                      : const Color(0xFF1A1F2C),
                  height: 1.18,
                  letterSpacing: -0.5,
                ),
                children: [
                  TextSpan(text: '${page.title}\n'),
                  TextSpan(
                    text: page.titleAccent,
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: r.scale(8, tablet: 10)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.scale(12)),
              child: Text(
                page.body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: bodySize,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondaryOf(context),
                ),
              ),
            ),
            SizedBox(height: r.scale(short ? 14 : 18)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < page.features.length; i++) ...[
                  if (i > 0) SizedBox(width: r.scale(10)),
                  Expanded(
                    child: _FeatureColumn(
                      item: page.features[i],
                      compact: short,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: r.scale(short ? 4 : 8)),
          ],
        ),
      ),
    );
  }
}

class _FeatureColumn extends StatelessWidget {
  const _FeatureColumn({required this.item, required this.compact});

  final _FeatureItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final isDark = AppColors.isDark(context);
    final iconBox = r.scale(compact ? 48 : 52, tablet: 56);
    final asset = isDark ? (item.darkAsset ?? item.asset) : item.asset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: SizedBox(
            width: iconBox,
            height: iconBox,
            child: Image.asset(
              asset,
              width: iconBox,
              height: iconBox,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        SizedBox(height: r.scale(compact ? 8 : 10)),
        Text(
          item.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: r.scale(compact ? 11 : 12, tablet: 13),
            fontWeight: FontWeight.w600,
            height: 1.25,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }
}

class _FeatureItem {
  const _FeatureItem({
    required this.title,
    required this.asset,
    this.darkAsset,
  });

  final String asset;
  final String? darkAsset;
  final String title;
}

class _OnboardPage {
  const _OnboardPage({
    required this.image,
    required this.title,
    required this.titleAccent,
    required this.body,
    required this.features,
    this.darkImage,
  });

  final String image;
  final String? darkImage;
  final String title;
  final String titleAccent;
  final String body;
  final List<_FeatureItem> features;
}

/// Renders PNG assets normally, and SVG assets that may wrap an embedded PNG.
class _OnboardImage extends StatefulWidget {
  const _OnboardImage({required this.assetPath, this.fit = BoxFit.contain});

  final String assetPath;
  final BoxFit fit;

  @override
  State<_OnboardImage> createState() => _OnboardImageState();
}

class _OnboardImageState extends State<_OnboardImage> {
  static final RegExp _embeddedPngPattern = RegExp(
    r'(?:xlink:)?href="data:image\/png;base64,([^"]+)"',
  );

  static final Map<String, Future<Widget>> _cache = {};

  late final Future<Widget> _imageFuture = _cache.putIfAbsent(
    '${widget.assetPath}|${widget.fit}',
    () => _loadImage(widget.assetPath, widget.fit),
  );

  static Future<Widget> _loadImage(String assetPath, BoxFit fit) async {
    if (!assetPath.toLowerCase().endsWith('.svg')) {
      return Image.asset(assetPath, fit: fit);
    }

    final svgText = await rootBundle.loadString(assetPath);
    final match = _embeddedPngPattern.firstMatch(svgText);
    if (match != null) {
      final bytes = base64Decode(match.group(1)!);
      return Image.memory(bytes, fit: fit, gaplessPlayback: true);
    }
    return SvgPicture.string(svgText, fit: fit);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.assetPath.toLowerCase().endsWith('.svg')) {
      return Image.asset(
        widget.assetPath,
        fit: widget.fit,
        width: widget.fit == BoxFit.fitWidth ? double.infinity : null,
        alignment: Alignment.topCenter,
      );
    }

    return FutureBuilder<Widget>(
      future: _imageFuture,
      builder: (context, snapshot) {
        final child = snapshot.data;
        if (child != null) {
          return SizedBox.expand(child: child);
        }
        return const SizedBox.expand();
      },
    );
  }
}
