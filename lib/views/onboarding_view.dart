import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/onboarding_controller.dart';
import '../core/responsive.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_page.dart';

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
      title: 'Eat Healthy Live Healthy',
      body: 'Track meals and build better eating habits every day.',
    ),
    _OnboardPage(
      image: 'assets/image/onboarding2.png',
      title: 'AI Powered Tracking',
      body: 'Scan food or search quickly to log calories with ease.',
    ),
    _OnboardPage(
      image: 'assets/image/onboarding3.png',
      title: 'Personalized For You',
      body: 'Goals and macros tailored to your body and lifestyle.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleNext() {
    final isLast = _controller.pageIndex.value == _pages.length - 1;

    if (isLast) {
      Get.offNamed(AppRoutes.login);
    } else {
      _controller.nextPage(_pages.length);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final horizontalPadding = r.pagePadding.left;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: _controller.goToPage,
                  itemBuilder: (_, index) {
                    final page = _pages[index];

                    return ResponsivePage(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          const Spacer(flex: 2),
                          Flexible(
                            flex: 5,
                            child: Image.asset(
                              page.image,
                              fit: BoxFit.contain,
                            ),
                          ),
                          SizedBox(height: r.scale(28, tablet: 32)),
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: r.scale(26, tablet: 30, desktop: 34),
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: r.scale(12)),
                          Text(
                            page.body,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: r.scale(15, tablet: 16, desktop: 17),
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(flex: 3),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Obx(() {
                final currentIndex = _controller.pageIndex.value;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: currentIndex == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: currentIndex == index
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                  ),
                );
              }),
              SizedBox(height: r.scale(20)),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: r.formMaxWidth),
                child: Obx(() {
                  final isLast =
                      _controller.pageIndex.value == _pages.length - 1;
                  return PrimaryButton(
                    label: isLast ? 'Get Started' : 'Next',
                    onPressed: _handleNext,
                  );
                }),
              ),
              SizedBox(height: r.scale(12)),
            ],
          ),
        ),  
      ),
    );
  }
}

class _OnboardPage {
  const _OnboardPage({
    required this.image,
    required this.title,
    required this.body,
  }); 

  final String image;
  final String title;
  final String body;
}
