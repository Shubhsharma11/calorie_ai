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

/// Welcome carousel: track home → AI meal plan → coins & gifts.
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
      image: 'assets/image/buddy/onboard_hero_track.png',
      title: 'Meet Your',
      titleAccent: 'Smart Coach',
      body: 'Track calories, steps, and coins in one calm home screen.',
      featureStyle: _FeatureStyle.outlineIcons,
      features: [
        _FeatureItem(title: 'Personalized', icon: Icons.person_outline_rounded),
        _FeatureItem(title: 'Daily Tips', icon: Icons.lightbulb_outline_rounded),
        _FeatureItem(title: 'Earn Coins', icon: Icons.monetization_on_outlined),
      ],
    ),
    _OnboardPage(
      image: 'assets/image/buddy/onboard_hero_meals.png',
      title: 'AI Meal Plan',
      titleAccent: 'Made For You',
      body:
          'Get a weekly plan that matches your calories, macros, and goals.',
      featureStyle: _FeatureStyle.chips,
      features: [
        _FeatureItem(
          title: 'Weekly Plan',
          icon: Icons.calendar_today_outlined,
        ),
        _FeatureItem(
          title: 'Smart Meals',
          icon: Icons.lightbulb_outline_rounded,
        ),
        _FeatureItem(
          title: 'Easy Logging',
          icon: Icons.check_circle_outline_rounded,
        ),
      ],
    ),
    _OnboardPage(
      image: 'assets/image/buddy/onboard_hero_coins.png',
      title: 'Walk & Claim',
      titleAccent: 'Earn Rewards',
      body:
          'Earn coins from steps, claim them to your wallet, unlock real gifts.',
      featureStyle: _FeatureStyle.tags,
      giftHighlights: [
        _GiftHighlight(label: 'Steps', value: 'Coins'),
        _GiftHighlight(label: 'Claim', value: 'Wallet'),
      ],
      features: [
        _FeatureItem(title: 'Streaks'),
        _FeatureItem(title: 'Wallet'),
        _FeatureItem(title: 'Gift Shop'),
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
                    if (isLast) {
                      return SizedBox(height: r.scale(38, tablet: 40));
                    }
                    return _SkipButton(onPressed: _finish);
                  }),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: _controller.goToPage,
                    itemBuilder: (_, index) {
                      return Obx(() {
                        final active =
                            _controller.pageIndex.value == index;
                        return _OnboardSlide(
                          page: _pages[index],
                          responsive: r,
                          short: short,
                          isActive: active,
                        );
                      });
                    },
                  ),
                ),
                SizedBox(height: r.scale(short ? 8 : 10)),
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
                SizedBox(height: r.scale(short ? 12 : 16)),
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
                              r.scale(28, tablet: 30),
                            ),
                          ),
                        ),
                        child: Text(isLast ? 'Get Started →' : 'Next →'),
                      ),
                    );
                  }),
                ),
                SizedBox(height: r.scale(short ? 10 : 14)),
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
      padding: EdgeInsets.only(top: r.scale(2), bottom: r.scale(2)),
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
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder
                    : const Color(0xFFE5E5EA),
              ),
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

class _OnboardSlide extends StatefulWidget {
  const _OnboardSlide({
    required this.page,
    required this.responsive,
    required this.short,
    required this.isActive,
  });

  final _OnboardPage page;
  final Responsive responsive;
  final bool short;
  final bool isActive;

  @override
  State<_OnboardSlide> createState() => _OnboardSlideState();
}

class _OnboardSlideState extends State<_OnboardSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<double> _imageScale;
  late final Animation<double> _imageFade;
  late final Animation<Offset> _imageSlide;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Pop-up: grow from small with a spring bounce.
    _imageScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_enter);

    _imageFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0, 0.35, curve: Curves.easeOut),
      ),
    );

    // Tiny settle upward so it feels like it pops into place.
    _imageSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _contentFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0.45, 1, curve: Curves.easeOut),
      ),
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0.45, 1, curve: Curves.easeOutCubic),
      ),
    );

    if (widget.isActive) {
      _enter.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _OnboardSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _enter.forward(from: 0);
    } else if (!widget.isActive && oldWidget.isActive) {
      _enter.value = 0;
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = widget.responsive;
    final page = widget.page;
    final short = widget.short;
    final isDark = AppColors.isDark(context);
    final titleSize = r.scale(short ? 28 : 32, tablet: 36, desktop: 40);
    final bodySize = r.scale(short ? 14 : 15, tablet: 16, desktop: 17);

    final titleBlock = Text.rich(
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
    );

    final bodyBlock = Padding(
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
    );

    final imageBlock = Expanded(
      flex: page.titleFirst ? 11 : 14,
      child: FadeTransition(
        opacity: _imageFade,
        child: SlideTransition(
          position: _imageSlide,
          child: ScaleTransition(
            alignment: Alignment.center,
            scale: _imageScale,
            child: _OnboardImage(
              assetPath:
                  isDark ? (page.darkImage ?? page.image) : page.image,
            ),
          ),
        ),
      ),
    );

    final giftsBlock = page.giftHighlights.isEmpty
        ? null
        : Row(
            children: [
              for (var i = 0; i < page.giftHighlights.length; i++) ...[
                if (i > 0) SizedBox(width: r.scale(10)),
                Expanded(
                  child: _GiftHighlightCard(
                    highlight: page.giftHighlights[i],
                  ),
                ),
              ],
            ],
          );

    final featuresBlock = _FeaturesRow(
      features: page.features,
      style: page.featureStyle,
      compact: short,
    );

    final content = Column(
      children: [
        titleBlock,
        SizedBox(height: r.scale(8, tablet: 10)),
        bodyBlock,
        if (giftsBlock != null) ...[
          SizedBox(height: r.scale(short ? 10 : 14)),
          giftsBlock,
        ],
        SizedBox(height: r.scale(short ? 14 : 18)),
        featuresBlock,
      ],
    );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: r.scale(420, tablet: 520, desktop: 560),
        ),
        child: Column(
          children: [
            const Spacer(flex: 1),
            if (page.titleFirst) ...[
              FadeTransition(
                opacity: _contentFade,
                child: SlideTransition(
                  position: _contentSlide,
                  child: Column(
                    children: [
                      titleBlock,
                      SizedBox(height: r.scale(8, tablet: 10)),
                      bodyBlock,
                    ],
                  ),
                ),
              ),
              SizedBox(height: r.scale(short ? 10 : 14)),
              imageBlock,
              FadeTransition(
                opacity: _contentFade,
                child: SlideTransition(
                  position: _contentSlide,
                  child: Column(
                    children: [
                      if (giftsBlock != null) ...[
                        SizedBox(height: r.scale(short ? 10 : 14)),
                        giftsBlock,
                      ],
                      SizedBox(height: r.scale(short ? 10 : 12)),
                      featuresBlock,
                    ],
                  ),
                ),
              ),
            ] else ...[
              imageBlock,
              const Spacer(flex: 1),
              FadeTransition(
                opacity: _contentFade,
                child: SlideTransition(
                  position: _contentSlide,
                  child: content,
                ),
              ),
            ],
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}

class _GiftHighlightCard extends StatelessWidget {
  const _GiftHighlightCard({required this.highlight});

  final _GiftHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final isDark = AppColors.isDark(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(10),
        vertical: r.scale(12),
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE5E5EA),
        ),
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: r.scale(13),
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.darkTextPrimary
                : const Color(0xFF1A1F2C),
          ),
          children: [
            TextSpan(text: '${highlight.label} → '),
            TextSpan(
              text: highlight.value,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

enum _FeatureStyle { outlineIcons, chips, tags }

class _FeaturesRow extends StatelessWidget {
  const _FeaturesRow({
    required this.features,
    required this.style,
    required this.compact,
  });

  final List<_FeatureItem> features;
  final _FeatureStyle style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < features.length; i++) ...[
          if (i > 0) SizedBox(width: r.scale(style == _FeatureStyle.chips ? 8 : 10)),
          Expanded(
            child: switch (style) {
              _FeatureStyle.outlineIcons => _OutlineFeature(
                  item: features[i],
                  compact: compact,
                ),
              _FeatureStyle.chips => _ChipFeature(
                  item: features[i],
                  compact: compact,
                ),
              _FeatureStyle.tags => _TagFeature(item: features[i]),
            },
          ),
        ],
      ],
    );
  }
}

class _OutlineFeature extends StatelessWidget {
  const _OutlineFeature({required this.item, required this.compact});

  final _FeatureItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final isDark = AppColors.isDark(context);
    final color = isDark
        ? AppColors.darkTextPrimary
        : const Color(0xFF3A3A3C);

    return Column(
      children: [
        Icon(
          item.icon ?? Icons.star_outline_rounded,
          size: r.scale(compact ? 26 : 28),
          color: color,
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
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ChipFeature extends StatelessWidget {
  const _ChipFeature({required this.item, required this.compact});

  final _FeatureItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final isDark = AppColors.isDark(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(8),
        vertical: r.scale(compact ? 10 : 12),
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
        border: isDark
            ? Border.all(color: AppColors.darkBorder)
            : null,
      ),
      child: Column(
        children: [
          Icon(
            item.icon ?? Icons.star_outline_rounded,
            size: r.scale(compact ? 18 : 20),
            color: isDark
                ? AppColors.darkTextPrimary
                : const Color(0xFF1C1C1E),
          ),
          SizedBox(height: r.scale(6)),
          Text(
            item.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.scale(compact ? 10 : 11, tablet: 12),
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : const Color(0xFF1C1C1E),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagFeature extends StatelessWidget {
  const _TagFeature({required this.item});

  final _FeatureItem item;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final isDark = AppColors.isDark(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(8),
        vertical: r.scale(8),
      ),
      decoration: BoxDecoration(     
                    color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE5E5EA),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        item.title,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: r.scale(11, tablet: 12),
          fontWeight: FontWeight.w600,
          color: isDark
              ? AppColors.darkTextPrimary
              : const Color(0xFF3A3A3C),
        ),
      ),
    );
  }
}

class _FeatureItem {
  const _FeatureItem({
    required this.title,
    this.icon,
  });

  final IconData? icon;
  final String title;
}

class _GiftHighlight {
  const _GiftHighlight({required this.label, required this.value});

  final String label;
  final String value;
}

class _OnboardPage {
  const _OnboardPage({
    required this.image,
    required this.title,
    required this.titleAccent,
    required this.body,
    required this.features,
    this.darkImage,
    this.giftHighlights = const [],
    this.featureStyle = _FeatureStyle.outlineIcons,
    this.titleFirst = false,
  });

  final String image;
  final String? darkImage;
  final String title;
  final String titleAccent;
  final String body;
  final List<_FeatureItem> features;
  final List<_GiftHighlight> giftHighlights;
  final _FeatureStyle featureStyle;
  final bool titleFirst;
}

/// Renders PNG assets normally, and SVG assets that may wrap an embedded PNG.
class _OnboardImage extends StatefulWidget {
  const _OnboardImage({required this.assetPath});

  final String assetPath;

  @override
  State<_OnboardImage> createState() => _OnboardImageState();
}

class _OnboardImageState extends State<_OnboardImage> {
  static final RegExp _embeddedPngPattern = RegExp(
    r'(?:xlink:)?href="data:image\/png;base64,([^"]+)"',
  );

  static final Map<String, Future<Widget>> _cache = {};

  late final Future<Widget> _imageFuture = _cache.putIfAbsent(
    widget.assetPath,
    () => _loadImage(widget.assetPath),
  );

  static Future<Widget> _loadImage(String assetPath) async {
    if (!assetPath.toLowerCase().endsWith('.svg')) {
      return Image.asset(
        assetPath,
        fit: BoxFit.contain,
        width: double.infinity,
        filterQuality: FilterQuality.high,
      );
    }

    final svgText = await rootBundle.loadString(assetPath);
    final match = _embeddedPngPattern.firstMatch(svgText);
    if (match != null) {
      final bytes = base64Decode(match.group(1)!);
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        width: double.infinity,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
      );
    }
    return SvgPicture.string(svgText, fit: BoxFit.contain);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.assetPath.toLowerCase().endsWith('.svg')) {
      return Image.asset(
        widget.assetPath,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      );
    }

    return FutureBuilder<Widget>(
      future: _imageFuture,
      builder: (context, snapshot) {
        return snapshot.data ?? const SizedBox.shrink();
      },
    );
  }
}
