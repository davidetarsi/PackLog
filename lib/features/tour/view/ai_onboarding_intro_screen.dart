import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import '../providers/post_login_onboarding_provider.dart';

class AiOnboardingIntroScreen extends ConsumerStatefulWidget {
  const AiOnboardingIntroScreen({super.key});

  @override
  ConsumerState<AiOnboardingIntroScreen> createState() =>
      _AiOnboardingIntroScreenState();
}

class _AiOnboardingIntroScreenState
    extends ConsumerState<AiOnboardingIntroScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(analyticsServiceProvider).logEvent('ai_onboarding_started');
      }
    });
  }

  void _handleSkip() {
    ref.read(analyticsServiceProvider).logEvent('ai_onboarding_skipped');
    ref.read(postLoginOnboardingProvider.notifier).skipAi();
    // Router redirect handles navigation when step changes from aiIntro.
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(
              Icons.auto_awesome,
              size: context.iconSizeHero,
              color: colorScheme.primary,
            ),
            SizedBox(height: context.spacingLg),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacingLg),
              child: Text(
                'onboarding_tour.ai_intro.title'.tr(),
                style: textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: context.spacingMd),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacingLg),
              child: Text(
                'onboarding_tour.ai_intro.body'.tr(),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(),
            UniversalActionBar(
              primaryLabel: 'onboarding_tour.ai_intro.cta'.tr(),
              primaryIcon: Icons.photo_camera_outlined,
              onPrimaryPressed: () =>
                  context.push('/onboarding-ai-intro/sandbox'),
              rightAction: TextButton(
                onPressed: _handleSkip,
                child: Text('onboarding_tour.ai_intro.skip'.tr()),
              ),
            ),
            SizedBox(height: context.spacingMd),
          ],
        ),
      ),
    );
  }
}
