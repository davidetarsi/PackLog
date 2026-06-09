import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../houses/providers/house_provider.dart';
import '../../tour/tour_keys.dart';
import '../model/ai_import_state.dart';
import '../providers/ai_import_notifier.dart';
import 'widgets/ai_photo_group_header.dart';
import 'widgets/ai_result_card.dart';

/// AI Bulk Import screen: picks up to 5 images (gallery or camera), runs them
/// through GPT-4o Vision sequentially, and lets the user review/edit results
/// before saving to the DB.
///
/// All AI state lives in [AiImportNotifier]; the screen manages only
/// [TextEditingController]s and the onboarding tooltip flag.
class AiClothingSandboxScreen extends ConsumerStatefulWidget {
  final String? houseId;
  final bool isFirstTimeOnboarding;
  final ImageSource? autoSource;

  const AiClothingSandboxScreen({
    super.key,
    this.houseId,
    this.isFirstTimeOnboarding = false,
    this.autoSource,
  }) : assert(
          !isFirstTimeOnboarding || houseId == null,
          'In onboarding mode houseId must be null',
        ),
       assert(
          isFirstTimeOnboarding || houseId != null,
          'houseId is required when not in onboarding mode',
        );

  @override
  ConsumerState<AiClothingSandboxScreen> createState() =>
      _AiClothingSandboxScreenState();
}

class _AiClothingSandboxScreenState
    extends ConsumerState<AiClothingSandboxScreen> {
  final List<List<TextEditingController>> _controllers = [];
  bool _onboardingTooltipShown = false;

  @override
  void initState() {
    super.initState();
    // Set the initial house selection in the notifier
    if (widget.houseId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(aiImportNotifierProvider.notifier)
              .setSelectedHouseId(widget.houseId!);
        }
      });
    }
    // Auto-trigger picker if source was pre-selected (from onboarding intro)
    if (widget.autoSource != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.autoSource == ImageSource.gallery) {
          _pickFromGallery();
        } else {
          _pickFromCamera();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final group in _controllers) {
      for (final c in group) {
        c.dispose();
      }
    }
    // Reset notifier state when screen is disposed.
    // Use addPostFrameCallback to avoid modifying provider during dispose.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiImportNotifierProvider.notifier).reset();
    });
    super.dispose();
  }

  void _syncControllers(AiImportState? prev, AiImportState next) {
    // Groups added
    while (_controllers.length < next.photoGroups.length) {
      final gi = _controllers.length;
      _controllers.add(
        next.photoGroups[gi].results
            .map((r) => TextEditingController(text: r.name))
            .toList(),
      );
    }
    // Groups removed
    while (_controllers.length > next.photoGroups.length) {
      for (final c in _controllers.last) {
        c.dispose();
      }
      _controllers.removeLast();
    }
    // Items removed within a group
    for (var gi = 0; gi < _controllers.length; gi++) {
      final resultCount = next.photoGroups[gi].results.length;
      while (_controllers[gi].length > resultCount) {
        _controllers[gi].last.dispose();
        _controllers[gi].removeLast();
      }
    }
  }

  // ── Picker ───────────────────────────────────────────────────────────────────

  Future<void> _showPickerSheet() async {
    final notifier = ref.read(aiImportNotifierProvider.notifier);
    if (notifier.remainingSlots <= 0) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('ai_import.source_gallery'.tr()),
              subtitle: Text(
                'ai_import.gallery_subtitle'.tr(
                  args: [notifier.remainingSlots.toString()],
                ),
              ),
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
    final notifier = ref.read(aiImportNotifierProvider.notifier);
    final pickedFiles = await ImagePicker().pickMultiImage(
      imageQuality: 80,
      limit: notifier.remainingSlots,
    );
    if (pickedFiles.isEmpty || !mounted) return;
    await notifier.processFiles(pickedFiles.map((f) => File(f.path)).toList());
  }

  Future<void> _pickFromCamera() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    await ref
        .read(aiImportNotifierProvider.notifier)
        .processFiles([File(picked.path)]);
  }

  // ── Onboarding tooltip ───────────────────────────────────────────────────────

  void _showAiSaveTooltip() {
    if (_onboardingTooltipShown) return;
    setState(() => _onboardingTooltipShown = true);
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: 'ai_save_tooltip',
          keyTarget: tourKeys.infoCardTarget,
          shape: ShapeLightFocus.Circle,
          radius: 1,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (ctx, controller) {
                final colorScheme = Theme.of(context).colorScheme;
                final textTheme = Theme.of(context).textTheme;
                return Container(
                  padding: EdgeInsets.all(context.spacingMd),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(
                      AppConstants.cardBorderRadius,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'onboarding_tour.ai_save_tooltip'.tr(),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: context.spacingMd),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () => controller.next(),
                          child: Text('tour.finish'.tr()),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ],
      colorShadow: Colors.black,
      opacityShadow: 0.8,
      hideSkip: true,
    ).show(context: context);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiImportNotifierProvider);
    final notifier = ref.read(aiImportNotifierProvider.notifier);

    // Sync controllers with state and handle side effects
    ref.listen<AiImportState>(aiImportNotifierProvider, (prev, next) {
      _syncControllers(prev, next);

      // Trigger onboarding tooltip on first results
      if (widget.isFirstTimeOnboarding &&
          next.photoGroups.isNotEmpty &&
          !_onboardingTooltipShown) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAiSaveTooltip();
        });
      }

      // Show success snackbar after save
      if (prev != null &&
          prev.photoGroups.isNotEmpty &&
          !next.isLoading &&
          next.photoGroups.isEmpty &&
          next.errorMessage == null) {
        final count = prev.photoGroups.expand((g) => g.results).length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ai_import.save_success'.tr(args: [count.toString()]),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final canAddMore = !aiState.isLoading && notifier.remainingSlots > 0;

    return Scaffold(
      appBar: AppBar(title: Text('ai_import.title'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: canAddMore ? _showPickerSheet : null,
        icon: const Icon(Icons.add_photo_alternate),
        label: aiState.photoGroups.isEmpty
            ? Text('ai_import.pick_images'.tr())
            : Text(
                'ai_import.add_photos'.tr(
                  args: [aiState.photoGroups.length.toString()],
                ),
              ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: aiState.photoGroups.isNotEmpty
          ? _buildBottomBar(context, aiState, notifier)
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.spacingMd,
            context.spacingMd,
            context.spacingMd,
            context.responsive(100),
          ),
          child: _buildBody(context, aiState, notifier),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AiImportState state,
    AiImportNotifier notifier,
  ) {
    if (state.isLoading) return _buildLoading(context, state);
    if (state.photoGroups.isEmpty) return _buildEmptyState(context);
    return _buildResults(context, state, notifier);
  }

  // ── Empty state ──────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
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
    );
  }

  // ── Loading state ────────────────────────────────────────────────────────────

  Widget _buildLoading(BuildContext context, AiImportState state) {
    final progress =
        state.totalImages > 0 ? state.processingIndex / state.totalImages : null;
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: context.screenHeight * 0.6,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacingLg),
            child: LinearProgressIndicator(value: progress, minHeight: 6),
          ),
          SizedBox(height: context.spacingLg),
          Text(
            state.totalImages > 0
                ? 'ai_import.loading_progress'.tr(
                    args: [
                      state.processingIndex.toString(),
                      state.totalImages.toString(),
                    ],
                  )
                : 'ai_import.loading'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (state.photoGroups.isNotEmpty) ...[
            SizedBox(height: context.spacingMd),
            Text(
              'ai_import.items_found_so_far'.tr(
                args: [
                  state.photoGroups
                      .expand((g) => g.results)
                      .length
                      .toString(),
                ],
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Results state ────────────────────────────────────────────────────────────

  Widget _buildResults(
    BuildContext context,
    AiImportState state,
    AiImportNotifier notifier,
  ) {
    final allResults = notifier.allResults;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Results header ──────────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.only(bottom: context.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.checkroom_outlined,
                    size: context.iconSizeSm,
                    color: colorScheme.primary,
                  ),
                  SizedBox(width: context.spacingXs),
                  Text(
                    'ai_import.items_identified'.tr(
                      args: [allResults.length.toString()],
                    ),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.spacingXs),
              Text(
                'ai_import.edit_hint'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // ── Grouped by photo ────────────────────────────────────────────────
        for (var gi = 0; gi < state.photoGroups.length; gi++) ...[
          AiPhotoGroupHeader(
            photo: state.photoGroups[gi].photo,
            photoIndex: gi + 1,
            totalPhotos: state.photoGroups.length,
          ),
          SizedBox(height: context.spacingSm),
          if (gi < _controllers.length)
            for (var ii = 0;
                ii < state.photoGroups[gi].results.length;
                ii++)
              if (ii < _controllers[gi].length)
                Padding(
                  padding: EdgeInsets.only(bottom: context.spacingMd),
                  child: AiResultCard(
                    item: state.photoGroups[gi].results[ii],
                    index: ii + 1,
                    controller: _controllers[gi][ii],
                    onNameChanged: (value) =>
                        notifier.updateItemName(gi, ii, value),
                    onDelete: () => notifier.deleteItem(gi, ii),
                  ),
                ),
          if (gi < state.photoGroups.length - 1)
            Padding(
              padding: EdgeInsets.symmetric(vertical: context.spacingSm),
              child: Divider(color: colorScheme.outlineVariant),
            ),
        ],

        // ── Error banner (inline) ───────────────────────────────────────────
        if (state.errorMessage != null) ...[
          SizedBox(height: context.spacingMd),
          Container(
            padding: EdgeInsets.all(context.spacingMd),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  size: context.iconSizeSm,
                  color: colorScheme.onErrorContainer,
                ),
                SizedBox(width: context.spacingSm),
                Expanded(
                  child: Text(
                    state.errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Bottom bar (house selector + save) ───────────────────────────────────────

  Widget _buildBottomBar(
    BuildContext context,
    AiImportState state,
    AiImportNotifier notifier,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          context.spacingMd,
          context.spacingSm + context.spacingXs,
          context.spacingMd,
          context.spacingSm,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!widget.isFirstTimeOnboarding) ...[
              Expanded(
                child: _buildHouseDropdown(context, state, notifier),
              ),
              SizedBox(width: context.spacingMd),
            ],
            ElevatedButton(
              onPressed: state.isLoading
                  ? null
                  : () {
                      if (widget.isFirstTimeOnboarding) {
                        notifier.saveItemsOnboarding();
                      } else {
                        notifier.saveItems();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: EdgeInsets.symmetric(
                  horizontal: context.spacingMd,
                  vertical: context.spacingSm,
                ),
              ),
              child: Text(
                'ai_import.save_button'.tr(
                  args: [notifier.allResults.length.toString()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHouseDropdown(
    BuildContext context,
    AiImportState state,
    AiImportNotifier notifier,
  ) {
    final housesAsync = ref.watch(houseNotifierProvider);
    return housesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => Text('errors.load_failed'.tr()),
      data: (houses) => DropdownButtonFormField<String>(
        initialValue: state.selectedHouseId,
        isDense: true,
        decoration: InputDecoration(
          labelText: 'ai_import.destination_house'.tr(),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: context.spacingMd,
            vertical: context.spacingSm,
          ),
        ),
        items: houses
            .map(
              (h) => DropdownMenuItem<String>(
                value: h.id,
                child: Text(h.name),
              ),
            )
            .toList(),
        onChanged: state.isLoading
            ? null
            : (v) {
                if (v != null) notifier.setSelectedHouseId(v);
              },
      ),
    );
  }
}
