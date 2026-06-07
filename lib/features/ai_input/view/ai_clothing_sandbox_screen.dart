import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/monitoring/monitoring_service.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../shared/config/app_config.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../houses/model/house_model.dart';
import '../../houses/providers/house_provider.dart';
import '../../houses/repositories/house_repository.dart';
import '../../items/model/item_model.dart';
import '../../items/providers/item_provider.dart';
import '../../items/repositories/item_repository.dart';
import '../../tour/providers/post_login_onboarding_provider.dart';
import '../../tour/tour_keys.dart';
import '../model/clothing_analysis_result.dart';
import '../service/ai_clothing_analyzer_service.dart';

/// Raggruppa una foto sorgente con i risultati AI estratti da essa.
class _PhotoGroup {
  final File photo;
  final List<ClothingAnalysisResult> results;
  final List<TextEditingController> controllers;

  _PhotoGroup({
    required this.photo,
    required this.results,
    required this.controllers,
  });
}

/// AI Bulk Import screen: picks up to 5 images (gallery or camera), runs them
/// through GPT-4o Vision sequentially, and lets the user review/edit results
/// before saving to the DB.
///
/// Not wired to any provider for its own AI state — uses local state intentionally.
class AiClothingSandboxScreen extends ConsumerStatefulWidget {
  final String? houseId;
  final bool isFirstTimeOnboarding;

  const AiClothingSandboxScreen({
    super.key,
    this.houseId,
    this.isFirstTimeOnboarding = false,
  }) : assert(
          !isFirstTimeOnboarding || houseId == null,
          'In onboarding mode houseId must be null — the house is created at save time',
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
  // ── Local state ─────────────────────────────────────────────────────────────

  final List<_PhotoGroup> _photoGroups = [];
  bool _isLoading = false;
  String? _errorMessage;
  late String? _selectedHouseId = widget.houseId;
  bool _onboardingTooltipShown = false;
  String? _rawJsonDump;
  int _processingIndex = 0;
  int _totalImages = 0;

  final _uuid = const Uuid();

  // ── Computed helpers ─────────────────────────────────────────────────────────

  int get _totalPhotosSelected => _photoGroups.length;
  int get _remainingSlots => 5 - _totalPhotosSelected;
  List<ClothingAnalysisResult> get _allResults =>
      _photoGroups.expand((g) => g.results).toList();

  // ── Service ──────────────────────────────────────────────────────────────────

  late final AiClothingAnalyzerService _service;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _service = AiClothingAnalyzerService(
      proxyUrl: '${AppConfig.supabaseUrl}/functions/v1/openai-proxy',
      anonKey: AppConfig.supabaseAnonKey,
      analytics: ref.read(coreAnalyticsServiceProvider),
      monitoring: ref.read(monitoringServiceProvider),
    );
  }

  @override
  void dispose() {
    for (final group in _photoGroups) {
      for (final c in group.controllers) {
        c.dispose();
      }
    }
    super.dispose();
  }

  // ── Picker ───────────────────────────────────────────────────────────────────

  Future<void> _showPickerSheet() async {
    if (_remainingSlots <= 0) return;

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
                  args: [_remainingSlots.toString()],
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
    final pickedFiles = await ImagePicker().pickMultiImage(
      imageQuality: 80,
      limit: _remainingSlots,
    );
    if (pickedFiles.isEmpty || !mounted) return;
    await _processFiles(pickedFiles.map((f) => File(f.path)).toList());
  }

  Future<void> _pickFromCamera() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    await _processFiles([File(picked.path)]);
  }

  // ── Processing ───────────────────────────────────────────────────────────────

  Future<void> _processFiles(List<File> files) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _processingIndex = 0;
      _totalImages = files.length;
      _errorMessage = null;
    });

    try {
      for (var i = 0; i < files.length; i++) {
        if (!mounted) return;
        setState(() => _processingIndex = i + 1);

        final file = files[i];
        final (processedBytes: _, :result, :rawJson) = await _service
            .processWithIntermediateResult(file);

        if (!mounted) return;
        setState(() {
          final controllers = result
              .map((item) => TextEditingController(text: item.name))
              .toList();
          _photoGroups.add(
            _PhotoGroup(photo: file, results: result, controllers: controllers),
          );
          _rawJsonDump = rawJson;
        });
        if (widget.isFirstTimeOnboarding &&
            _photoGroups.isNotEmpty &&
            !_onboardingTooltipShown) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showAiSaveTooltip();
          });
        }
      }
    } on GptLimitExceededException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
      _showErrorSnackBar(e.message);
    } on ClothingAnalysisException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
      _showErrorSnackBar(e.message);
    } catch (e) {
      if (!mounted) return;
      final msg = 'ai_import.unexpected_error'.tr(args: [e.toString()]);
      setState(() => _errorMessage = msg);
      _showErrorSnackBar(msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Item actions ─────────────────────────────────────────────────────────────

  void _deleteItem(int groupIndex, int itemIndex) {
    setState(() {
      _photoGroups[groupIndex].controllers[itemIndex].dispose();
      _photoGroups[groupIndex].results.removeAt(itemIndex);
      _photoGroups[groupIndex].controllers.removeAt(itemIndex);
      if (_photoGroups[groupIndex].results.isEmpty) {
        _photoGroups.removeAt(groupIndex);
      }
    });
  }

  Future<void> _saveItems() async {
    if (widget.isFirstTimeOnboarding) {
      await _saveItemsOnboarding();
    } else {
      await _saveItemsNormal();
    }
  }

  Future<void> _saveItemsNormal() async {
    final allResults = _allResults;
    if (allResults.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final items = allResults.map((item) {
        return ItemModel(
          id: _uuid.v4(),
          houseId: _selectedHouseId!,
          name: item.name,
          category: _mapCategory(item.category),
          quantity: 1,
          createdAt: now,
          updatedAt: now,
          aiMetadata: jsonEncode(item.toJson()),
        );
      }).toList();

      final repo = ref.read(itemRepositoryProvider);
      await repo.insertMultipleItems(items);
      ref.invalidate(itemNotifierProvider(_selectedHouseId!));
      ref.read(syncOrchestratorProvider).requestSync();

      if (!mounted) return;

      final saved = items.length;
      setState(() {
        for (final group in _photoGroups) {
          for (final c in group.controllers) {
            c.dispose();
          }
        }
        _photoGroups.clear();
        _rawJsonDump = null;
        _errorMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ai_import.save_success'.tr(args: [saved.toString()])),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('ai_import.save_error'.tr(args: [e.toString()]));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveItemsOnboarding() async {
    final allResults = _allResults;
    if (allResults.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final houseId = _uuid.v4();
      final house = HouseModel(
        id: houseId,
        name: 'onboarding.default_house_name'.tr(),
        createdAt: now,
        updatedAt: now,
      );
      final items = allResults.map((item) {
        return ItemModel(
          id: _uuid.v4(),
          houseId: houseId,
          name: item.name,
          category: _mapCategory(item.category),
          quantity: 1,
          createdAt: now,
          updatedAt: now,
          aiMetadata: jsonEncode(item.toJson()),
        );
      }).toList();

      await ref.read(houseRepositoryProvider).createHouseWithItems(house, items);
      ref.invalidate(houseNotifierProvider);
      ref.read(syncOrchestratorProvider).requestSync();

      if (!mounted) return;

      await ref.read(postLoginOnboardingProvider.notifier).completeAi(houseId);

      if (!mounted) return;

      final saved = items.length;
      setState(() {
        for (final group in _photoGroups) {
          for (final c in group.controllers) {
            c.dispose();
          }
        }
        _photoGroups.clear();
        _rawJsonDump = null;
        _errorMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ai_import.save_success'.tr(args: [saved.toString()])),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('ai_import.save_error'.tr(args: [e.toString()]));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Maps the AI category string to the closest [ItemCategory] domain value.
  ItemCategory _mapCategory(String aiCategory) {
    final lower = aiCategory.toLowerCase();
    if (lower.contains('accessory')) {
      return ItemCategory.varie;
    }
    // Upper Body, Lower Body, Outerwear, Shoes → vestiti
    return ItemCategory.vestiti;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

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
                    borderRadius: BorderRadius.circular(16),
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
    final canAddMore = !_isLoading && _remainingSlots > 0;

    return Scaffold(
      appBar: AppBar(title: Text('ai_import.title'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: canAddMore ? _showPickerSheet : null,
        icon: const Icon(Icons.add_photo_alternate),
        label: _totalPhotosSelected == 0
            ? Text('ai_import.pick_images'.tr())
            : Text(
                'ai_import.add_photos'.tr(
                  args: [_totalPhotosSelected.toString()],
                ),
              ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: _photoGroups.isNotEmpty
          ? _buildBottomBar(context)
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.spacingMd,
            context.spacingMd,
            context.spacingMd,
            context.responsive(100),
          ),
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) return _buildLoading(context);
    if (_photoGroups.isEmpty) return _buildEmptyState(context);
    return _buildResults(context);
  }

  // ── Empty state ──────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: context.iconSizeHero,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          SizedBox(height: context.spacingMd),
          Text(
            'ai_import.empty_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.spacingSm),
          Text(
            'ai_import.empty_subtitle'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Loading state ────────────────────────────────────────────────────────────

  Widget _buildLoading(BuildContext context) {
    final progress = _totalImages > 0 ? _processingIndex / _totalImages : null;
    return Center(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: context.responsive(240),
              child: LinearProgressIndicator(value: progress, minHeight: 6),
            ),
            SizedBox(height: context.spacingLg),
            Text(
              _totalImages > 0
                  ? 'ai_import.loading_progress'.tr(
                      args: [
                        _processingIndex.toString(),
                        _totalImages.toString(),
                      ],
                    )
                  : 'ai_import.loading'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (_photoGroups.isNotEmpty) ...[
              SizedBox(height: context.spacingMd),
              Text(
                'ai_import.items_found_so_far'.tr(
                  args: [_allResults.length.toString()],
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Results state ────────────────────────────────────────────────────────────

  Widget _buildResults(BuildContext context) {
    final allResults = _allResults;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Results header ────────────────────────────────────────────────────
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
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: context.spacingXs),
                  Text(
                    'ai_import.items_identified'.tr(
                      args: [allResults.length.toString()],
                    ),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.spacingXs),
              Text(
                'ai_import.edit_hint'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // ── Grouped by photo ──────────────────────────────────────────────────
        for (var gi = 0; gi < _photoGroups.length; gi++) ...[
          _PhotoGroupHeader(
            photo: _photoGroups[gi].photo,
            photoIndex: gi + 1,
            totalPhotos: _photoGroups.length,
          ),
          SizedBox(height: context.spacingSm),
          for (var ii = 0; ii < _photoGroups[gi].results.length; ii++)
            Padding(
              padding: EdgeInsets.only(bottom: context.spacingMd),
              child: _EditableResultCard(
                item: _photoGroups[gi].results[ii],
                index: ii + 1,
                controller: _photoGroups[gi].controllers[ii],
                onNameChanged: (value) {
                  setState(() {
                    _photoGroups[gi].results[ii] = _photoGroups[gi].results[ii]
                        .copyWith(name: value);
                  });
                },
                onDelete: () => _deleteItem(gi, ii),
              ),
            ),
          if (gi < _photoGroups.length - 1)
            Padding(
              padding: EdgeInsets.symmetric(vertical: context.spacingSm),
              child: Divider(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
        ],

        // ── Error banner ─────────────────────────────────────────────────────
        if (_errorMessage != null) ...[
          SizedBox(height: context.spacingMd),
          _ErrorBanner(message: _errorMessage!),
        ],

        // ── Debug: Raw JSON dump ──────────────────────────────────────────────
        if (_rawJsonDump != null) ...[
          SizedBox(height: context.spacingMd),
          _RawJsonDebugPanel(rawJson: _rawJsonDump!),
        ],
      ],
    );
  }

  // ── Bottom bar (house selector + save) ───────────────────────────────────────

  Widget _buildBottomBar(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          context.spacingMd,
          context.spacingSm + context.spacingXs,
          context.spacingMd,
          context.spacingSm,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!widget.isFirstTimeOnboarding) ...[
              Expanded(child: _buildHouseDropdown(context)),
              SizedBox(width: context.spacingMd),
            ],
            ElevatedButton(
              onPressed: _isLoading ? null : _saveItems,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: EdgeInsets.symmetric(
                  horizontal: context.spacingMd,
                  vertical: context.spacingSm,
                ),
              ),
              child: Text(
                'ai_import.save_button'.tr(
                  args: [_allResults.length.toString()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHouseDropdown(BuildContext context) {
    final housesAsync = ref.watch(houseNotifierProvider);
    return housesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => Text('errors.load_failed'.tr()),
      data: (houses) => DropdownButtonFormField<String>(
        initialValue: _selectedHouseId,
        isDense: true,
        decoration: InputDecoration(
          labelText: 'ai_import.destination_house'.tr(),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.inputBorderRadius,
            ),
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
        onChanged: _isLoading
            ? null
            : (v) {
                if (v != null) setState(() => _selectedHouseId = v);
              },
      ),
    );
  }
}

// ── Photo group header ────────────────────────────────────────────────────────

class _PhotoGroupHeader extends StatelessWidget {
  final File photo;
  final int photoIndex;
  final int totalPhotos;

  const _PhotoGroupHeader({
    required this.photo,
    required this.photoIndex,
    required this.totalPhotos,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
          child: Image.file(
            photo,
            width: context.responsive(56),
            height: context.responsive(56),
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(width: context.spacingMd),
        Text(
          totalPhotos > 1
              ? 'ai_import.photo_of'.tr(
                  args: [photoIndex.toString(), totalPhotos.toString()],
                )
              : 'ai_import.photo'.tr(),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ── Editable Result Card ──────────────────────────────────────────────────────

class _EditableResultCard extends StatelessWidget {
  final ClothingAnalysisResult item;
  final int index;
  final TextEditingController controller;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onDelete;

  const _EditableResultCard({
    required this.item,
    required this.index,
    required this.controller,
    required this.onNameChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: number + editable name + delete ───────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: context.responsive(22),
                  height: context.responsive(22),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$index',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: context.spacingSm),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onNameChanged,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: context.spacingSm,
                        vertical: context.spacingXs,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.inputBorderRadius,
                        ),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.inputBorderRadius,
                        ),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  color: Theme.of(context).colorScheme.error,
                  tooltip: 'common.delete'.tr(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            SizedBox(height: context.spacingMd),
            const Divider(height: 1),
            SizedBox(height: context.spacingMd),

            // ── AI metadata fields ────────────────────────────────────────
            _ResultRow(
              icon: Icons.category_outlined,
              label: 'ai_import.field_category'.tr(),
              value: item.category,
            ),
            _ResultRow(
              icon: Icons.palette_outlined,
              label: 'ai_import.field_color'.tr(),
              value: item.baseColor,
            ),
            _ResultRow(
              icon: Icons.layers_outlined,
              label: 'ai_import.field_coverage'.tr(),
              value: item.coverage,
            ),
            _ResultRow(
              icon: Icons.grid_view_outlined,
              label: 'ai_import.field_pattern'.tr(),
              value: item.pattern,
            ),
            _ResultRow(
              icon: Icons.straighten_outlined,
              label: 'ai_import.field_fit'.tr(),
              value: item.fit,
            ),
            _ResultRow(
              icon: Icons.business_center_outlined,
              label: 'ai_import.field_formality'.tr(),
              value: item.formality,
            ),
            SizedBox(height: context.spacingXs),

            // ── Score bars ────────────────────────────────────────────────
            _ScoreRow(
              icon: Icons.thermostat_outlined,
              label: 'ai_import.field_warmth'.tr(),
              value: item.warmth,
              max: 5,
            ),
            _ScoreRow(
              icon: Icons.shuffle_outlined,
              label: 'ai_import.field_versatility'.tr(),
              value: item.calculatedVersatility,
              max: 5,
            ),
            if (item.activityTags.isNotEmpty) ...[
              SizedBox(height: context.spacingSm),
              _TagsRow(
                icon: Icons.local_activity_outlined,
                label: 'ai_import.field_activities'.tr(),
                tags: item.activityTags,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _ScoreRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final int max;

  const _ScoreRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacingSm),
      child: Row(
        children: [
          Icon(
            icon,
            size: context.iconSizeSm,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: context.spacingSm),
          SizedBox(
            width: context.responsive(76),
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: value / max,
              minHeight: 6,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(width: context.spacingSm),
          Text(
            '$value/$max',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<String> tags;

  const _TagsRow({required this.icon, required this.label, required this.tags});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: context.iconSizeSm,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: context.spacingSm),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: context.spacingXs),
        Wrap(
          spacing: context.spacingXs,
          runSpacing: context.spacingXs,
          children: tags
              .map(
                (tag) => Chip(
                  label: Text(tag),
                  labelStyle: Theme.of(context).textTheme.labelSmall,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacingSm),
      child: Row(
        children: [
          Icon(
            icon,
            size: context.iconSizeSm,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: context.spacingSm),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _RawJsonDebugPanel extends StatelessWidget {
  final String rawJson;

  const _RawJsonDebugPanel({required this.rawJson});

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1A1A2E)
        : const Color(0xFF1E1E2E);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: Text('🛠️', style: TextStyle(fontSize: AppSpacing.fontSm)),
        title: Text(
          'ai_import.debug_raw_json'.tr(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(
                AppConstants.cardBorderRadius,
              ),
            ),
            padding: EdgeInsets.all(context.spacingSm),
            child: SelectableText(
              rawJson,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: context.fontSizeXxs,
                color: const Color(0xFFCDD6F4),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppConstants.inputBorderRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: context.iconSizeSm,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          SizedBox(width: context.spacingSm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
