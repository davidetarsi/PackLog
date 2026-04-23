import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/config/app_config.dart';
import '../models/clothing_analysis_result.dart';
import '../services/ai_clothing_analyzer_service.dart';

/// Throwaway sandbox screen that exercises the full `AiClothingAnalyzerService`
/// pipeline end-to-end from the gallery.
///
/// Not wired to any Riverpod provider — pure local state intentionally.
class AiClothingSandboxScreen extends StatefulWidget {
  const AiClothingSandboxScreen({super.key});

  @override
  State<AiClothingSandboxScreen> createState() =>
      _AiClothingSandboxScreenState();
}

class _AiClothingSandboxScreenState extends State<AiClothingSandboxScreen> {
  // ── Local state ─────────────────────────────────────────────────────────────

  File? _originalImage;
  Uint8List? _processedImageBytes;
  List<ClothingItem>? _results;
  String? _rawJsonDump;
  bool _isLoading = false;
  String? _errorMessage;

  // ── Service ──────────────────────────────────────────────────────────────────

  final AiClothingAnalyzerService _service = AiClothingAnalyzerService(
    // removeBgApiKey: AppConfig.removeBg, // ← REMOVE.BG DISABILITATO
    openAiApiKey: AppConfig.openAi,
  );

  // ── Logic ────────────────────────────────────────────────────────────────────

  Future<void> _pickAndTestImage() async {
    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;
    if (!mounted) return;

    setState(() {
      _originalImage = File(picked.path);
      _processedImageBytes = null;
      _results = null;
      _rawJsonDump = null;
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final (
        :processedBytes,
        :result,
        :rawJson,
      ) = await _service.processWithIntermediateResult(_originalImage!);

      if (!mounted) return;
      setState(() {
        _processedImageBytes = processedBytes;
        _results = result;
        _rawJsonDump = rawJson;
      });
    } on ClothingAnalysisException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      final msg = 'Unexpected error: $e';
      setState(() => _errorMessage = msg);
      _showError(msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Sandbox ✨'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _pickAndTestImage,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Test Image'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) return _buildLoading(context);
    if (_originalImage == null) return _buildEmptyState(context);
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
            'Pick an image to test the AI pipeline',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Background removal → GPT-4o Vision',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
            textAlign: TextAlign.center,
          ),
          if (AppConfig.openAi.startsWith('MISSING')) ...[
            const SizedBox(height: 24),
            _ApiKeyWarning(
              missingRemoveBg: false, // ← REMOVE.BG DISABILITATO
              missingOpenAi: AppConfig.openAi.startsWith('MISSING'),
            ),
          ],
        ],
      ),
    );
  }

  // ── Loading state ────────────────────────────────────────────────────────────

  Widget _buildLoading(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Processing with GPT-4o…',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Results state ────────────────────────────────────────────────────────────

  Widget _buildResults(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Images row ────────────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ImageCard(
                label: 'Original',
                child: Image.file(
                  _originalImage!,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ImageCard(
                label: 'GPT-4o Input',
                subtitle: 'bg removal off',
                child: _processedImageBytes != null
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          const _CheckerboardBackground(height: 200),
                          Image.memory(
                            _processedImageBytes!,
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        ],
                      )
                    : const SizedBox(
                        height: 200,
                        child: Center(child: Text('—')),
                      ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Results list ──────────────────────────────────────────────────────
        if (_results != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  Icons.checkroom_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_results!.length} ${_results!.length == 1 ? 'capo' : 'capi'} identificati',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
          ),
          ...List.generate(_results!.length, (i) => Padding(
            padding: EdgeInsets.only(bottom: i < _results!.length - 1 ? 12 : 0),
            child: _ResultCard(item: _results![i], index: i + 1),
          )),
        ],

        // ── Error banner ──────────────────────────────────────────────────────
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
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ImageCard extends StatelessWidget {
  final String label;
  final String? subtitle;
  final Widget child;

  const _ImageCard({
    required this.label,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (subtitle != null) ...[
              const SizedBox(width: 4),
              Text(
                '($subtitle)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 200),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Grey-and-white checkered pattern to reveal transparent areas in PNG images.
class _CheckerboardBackground extends StatelessWidget {
  final double height;

  const _CheckerboardBackground({required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _CheckerboardPainter()),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  static const double _tileSize = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final paintLight = Paint()..color = const Color(0xFFE0E0E0);
    final paintDark = Paint()..color = const Color(0xFFBDBDBD);

    final cols = (size.width / _tileSize).ceil();
    final rows = (size.height / _tileSize).ceil();

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final isLight = (r + c) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(c * _tileSize, r * _tileSize, _tileSize, _tileSize),
          isLight ? paintLight : paintDark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ResultCard extends StatelessWidget {
  final ClothingItem item;
  final int index;

  const _ResultCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: numero + nome capo ────────────────────────────────
            Row(
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
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── String fields ─────────────────────────────────────────────
            _ResultRow(
              icon: Icons.category_outlined,
              label: 'Category',
              value: item.category,
            ),
            _ResultRow(
              icon: Icons.palette_outlined,
              label: 'Color',
              value: '${item.baseColor} (${item.colorTone})',
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
            const SizedBox(height: 4),

            // ── Score fields ──────────────────────────────────────────────
            _ScoreRow(
              icon: Icons.business_center_outlined,
              label: 'Formality',
              value: item.formality,
              max: 10,
            ),
            _ScoreRow(
              icon: Icons.shuffle_outlined,
              label: 'Versatility',
              value: item.calculatedVersatility,
              max: 5,
            ),

            // ── Tag fields ────────────────────────────────────────────────
            if (item.weather.isNotEmpty) ...[
              const SizedBox(height: 8),
              _TagsRow(
                icon: Icons.wb_cloudy_outlined,
                label: 'Weather',
                tags: item.weather,
              ),
            ],
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
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
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

  const _TagsRow({
    required this.icon,
    required this.label,
    required this.tags,
  });

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
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.4),
                  ),
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                ),
              )
              .toList(),
        ),
      ],
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
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: const Text('🛠️', style: TextStyle(fontSize: 16)),
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
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              rawJson,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Color(0xFFCDD6F4),
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
                fontSize: 12,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiKeyWarning extends StatelessWidget {
  final bool missingRemoveBg;
  final bool missingOpenAi;

  const _ApiKeyWarning({
    required this.missingRemoveBg,
    required this.missingOpenAi,
  });

  @override
  Widget build(BuildContext context) {
    final missing = [
      if (missingRemoveBg) 'Remove.bg',
      if (missingOpenAi) 'OpenAI',
    ].join(' & ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.key_off_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$missing API key(s) not set.\nAggiungi --dart-define=REMOVE_BG_KEY / OPENAI_KEY nel launch.json.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
