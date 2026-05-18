import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../features/onboarding/providers/onboarding_status_provider.dart';
import '../../../shared/providers/language_locale.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import 'widgets/content_slide.dart';
import 'widgets/language_slide.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Locale? _selectedLocale;
  bool _localeApplied = false;

  static const _pageNames = ['language', 'houses', 'items', 'trips'];

  bool get _isNextEnabled {
    if (_currentPage == 0) return _selectedLocale != null;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _initDefaultLocale();
    ref.read(analyticsServiceProvider).logEvent('onboarding_started');
  }

  void _initDefaultLocale() {
    final deviceLang =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    const supported = {
      'it': Locale('it', 'IT'),
      'en': Locale('en', 'US'),
    };
    final match = supported[deviceLang];
    if (match != null) {
      setState(() => _selectedLocale = match);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onLocaleTapped(Locale locale) async {
    await context.setLocale(locale);
    _localeApplied = true;
    ref.read(languageLocaleProvider.notifier).updateLocale(locale.languageCode);
    setState(() => _selectedLocale = locale);
    ref.read(analyticsServiceProvider).logEvent(
      'onboarding_language_selected',
      properties: {'language': locale.languageCode},
    );
  }

  Future<void> _ensureLocaleApplied() async {
    if (!_localeApplied && _selectedLocale != null) {
      await _onLocaleTapped(_selectedLocale!);
    }
  }

  Future<void> _handleNext() async {
    if (_currentPage == 0) {
      await _ensureLocaleApplied();
    }
    if (_currentPage == 3) {
      await _handleComplete();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleComplete() async {
    ref.read(analyticsServiceProvider).logEvent(
      'onboarding_completed',
      properties: {'language': _selectedLocale?.languageCode ?? 'unknown'},
    );
    await ref.read(onboardingStatusProvider.notifier).markCompleted();
    // Router redirects automatically via _AuthChangeNotifier
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
                  ref.read(analyticsServiceProvider).logEvent(
                    'onboarding_page_viewed',
                    properties: {
                      'page_index': index,
                      'page_name': _pageNames[index],
                    },
                  );
                },
                children: [
                  LanguageSlide(
                    selectedLocale: _selectedLocale,
                    onLocaleTapped: _onLocaleTapped,
                  ),
                  const ContentSlide(
                    icon: Icons.home_outlined,
                    titleKey: 'onboarding.houses.title',
                    descriptionKey: 'onboarding.houses.description',
                  ),
                  const ContentSlide(
                    icon: Icons.inventory_2_outlined,
                    titleKey: 'onboarding.items.title',
                    descriptionKey: 'onboarding.items.description',
                  ),
                  const ContentSlide(
                    icon: Icons.luggage_outlined,
                    titleKey: 'onboarding.trips.title',
                    descriptionKey: 'onboarding.trips.description',
                  ),
                ],
              ),
            ),
            const Spacer(),
            _DotsIndicator(
              count: 4,
              currentIndex: _currentPage,
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Theme.of(context).colorScheme.outlineVariant,
            ),
            SizedBox(height: context.spacingMd),
            UniversalActionBar(
              primaryLabel: _currentPage < 3
                  ? 'onboarding.next'.tr()
                  : 'onboarding.start'.tr(),
              onPrimaryPressed: _isNextEnabled ? _handleNext : null,
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
