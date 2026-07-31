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

/// Clean welcome carousel: hero + title + body + CTA.
/// No feature grids — those cramped every device size.
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
      image: 'assets/image/sp1.png',
      darkImage: 'assets/image/sp1_dark.png',
      title: 'Eat Healthy',
      titleAccent: 'Live Healthy',
      body:
          'Log meals in seconds and build better eating habits that actually stick.',
      highlights: ['Meal logging', 'Daily habits', 'Stay consistent'],
    ),
    _OnboardPage(
      image: 'assets/image/sp2.png',
      darkImage: 'assets/image/sp2_dark.png',
      title: 'AI-Powered',
      titleAccent: 'Tracking',
      body:
          'Scan a barcode or search — FitBuddy fills in calories so you don’t have to guess.',
      highlights: ['Barcode scan', 'Smart search', 'Live calories'],
    ),
    _OnboardPage(
      image: 'assets/image/sp3.png',
      darkImage: 'assets/image/sp3_dark.png',
      title: 'Personalized',
      titleAccent: 'For You',
      body:
          'Goals, macros, and reminders tailored to your body and lifestyle.',
      highlights: ['Custom goals', 'Weight progress', 'Water reminders'],
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
    final bg = AppColors.backgroundOf(context);
    final horizontal = r.scale(24, tablet: 40, desktop: 48);
    final buttonHeight = r.scale(52, tablet: 56, desktop: 58);
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
            ),
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: r.scale(-28),
              right: r.scale(-56, tablet: -36),
              child: IgnorePointer(
                child: Container(
                  width: r.scale(220, tablet: 200),
                  height: r.scale(220, tablet: 200),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(
                      alpha: isDark ? 0.12 : 0.08,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontal),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Obx(() {
                        final isLast = _controller.pageIndex.value ==
                            _pages.length - 1;
                        if (isLast) {
                          return SizedBox(height: r.scale(40));
                        }
                        return TextButton(
                          onPressed: _finish,
                          style: TextButton.styleFrom(
                            foregroundColor:
                                AppColors.textSecondaryOf(context),
                            padding: EdgeInsets.symmetric(
                              horizontal: r.scale(8),
                              vertical: r.scale(8),
                            ),
                          ),
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              fontSize: r.scale(15, tablet: 16),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
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
                    SizedBox(height: r.scale(short ? 8 : 12)),
                    Obx(() {
                      final current = _controller.pageIndex.value;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            margin: EdgeInsets.symmetric(
                              horizontal: r.scale(4),
                            ),
                            width: current == i
                                ? r.scale(24, tablet: 28)
                                : r.scale(8),
                            height: r.scale(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: current == i
                                  ? AppColors.primary
                                  : AppColors.borderOf(context),
                            ),
                          ),
                        ),
                      );
                    }),
                    SizedBox(height: r.scale(short ? 16 : 22)),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: r.formMaxWidth),
                      child: Obx(() {
                        final isLast = _controller.pageIndex.value ==
                            _pages.length - 1;
                        return SizedBox(
                          height: buttonHeight,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _handleNext,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              elevation: 0,
                              textStyle: TextStyle(
                                fontSize: r.scale(16, tablet: 17),
                                fontWeight: FontWeight.w700,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  r.scale(14, tablet: 16),
                                ),
                              ),
                            ),
                            child: Text(isLast ? 'Get Started' : 'Continue'),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: r.scale(short ? 12 : 18)),
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
    final bodySize = r.scale(short ? 15 : 16, tablet: 17, desktop: 18);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: r.scale(420, tablet: 520, desktop: 560),
        ),
        child: Column(
          children: [
            Expanded(
              flex: short ? 5 : 6,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: r.scale(8, tablet: 16),
                ),
                child: _OnboardImage(
                  assetPath:
                      isDark ? (page.darkImage ?? page.image) : page.image,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SizedBox(height: r.scale(short ? 16 : 24)),
            Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryOf(context),
                  height: 1.2,
                  letterSpacing: -0.4,
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
            SizedBox(height: r.scale(10, tablet: 12)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.scale(12)),
              child: Text(
                page.body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: bodySize,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ),
            SizedBox(height: r.scale(short ? 14 : 20)),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: r.scale(8),
              runSpacing: r.scale(8),
              children: [
                for (final label in page.highlights)
                  _HighlightChip(label: label),
              ],
            ),
            SizedBox(height: r.scale(short ? 8 : 12)),
          ],
        ),
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final isDark = AppColors.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder.withValues(alpha: 0.9)
              : AppColors.border.withValues(alpha: 0.9),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryOf(context),
          height: 1.1,
        ),
      ),
    );
  }
}

class _OnboardPage {
  const _OnboardPage({
    required this.image,
    required this.title,
    required this.titleAccent,
    required this.body,
    this.darkImage,
    this.highlights = const [],
  });

  final String image;
  final String? darkImage;
  final String title;
  final String titleAccent;
  final String body;
  final List<String> highlights;
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
      return Image.asset(widget.assetPath, fit: widget.fit);
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
