import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/analytics/core_analytics_service.dart';
import '../../../features/onboarding/providers/onboarding_status_provider.dart';
import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import 'widgets/content_slide.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  static const _pageNames = ['houses', 'items', 'trips'];

  bool get _isLastPage => _currentPage == _pageNames.length - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(coreAnalyticsServiceProvider).trackOnboardingStarted();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    if (_isLastPage) {
      await _handleComplete();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleComplete() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      ref.read(coreAnalyticsServiceProvider).trackOnboardingCompleted();
      await ref.read(onboardingStatusProvider.notifier).markCompleted();
      if (mounted && ref.read(onboardingStatusProvider) is AsyncError) {
        AppSnackBar.showError(context, 'Errore. Riprova.');
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Expanded(
              flex: 6,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  ref
                      .read(analyticsServiceProvider)
                      .logEvent(
                        'onboarding_page_viewed',
                        properties: {
                          'page_index': index,
                          'page_name': _pageNames[index],
                        },
                      );
                },
                children: const [
                  ContentSlide(
                    icon: Icons.home_outlined,
                    videoAsset: 'assets/onboarding/houses.mp4',
                    titleKey: 'onboarding.houses.title',
                    descriptionKey: 'onboarding.houses.description',
                  ),
                  ContentSlide(
                    icon: Icons.inventory_2_outlined,
                    videoAsset: 'assets/onboarding/items.mp4',
                    titleKey: 'onboarding.items.title',
                    descriptionKey: 'onboarding.items.description',
                  ),
                  ContentSlide(
                    icon: Icons.luggage_outlined,
                    videoAsset: 'assets/onboarding/trips.mp4',
                    titleKey: 'onboarding.trips.title',
                    descriptionKey: 'onboarding.trips.description',
                  ),
                ],
              ),
            ),
            const Spacer(),
            _DotsIndicator(
              count: 3,
              currentIndex: _currentPage,
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Theme.of(context).colorScheme.outlineVariant,
            ),
            SizedBox(height: context.spacingMd),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
              child: UniversalActionBar(
                primaryLabel: !_isLastPage
                    ? 'onboarding.next'.tr()
                    : 'onboarding.start'.tr(),
                onPrimaryPressed: _handleNext,
                isLoading: _isLastPage && _isCompleting,
              ),
            ),
            SizedBox(height: context.spacingMd),
          ],
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final Color activeColor;
  final Color inactiveColor;

  const _DotsIndicator({
    required this.count,
    required this.currentIndex,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
