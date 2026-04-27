import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import '../../items/model/item_model.dart';
import '../../items/repositories/item_repository.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import '../services/smart_packing_agent.dart';

// ── Navigation payload ────────────────────────────────────────────────────────

/// Data carrier passed from [SmartPackingLoadingScreen] to
/// [SmartPackingResultsScreen] via GoRouter `extra`.
///
/// [pendingTrip] is non-null when coming from the trip creation form
/// (trip not yet saved in DB). The results screen will call [addTrip]
/// instead of [updateTrip] in that case.
class SmartPackingResultsPayload {
  final List<SmartPackingRecommendation> recommendations;
  final TripModel? pendingTrip;

  const SmartPackingResultsPayload({
    required this.recommendations,
    this.pendingTrip,
  });
}

// ── State for a single recommendation row ─────────────────────────────────────

/// Holds an AI recommendation paired with the resolved item and its selection.
class _RecommendationEntry {
  final SmartPackingRecommendation recommendation;
  final ItemModel item;
  bool isSelected;

  _RecommendationEntry({
    required this.recommendation,
    required this.item,
    this.isSelected = true,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// Displays the AI-generated packing list and lets the user approve or
/// remove individual items before saving them to the trip.
///
/// Two modes:
/// - **Creation** (`pendingTrip != null`): trip not in DB yet; saving calls
///   [addTrip] and navigates to the new trip's detail screen.
/// - **Edit** (`pendingTrip == null`): trip already in DB; saving calls
///   [updateTrip] and returns to the existing trip's detail screen.
class SmartPackingResultsScreen extends ConsumerStatefulWidget {
  final String tripId;
  final List<SmartPackingRecommendation> recommendations;

  /// Non-null when the trip has not yet been saved to the DB.
  final TripModel? pendingTrip;

  const SmartPackingResultsScreen({
    super.key,
    required this.tripId,
    required this.recommendations,
    this.pendingTrip,
  });

  @override
  ConsumerState<SmartPackingResultsScreen> createState() =>
      _SmartPackingResultsScreenState();
}

class _SmartPackingResultsScreenState
    extends ConsumerState<SmartPackingResultsScreen> {
  List<_RecommendationEntry> _entries = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveItems());
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  /// Resolves full [ItemModel] details for each recommendation id.
  ///
  /// Items that no longer exist in the DB (deleted after the AI call) are
  /// silently skipped rather than crashing the screen.
  Future<void> _resolveItems() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final repo = ref.read(itemRepositoryProvider);
      final entries = <_RecommendationEntry>[];

      for (final rec in widget.recommendations) {
        if (rec.itemId.isEmpty) continue;
        try {
          final item = await repo.getItemById(rec.itemId);
          entries.add(_RecommendationEntry(recommendation: rec, item: item));
        } catch (_) {
          // Item deleted or not found; skip gracefully.
        }
      }

      if (mounted) setState(() => _entries = entries);
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Save logic ────────────────────────────────────────────────────────────

  List<TripItem> _buildTripItems(List<_RecommendationEntry> selected) {
    return selected.map((e) {
      final item = e.item;
      return TripItem(
        id: item.id,
        name: item.name,
        category: item.category,
        quantity: item.quantity ?? 1,
        originHouseId: item.houseId,
        isChecked: false,
      );
    }).toList();
  }

  Future<void> _saveToTrip() async {
    final selected = _entries.where((e) => e.isSelected).toList();
    if (selected.isEmpty) {
      AppSnackBar.showWarning(
        context,
        'Seleziona almeno un elemento prima di salvare.',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final newItems = _buildTripItems(selected);

      if (widget.pendingTrip != null) {
        // ── Creation mode: trip not yet in DB ─────────────────────────────
        final trip = widget.pendingTrip!.copyWith(
          items: newItems,
          updatedAt: DateTime.now(),
        );
        await ref.read(tripNotifierProvider.notifier).addTrip(trip);

        if (mounted) {
          AppSnackBar.showSuccess(
            context,
            'Viaggio creato con ${selected.length} oggett${selected.length == 1 ? 'o' : 'i'}.',
          );
          context.go('/trips/${trip.id}');
        }
      } else {
        // ── Edit mode: merge items into existing trip ──────────────────────
        final tripsAsync = ref.read(tripNotifierProvider);
        final trip = tripsAsync.value?.firstWhere(
          (t) => t.id == widget.tripId,
          orElse: () => throw StateError('Viaggio non trovato'),
        );
        if (trip == null) throw StateError('Viaggio non trovato');

        final existingIds = trip.items.map((i) => i.id).toSet();
        final merged = [
          ...trip.items,
          ...newItems.where((i) => !existingIds.contains(i.id)),
        ];

        await ref.read(tripNotifierProvider.notifier).updateTrip(
              trip.copyWith(items: merged, updatedAt: DateTime.now()),
            );

        if (mounted) {
          AppSnackBar.showSuccess(
            context,
            '${selected.length} oggett${selected.length == 1 ? 'o aggiunto' : 'i aggiunti'} al viaggio.',
          );
          context.go('/trips/${widget.tripId}');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Errore durante il salvataggio: $e');
        setState(() => _isSaving = false);
      }
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final selectedCount = _entries.where((e) => e.isSelected).length;

    return StickyCtaScaffold(
      appBar: AppBar(
        title: const Text('Lista Suggerita'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!_isLoading && _entries.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                final allSelected = _entries.every((e) => e.isSelected);
                for (final e in _entries) {
                  e.isSelected = !allSelected;
                }
              }),
              child: Text(
                _entries.every((e) => e.isSelected)
                    ? 'Deseleziona tutto'
                    : 'Seleziona tutto',
              ),
            ),
        ],
      ),
      body: _buildBody(context),
      bottomContent: UniversalActionBar(
        primaryLabel: _isSaving
            ? 'Salvataggio...'
            : widget.pendingTrip != null
                ? 'Crea Viaggio con $selectedCount Element${selectedCount == 1 ? 'o' : 'i'}'
                : 'Aggiungi $selectedCount Element${selectedCount == 1 ? 'o' : 'i'} al Viaggio',
        primaryIcon: widget.pendingTrip != null
            ? Icons.luggage
            : Icons.add_shopping_cart,
        onPrimaryPressed: (_isLoading || _isSaving || selectedCount == 0)
            ? null
            : _saveToTrip,
        isLoading: _isSaving,
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return _buildError(context);
    }

    if (_entries.isEmpty) {
      return _buildEmpty(context);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      itemCount: _entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return _RecommendationCard(
          entry: entry,
          onToggle: (value) => setState(() => entry.isSelected = value),
        );
      },
    );
  }

  Widget _buildError(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Impossibile caricare i dettagli degli oggetti.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
              onPressed: _resolveItems,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Nessun oggetto suggerito.\nProva ad aggiungere più oggetti al tuo guardaroba.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: Text(
                widget.pendingTrip != null
                    ? 'Torna alla creazione'
                    : 'Torna al viaggio',
              ),
              onPressed: () => widget.pendingTrip != null
                  ? context.pop()
                  : context.go('/trips/${widget.tripId}'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card widget ───────────────────────────────────────────────────────────────

class _RecommendationCard extends StatelessWidget {
  final _RecommendationEntry entry;
  final ValueChanged<bool> onToggle;

  const _RecommendationCard({
    required this.entry,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final item = entry.item;
    final isSelected = entry.isSelected;

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected ? colorScheme.surface : colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.outlineVariant,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onToggle(!isSelected),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Category icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.category.icon,
                  size: 22,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(width: AppSpacing.md),

              // Name + motivation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? colorScheme.onSurface
                                : colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.recommendation.motivation,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: colorScheme.onSurfaceVariant,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              // Checkbox
              Checkbox(
                value: isSelected,
                onChanged: (v) => onToggle(v ?? isSelected),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
