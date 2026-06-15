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

  Future<void> _showSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('ai_import.source_gallery'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text('ai_import.source_camera'.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickFromCamera();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final pickedFiles = await ImagePicker().pickMultiImage(
      imageQuality: 80,
      limit: 5,
    );
    if (pickedFiles.isEmpty || !mounted) return;
    _startProcessing(pickedFiles.map((f) => File(f.path)).toList());
  }

  Future<void> _pickFromCamera() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
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
              onPrimaryPressed: _showSourceSheet,
              rightAction: TextButton(
                onPressed: _handleSkip,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
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
