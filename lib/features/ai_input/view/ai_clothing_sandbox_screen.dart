import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import '../providers/ai_import_notifier.dart';

/// Page 1 of the AI import flow: lets the user pick images (gallery or camera)
/// and pushes to [AiResultsScreen] once the selection is confirmed.
///
/// Resets [AiImportNotifier] before each new pick so that returning from
/// the results page always starts a clean session.
class AiClothingSandboxScreen extends ConsumerStatefulWidget {
  final String houseId;

  const AiClothingSandboxScreen({super.key, required this.houseId});

  @override
  ConsumerState<AiClothingSandboxScreen> createState() =>
      _AiClothingSandboxScreenState();
}

class _AiClothingSandboxScreenState
    extends ConsumerState<AiClothingSandboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(aiImportNotifierProvider.notifier)
          .setSelectedHouseId(widget.houseId);
    });
  }

  // ── Picker ────────────────────────────────────────────────────────────────

  Future<void> _showPickerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('ai_import.source_gallery'.tr()),
              subtitle: Text('ai_import.gallery_subtitle'.tr(args: ['5'])),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text('ai_import.source_camera'.tr()),
              subtitle: Text('ai_import.camera_subtitle'.tr()),
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
    notifier.setSelectedHouseId(widget.houseId);
    // processFiles synchronously sets isLoading=true before the first await,
    // so Page 2 always renders in the loading state.
    unawaited(notifier.processFiles(files));
    context.push('/houses/${widget.houseId}/ai-import/results');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StickyCtaScaffold(
      appBar: AppBar(title: Text('ai_import.title'.tr())),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.spacingMd),
          child: SizedBox(
            height: context.screenHeight * 0.6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: context.iconSizeHero,
                  color: colorScheme.outlineVariant,
                ),
                SizedBox(height: context.spacingMd),
                Text(
                  'ai_import.empty_title'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: context.spacingSm),
                Text(
                  'ai_import.empty_subtitle'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outlineVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomContent: UniversalActionBar(
        primaryLabel: 'ai_import.pick_images'.tr(),
        primaryIcon: Icons.add_photo_alternate_outlined,
        onPrimaryPressed: _showPickerSheet,
      ),
    );
  }
}
