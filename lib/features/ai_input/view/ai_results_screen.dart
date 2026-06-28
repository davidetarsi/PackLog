import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/circular_action_button.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import '../../houses/model/house_model.dart';
import '../../houses/providers/house_provider.dart';
import '../../tour/tour_keys.dart';
import '../model/ai_import_state.dart';
import '../providers/ai_import_notifier.dart';
import 'widgets/ai_photo_group_header.dart';
import 'widgets/ai_result_card.dart';

/// Page 2 of the AI import flow: shows loading progress while GPT-4o Vision
/// analyses the images, then the editable results list with save CTA.
///
/// Always reached by pushing from [AiClothingSandboxScreen] (normal flow) or
/// [AiOnboardingIntroScreen] (onboarding flow), both of which call
/// [AiImportNotifier.processFiles] before navigating here.
class AiResultsScreen extends ConsumerStatefulWidget {
  final String? houseId;
  final bool isFirstTimeOnboarding;

  const AiResultsScreen({
    super.key,
    this.houseId,
    required this.isFirstTimeOnboarding,
  });

  @override
  ConsumerState<AiResultsScreen> createState() => _AiResultsScreenState();
}

class _AiResultsScreenState extends ConsumerState<AiResultsScreen> {
  final List<List<TextEditingController>> _controllers = [];
  bool _onboardingTooltipShown = false;
  Timer? _nameDebounce;

  @override
  void dispose() {
    _nameDebounce?.cancel();
    for (final group in _controllers) {
      for (final c in group) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _syncControllers(AiImportState? prev, AiImportState next) {
    final wasEmpty = _controllers.isEmpty;

    while (_controllers.length < next.photoGroups.length) {
      final gi = _controllers.length;
      _controllers.add(
        next.photoGroups[gi].results
            .map((r) => TextEditingController(text: r.name))
            .toList(),
      );
    }
    while (_controllers.length > next.photoGroups.length) {
      for (final c in _controllers.last) {
        c.dispose();
      }
      _controllers.removeLast();
    }
    for (var gi = 0; gi < _controllers.length; gi++) {
      final resultCount = next.photoGroups[gi].results.length;
      while (_controllers[gi].length < resultCount) {
        final ii = _controllers[gi].length;
        _controllers[gi].add(
          TextEditingController(text: next.photoGroups[gi].results[ii].name),
        );
      }
      while (_controllers[gi].length > resultCount) {
        _controllers[gi].last.dispose();
        _controllers[gi].removeLast();
      }
    }

    // Select all text in the first field when results first appear so the user
    // immediately sees the field is editable.
    if (wasEmpty && _controllers.isNotEmpty && _controllers[0].isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final c = _controllers[0][0];
        if (c.text.isNotEmpty) {
          c.selection = TextSelection(
            baseOffset: 0,
            extentOffset: c.text.length,
          );
        }
      });
    }
  }

  // ── Picker (add more photos) ──────────────────────────────────────────────

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
    await ref.read(aiImportNotifierProvider.notifier).processFiles([
      File(picked.path),
    ]);
  }

  // ── Onboarding tooltip ────────────────────────────────────────────────────

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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiImportNotifierProvider);
    final notifier = ref.read(aiImportNotifierProvider.notifier);

    ref.listen<AiImportState>(aiImportNotifierProvider, (prev, next) {
      _syncControllers(prev, next);

      if (widget.isFirstTimeOnboarding &&
          next.photoGroups.isNotEmpty &&
          !_onboardingTooltipShown) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showAiSaveTooltip();
        });
      }

      // Detect successful save: results gone, no error, not loading
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
        if (!widget.isFirstTimeOnboarding && widget.houseId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/houses/${widget.houseId}');
          });
        }
        // In onboarding mode the router redirect handles navigation when
        // the onboarding step advances inside saveItemsOnboarding().
      }
    });

    return StickyCtaScaffold(
      appBar: AppBar(title: Text('ai_import.title'.tr())),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.spacingMd),
          child: _buildBody(context, aiState, notifier),
        ),
      ),
      bottomContent: _buildBottomContent(context, aiState, notifier),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AiImportState state,
    AiImportNotifier notifier,
  ) {
    if (state.isLoading) return _buildLoading(context, state);
    if (state.photoGroups.isEmpty) return _buildEmptyError(context, state);
    return _buildResults(context, state, notifier);
  }

  // ── Bottom CTA ────────────────────────────────────────────────────────────

  Widget? _buildBottomContent(
    BuildContext context,
    AiImportState state,
    AiImportNotifier notifier,
  ) {
    if (state.isLoading) return null;
    if (state.photoGroups.isEmpty) return null;
    return _buildResultsBar(context, state, notifier);
  }

  // ── Results bottom bar ────────────────────────────────────────────────────

  Widget _buildResultsBar(
    BuildContext context,
    AiImportState state,
    AiImportNotifier notifier,
  ) {
    final totalItems = state.photoGroups.expand((g) => g.results).length;

    // AI found nothing: offer to pick another photo instead of a useless save.
    if (totalItems == 0) {
      return UniversalActionBar(
        primaryLabel: 'ai_import.retry_photo'.tr(),
        primaryIcon: Icons.add_photo_alternate_outlined,
        onPrimaryPressed: _showPickerSheet,
      );
    }

    final String primaryLabel;
    final VoidCallback? onPrimaryPressed;

    if (widget.isFirstTimeOnboarding) {
      primaryLabel = 'ai_import.save_button'.tr(args: [totalItems.toString()]);
      onPrimaryPressed = state.isLoading ? null : notifier.saveItemsOnboarding;
    } else {
      final houses = ref.watch(houseNotifierProvider).valueOrNull ?? [];
      final matching = houses.where((h) => h.id == state.selectedHouseId);
      final HouseModel? selectedHouse = matching.isEmpty
          ? null
          : matching.first;

      if (selectedHouse != null) {
        primaryLabel = 'ai_import.save_in_house'.tr(
          args: [selectedHouse.name, totalItems.toString()],
        );
        onPrimaryPressed = state.isLoading ? null : notifier.saveItems;
      } else {
        primaryLabel = 'ai_import.choose_house'.tr();
        onPrimaryPressed = null;
      }
    }

    // rightAction removed: one photo per session.
    return UniversalActionBar(
      primaryLabel: primaryLabel,
      isLoading: state.isLoading,
      onPrimaryPressed: onPrimaryPressed,
      leftAction: !widget.isFirstTimeOnboarding
          ? CircularActionButton(
              icon: Icons.other_houses_outlined,
              onPressed: state.isLoading
                  ? null
                  : () => _showHousePicker(state, notifier),
            )
          : null,
    );
  }

  Future<void> _showHousePicker(
    AiImportState state,
    AiImportNotifier notifier,
  ) async {
    final houses = ref.read(houseNotifierProvider).valueOrNull;
    if (houses == null || houses.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.spacingMd,
                context.spacingMd,
                context.spacingMd,
                context.spacingXs,
              ),
              child: Text(
                'ai_import.choose_house_title'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.only(bottom: context.spacingSm),
                itemCount: houses.length,
                itemBuilder: (context, index) {
                  final house = houses[index];
                  final isSelected = state.selectedHouseId == house.id;
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.home : Icons.home_outlined,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(house.name),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      notifier.setSelectedHouseId(house.id);
                      Navigator.pop(sheetContext);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Loading state ─────────────────────────────────────────────────────────

  Widget _buildLoading(BuildContext context, AiImportState state) {
    final progress = state.totalImages > 0
        ? state.processingIndex / state.totalImages
        : null;
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
                  state.photoGroups.expand((g) => g.results).length.toString(),
                ],
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.primary),
            ),
          ],
        ],
      ),
    );
  }

  // ── Empty / error on Page 2 ───────────────────────────────────────────────

  Widget _buildEmptyError(BuildContext context, AiImportState state) {
    if (state.errorMessage == null) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
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
    );
  }

  // ── Results state ─────────────────────────────────────────────────────────

  Widget _buildResults(
    BuildContext context,
    AiImportState state,
    AiImportNotifier notifier,
  ) {
    final allResults = state.photoGroups.expand((g) => g.results).toList();
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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

        for (var gi = 0; gi < state.photoGroups.length; gi++) ...[
          AiPhotoGroupHeader(
            photo: state.photoGroups[gi].photo,
            photoIndex: gi + 1,
            totalPhotos: state.photoGroups.length,
          ),
          SizedBox(height: context.spacingSm),
          if (gi < _controllers.length)
            for (var ii = 0; ii < state.photoGroups[gi].results.length; ii++)
              if (ii < _controllers[gi].length)
                Padding(
                  padding: EdgeInsets.only(bottom: context.spacingMd),
                  child: AiResultCard(
                    item: state.photoGroups[gi].results[ii],
                    index: ii + 1,
                    controller: _controllers[gi][ii],
                    autofocus: gi == 0 && ii == 0,
                    onNameChanged: (value) {
                      _nameDebounce?.cancel();
                      _nameDebounce = Timer(
                        const Duration(milliseconds: 300),
                        () => notifier.updateItemName(gi, ii, value),
                      );
                    },
                    onDelete: () => notifier.deleteItem(gi, ii),
                  ),
                ),
          if (gi < state.photoGroups.length - 1)
            Padding(
              padding: EdgeInsets.symmetric(vertical: context.spacingSm),
              child: Divider(color: colorScheme.outlineVariant),
            ),
        ],

        if (state.errorMessage != null) ...[
          SizedBox(height: context.spacingMd),
          Container(
            padding: EdgeInsets.all(context.spacingMd),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(
                AppConstants.inputBorderRadius,
              ),
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
}
