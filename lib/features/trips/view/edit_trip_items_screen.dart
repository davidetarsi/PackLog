import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../model/trip_model.dart';
import '../providers/trip_provider.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../items/repositories/item_repository.dart';
import '../../../shared/widgets/sticky_cta_scaffold.dart';
import '../../../shared/widgets/universal_action_bar.dart';
import 'trip_items_selector.dart';
import 'widgets/trip_edit_placeholder.dart';

/// Schermata per modificare solo gli oggetti del viaggio.
class EditTripItemsScreen extends ConsumerStatefulWidget {
  final String tripId;

  const EditTripItemsScreen({super.key, required this.tripId});

  @override
  ConsumerState<EditTripItemsScreen> createState() =>
      _EditTripItemsScreenState();
}

class _EditTripItemsScreenState extends ConsumerState<EditTripItemsScreen> {
  bool _isLoading = false;
  TripModel? _trip;
  List<TripItem> _selectedItems = [];

  /// Copia il viaggio nello stato modificabile, una volta sola.
  ///
  /// Vedi [tripEditPlaceholder]: la lettura in `initState` lasciava la
  /// schermata sullo spinner per sempre se il provider era ancora in
  /// caricamento. Idratando nel build, il primo `AsyncData` la riempie.
  ///
  /// Nessun `setState`: siamo dentro il build provocato da `ref.watch`.
  void _hydrate(TripModel trip) {
    if (_trip != null) return;
    _trip = trip;
    _selectedItems = List.from(trip.items);
  }

  /// Normalizza i [TripItem] con [originHouseId] vuoto recuperando la casa
  /// reale dell'[ItemModel] corrispondente. Questo sistema in modo idempotente
  /// i dati creati prima che il campo venisse introdotto.
  Future<List<TripItem>> _normalizeItemOrigins(List<TripItem> items) async {
    final itemRepo = ref.read(itemRepositoryProvider);
    return Future.wait(
      items.map((tripItem) async {
        if (tripItem.originHouseId.isNotEmpty) return tripItem;
        try {
          final itemModel = await itemRepo.getItemById(tripItem.id);
          return tripItem.copyWith(originHouseId: itemModel.houseId);
        } catch (_) {
          return tripItem;
        }
      }),
    );
  }

  Future<void> _saveChanges() async {
    if (_trip == null) return;

    setState(() => _isLoading = true);

    // Normalizza item legacy con originHouseId vuoto prima del salvataggio.
    final normalizedItems = await _normalizeItemOrigins(_selectedItems);

    if (!mounted) return;

    final updatedTrip = _trip!.copyWith(
      items: normalizedItems,
      updatedAt: DateTime.now(),
    );

    final success = await ErrorRetryDialog.executeWithRetry(
      context: context,
      operation: () =>
          ref.read(tripNotifierProvider.notifier).updateTrip(updatedTrip),
      errorTitle: 'errors.save_error'.tr(),
      errorMessage: 'errors.save_trip_items_failed'.tr(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final tripsAsync = ref.watch(tripNotifierProvider);
    final trip = tripsAsync.valueOrNull
        ?.where((t) => t.id == widget.tripId)
        .firstOrNull;
    if (trip != null) _hydrate(trip);

    final placeholder = tripEditPlaceholder(
      context: context,
      ref: ref,
      title: 'trips.edit_items'.tr(),
      tripsAsync: tripsAsync,
      isHydrated: _trip != null,
    );
    if (placeholder != null) return placeholder;

    return StickyCtaScaffold(
      appBar: AppBar(
        title: Text('trips.edit_items'.tr()),
        actions: [
          Center(
            child: Container(
              margin: EdgeInsets.only(right: context.spacingMd),
              padding: EdgeInsets.symmetric(
                horizontal: context.spacingSm,
                vertical: context.spacingXs,
              ),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: context.responsiveBorderRadius(12),
              ),
              child: Text(
                'common.items_count'.tr(
                  args: [_selectedItems.length.toString()],
                ),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(context.spacingMd),
        child: TripItemsSelector(
          selectedItems: _selectedItems,
          onSelectionChanged: (items) {
            setState(() {
              _selectedItems = items;
            });
          },
          shrinkWrap: false,
        ),
      ),
      bottomContent: UniversalActionBar(
        primaryLabel: 'trips.save_items'.tr(),
        primaryIcon: Icons.save,
        onPrimaryPressed: _isLoading ? null : _saveChanges,
        isLoading: _isLoading,
      ),
    );
  }
}
