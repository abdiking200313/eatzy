import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_cards.dart';
import '../../../widgets/zivo_logo.dart';
import 'onboarding_page_1.dart';
import 'onboarding_page_2.dart';
import 'onboarding_page_3.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const List<Widget> _pages = [
    OnboardingPage1(),
    OnboardingPage2(),
    OnboardingPage3(),
  ];

  late PageController _pageController;
  int _currentPage = 0;

  void _openMainApp() {
    context.go(AppRoutes.mainApp);
  }

  void _openRegister() {
    context.push(AppRoutes.register);
  }

  void _openLogin() {
    context.push(AppRoutes.login);
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            children: _pages,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: null,
              titleSpacing: TwSpacing.x5,
              title: const ZivoLogo(height: 34),
              actions: [
                TextButton(
                  onPressed: _openMainApp,
                  child: Text(
                    'Skip',
                    style: TwText.fontBoldSm.copyWith(color: TwColors.primary),
                  ),
                ),
                const SizedBox(width: TwSpacing.x5),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(TwSpacing.x5),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: index == _currentPage ? 32 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(
                          horizontal: TwSpacing.x2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(TwRadius.full),
                          color: index == _currentPage
                              ? TwColors.primary
                              : TwColors.borderStrong,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: TwSpacing.x8),
                  GradientActionButton(
                    label: 'Get Started',
                    onPressed: _openRegister,
                    icon: const Icon(
                      Icons.arrow_forward,
                      color: TwColors.onPrimary,
                    ),
                    fontSize: 18,
                  ),
                  const SizedBox(height: TwSpacing.x5),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Already have an account? ',
                          style: TwText.textXs.copyWith(
                            color: TwColors.textMuted,
                          ),
                        ),
                        WidgetSpan(
                          child: TextButton(
                            onPressed: _openLogin,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text('Log In', style: TwText.link),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
