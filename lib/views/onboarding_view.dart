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
      image: 'assets/image/sp1.png',
      darkImage: 'assets/image/sp1_dark.png',
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
      image: 'assets/image/sp2.png',
      darkImage: 'assets/image/sp2_dark.png',
      title: 'AI-Powered',
      titleAccent: 'Tracking',
      body: 'Scan a barcode or search — FitBuddy fills in calories for you.',
      features: [
        _FeatureItem(
          asset: 'assets/image/barcode.png',
          title: 'Scan & Log',
      
        ),
        _FeatureItem(
            asset: 'assets/image/search.png',
          title: 'Smart Search',
 
        ),
        _FeatureItem(
        asset: 'assets/image/progress.png',
          title: 'Track Progress',
         
        ),
      ],
    ),
    _OnboardPage(
      image: 'assets/image/sp3.png',
      darkImage: 'assets/image/sp3_dark.png',
      title: 'Personalized',
      titleAccent: 'For You',
      body: 'Goals, macros, and reminders tailored to your lifestyle.',
      features: [
        _FeatureItem(
           asset: 'assets/image/nutrition.png',
          title: 'Nutrition Measure',
  
        ),
        _FeatureItem(
           asset: 'assets/image/weight_progress.png',
          title: 'Weight Progress',
       
        ),
        _FeatureItem(
                  asset: 'assets/image/drop_water.png',
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
    final bg = isDark ? AppColors.backgroundOf(context) : Colors.white;
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
        body: Stack(
          children: [
            if (isDark)
              Positioned(
                top: r.scale(-40),
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    height: r.scale(280),
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.2),
                        radius: 0.95,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.14),
                          AppColors.darkHeaderWash.withValues(alpha: 0.55),
                          Colors.transparent,
                        ],
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
                        final isLast =
                            _controller.pageIndex.value == _pages.length - 1;
                        if (isLast) return SizedBox(height: r.scale(40));
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
                            margin:
                                EdgeInsets.symmetric(horizontal: r.scale(4)),
                            width: current == i
                                ? r.scale(28, tablet: 32)
                                : r.scale(8),
                            height: r.scale(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: current == i
                                  ? AppColors.primary
                                  : (isDark
                                      ? AppColors.darkBorder
                                          .withValues(alpha: 0.9)
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
                            child:
                                Text(isLast ? 'Get Started →' : 'Next →'),
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
    final titleSize = r.scale(short ? 30 : 34, tablet: 38, desktop: 42);
    final bodySize = r.scale(short ? 14.5 : 15.5, tablet: 16.5, desktop: 17);

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
                  horizontal: r.scale(4, tablet: 12),
                ),
                child: _OnboardImage(
                  assetPath:
                      isDark ? (page.darkImage ?? page.image) : page.image,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SizedBox(height: r.scale(short ? 8 : 12)),
           
            SizedBox(height: r.scale(short ? 12 : 16)),
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
            SizedBox(height: r.scale(10, tablet: 12)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.scale(18)),
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
            SizedBox(height: r.scale(short ? 16 : 22)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < page.features.length; i++) ...[
                  if (i > 0) SizedBox(width: r.scale(8)),
                  Expanded(
                    child: _FeatureColumn(
                      item: page.features[i],
                      compact: short,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: r.scale(short ? 6 : 10)),
          ],
        ),
      ),
    );
  }
}


  




class _FeatureColumn extends StatelessWidget {
  const _FeatureColumn({
    required this.item,
    required this.compact,
  });

  final _FeatureItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final isDark = AppColors.isDark(context);
    final r = context.responsive;
    final iconBox = r.scale(compact ? 42 : 46, tablet: 50);
    final asset = isDark
        ? (item.darkAsset ?? item.asset)
        : item.asset;

    return Column(
      children: [
        if (asset != null)
          SizedBox(
            width: iconBox,
            height: iconBox,
            child: Image.asset(
              asset,
              width: iconBox,
              height: iconBox,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, error, stackTrace) => _FeatureIconChip(
                icon: item.icon ?? Icons.circle,
                size: iconBox,
                isDark: isDark,
              ),
            ),
          )
        else
          _FeatureIconChip(
            icon: item.icon ?? Icons.circle,
            size: iconBox,
            isDark: isDark,
          ),
        SizedBox(height: r.scale(compact ? 8 : 10)),
        Text(
          item.title,
          textAlign: TextAlign.center,
         maxLines: 1,
softWrap: false,
overflow: TextOverflow.ellipsis,
          style: TextStyle(
           fontSize: r.scale(compact ? 10 : 12, tablet: 13),
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        SizedBox(height: r.scale(4)),
        SizedBox(
  height: r.scale(32, tablet: 36),
  
    ),


      ],
    );
  }
}

class _FeatureIconChip extends StatelessWidget {
  const _FeatureIconChip({
    required this.icon,
    required this.size,
    required this.isDark,
  });

  final IconData icon;
  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.14)
            : const Color(0xFFE8F8EE),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: isDark
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.28),
              )
            : null,
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: isDark ? AppColors.primary : const Color(0xFF2E9B4E),
      ),
    );
  }
}

class _FeatureItem {
  const _FeatureItem({
    required this.title,
    
    this.icon,
    this.asset,
    this.darkAsset,
  }) : assert(icon != null || asset != null);

  final IconData? icon;
  final String? asset;
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
