import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../features/ai_input/providers/ai_import_notifier.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_text_button.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import '../../ai_input/helpers/start_ai_scan.dart';
import '../../ai_input/view/widgets/image_source_sheet.dart';
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

  Future<void> _showSourceSheet() async {
    final source = await showImageSourceSheet(context);
    switch (source) {
      case ImageSource.gallery:
        await _pickFromGallery();
      case ImageSource.camera:
        await _pickFromCamera();
      case null:
        return;
    }
  }

  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: kAiScanMaxImageSide,
      maxHeight: kAiScanMaxImageSide,
    );
    if (picked == null || !mounted) return;
    _startProcessing([File(picked.path)]);
  }

  Future<void> _pickFromCamera() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: kAiScanMaxImageSide,
      maxHeight: kAiScanMaxImageSide,
    );
    if (picked == null || !mounted) return;
    _startProcessing([File(picked.path)]);
  }

  void _startProcessing(List<File> files) {
    final notifier = ref.read(aiImportNotifierProvider.notifier);
    notifier.reset();
    // processFiles synchronously sets isLoading=true before the first await,
    // so AiResultsScreen always renders in the loading state.
    unawaited(notifier.processFiles(files));
    context.push('/onboarding-ai-intro/results');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Stessa forma delle slide di benvenuto: "Salta" in alto a destra, testo
    // al centro, un solo bottone pieno in fondo.
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(right: context.spacingSm),
                child: DsTextButton(
                  key: const Key('ai_intro_skip'),
                  onPressed: _handleSkip,
                  label: 'onboarding_tour.ai_intro.skip'.tr(),
                ),
              ),
            ),
            const Spacer(),
            Icon(
              Icons.auto_awesome_outlined,
              size: context.iconSizeHero,
              color: colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: context.spacingLg),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacingLg),
              child: Text(
                'onboarding_tour.ai_intro.title'.tr(),
                style: textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: context.spacingMd),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacingLg),
              child: Text(
                'onboarding_tour.ai_intro.body'.tr(),
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spacingMd),
              child: UniversalActionBar(
                primaryLabel: 'onboarding_tour.ai_intro.cta'.tr(),
                primaryIcon: Icons.photo_camera_outlined,
                onPrimaryPressed: _showSourceSheet,
              ),
            ),
            SizedBox(height: context.spacingMd),
          ],
        ),
      ),
    );
  }
}
