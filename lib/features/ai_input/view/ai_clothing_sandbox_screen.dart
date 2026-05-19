import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/config/app_config.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../houses/providers/house_provider.dart';
import '../../items/model/item_model.dart';
import '../../items/providers/item_provider.dart';
import '../../items/repositories/item_repository.dart';
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
  final String houseId;

  const AiClothingSandboxScreen({super.key, required this.houseId});

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
  late String _selectedHouseId = widget.houseId;
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

  late final AiClothingAnalyzerService _service = AiClothingAnalyzerService(
    proxyUrl: '${AppConfig.supabaseUrl}/functions/v1/openai-proxy',
    anonKey: AppConfig.supabaseAnonKey,
  );

  // ── Lifecycle ────────────────────────────────────────────────────────────────

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
              title: const Text('Galleria'),
              subtitle: Text(
                'Max $_remainingSlots ${_remainingSlots == 1 ? 'foto' : 'foto'} selezionabili',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Fotocamera'),
              subtitle: const Text('Scatta una foto'),
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
      final msg = 'Unexpected error: $e';
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
    final allResults = _allResults;
    if (allResults.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final items = allResults.map((item) {
        return ItemModel(
          id: _uuid.v4(),
          houseId: _selectedHouseId,
          name: item.name,
          category: _mapCategory(item.category),
          quantity: 1,
          createdAt: now,
          updatedAt: now,
        );
      }).toList();

      final repo = ref.read(itemRepositoryProvider);
      await repo.insertMultipleItems(items);
      ref.invalidate(itemNotifierProvider(_selectedHouseId));

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
          content: Text(
            '$saved ${saved == 1 ? 'oggetto salvato' : 'oggetti salvati'} con successo!',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Errore durante il salvataggio: $e');
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

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canAddMore = !_isLoading && _remainingSlots > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Bulk Import ✨')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: canAddMore ? _showPickerSheet : null,
        icon: const Icon(Icons.add_photo_alternate),
        label: _totalPhotosSelected == 0
            ? const Text('Scegli immagini')
            : Text('Aggiungi foto ($_totalPhotosSelected/5)'),
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
            100,
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
            size: 72,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Scegli fino a 5 foto di outfit',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'GPT-4o analizzerà ogni immagine e identificherà i capi d\'abbigliamento',
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
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 240,
            child: LinearProgressIndicator(value: progress, minHeight: 6),
          ),
          const SizedBox(height: 20),
          Text(
            _totalImages > 0
                ? 'Analisi immagine $_processingIndex di $_totalImages…'
                : 'Caricamento…',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (_photoGroups.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${_allResults.length} capi trovati finora',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
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
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.checkroom_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${allResults.length} ${allResults.length == 1 ? 'capo' : 'capi'} identificati',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Modifica nomi o elimina prima di salvare',
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
          const SizedBox(height: 8),
          for (var ii = 0; ii < _photoGroups[gi].results.length; ii++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
        ],

        // ── Error banner ─────────────────────────────────────────────────────
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: _errorMessage!),
        ],

        // ── Debug: Raw JSON dump ──────────────────────────────────────────────
        if (_rawJsonDump != null) ...[
          const SizedBox(height: 16),
          _RawJsonDebugPanel(rawJson: _rawJsonDump!),
        ],
      ],
    );
  }

  // ── Bottom bar (house selector + save) ───────────────────────────────────────

  Widget _buildBottomBar(BuildContext context) {
    final housesAsync = ref.watch(houseNotifierProvider);
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
            Expanded(
              child: housesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Errore caricamento case'),
                data: (houses) => DropdownButtonFormField<String>(
                  initialValue: _selectedHouseId,
                  isDense: true,
                  decoration: InputDecoration(
                    labelText: 'Casa di destinazione',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
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
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveItems,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
              child: Text('Salva ${_allResults.length}'),
            ),
          ],
        ),
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
          borderRadius: BorderRadius.circular(8),
          child: Image.file(photo, width: 56, height: 56, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        Text(
          totalPhotos > 1 ? 'Foto $photoIndex di $totalPhotos' : 'Foto',
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
        borderRadius: BorderRadius.circular(12),
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
                  width: 22,
                  height: 22,
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
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onNameChanged,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
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
                  tooltip: 'Elimina',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── AI metadata fields ────────────────────────────────────────
            _ResultRow(
              icon: Icons.category_outlined,
              label: 'Category',
              value: item.category,
            ),
            _ResultRow(
              icon: Icons.palette_outlined,
              label: 'Color',
              value: item.baseColor,
            ),
            _ResultRow(
              icon: Icons.layers_outlined,
              label: 'Coverage',
              value: item.coverage,
            ),
            _ResultRow(
              icon: Icons.grid_view_outlined,
              label: 'Pattern',
              value: item.pattern,
            ),
            _ResultRow(
              icon: Icons.straighten_outlined,
              label: 'Fit',
              value: item.fit,
            ),
            _ResultRow(
              icon: Icons.business_center_outlined,
              label: 'Formality',
              value: item.formality,
            ),
            const SizedBox(height: 4),

            // ── Score bars ────────────────────────────────────────────────
            _ScoreRow(
              icon: Icons.thermostat_outlined,
              label: 'Warmth',
              value: item.warmth,
              max: 5,
            ),
            _ScoreRow(
              icon: Icons.shuffle_outlined,
              label: 'Versatility',
              value: item.calculatedVersatility,
              max: 5,
            ),
            if (item.activityTags.isNotEmpty) ...[
              const SizedBox(height: 8),
              _TagsRow(
                icon: Icons.local_activity_outlined,
                label: 'Activities',
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 76,
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
          const SizedBox(width: 8),
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
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
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
        leading: const Text(
          '🛠️',
          style: TextStyle(fontSize: AppSpacing.fontSm),
        ),
        title: Text(
          'Debug: Raw JSON',
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: 18,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: context.fontSizeXxs,
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
