import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/helpers/design_system.dart';
import '../../../../shared/helpers/snack_bar_helper.dart';
import '../../../items/providers/item_provider.dart';
import '../../../items/providers/item_selection_provider.dart';
import '../../../items/view/bulk_move_sheet.dart';
import '../../../trips/model/trip_model.dart';
import '../../../trips/providers/trip_provider.dart';
import '../../../trips/view/trip_picker_sheet.dart';

// Azioni della barra di selezione multipla della casa. Il [context] deve
// essere quello dello schermo (non della barra): dopo ogni await decide se
// mostrare snackbar e svuotare la selezione.

/// Mostra un dialog di conferma ed elimina in bulk gli item selezionati.
///
/// Usato dall'azione "Elimina" nella selection action bar.
Future<void> handleBulkDelete(
  BuildContext context,
  WidgetRef ref,
  String houseId,
) async {
  final selectionState = ref.read(itemSelectionNotifierProvider);
  final selectedIds = selectionState.selectedIds.toList();
  if (selectedIds.isEmpty) return;

  final count = selectedIds.length;

  final confirmed = await DialogHelpers.showDeleteConfirmation(
    context: context,
    itemType: '',
    itemName: '',
    customTitle: 'items.bulk_delete_confirm_title'.tr(args: [count.toString()]),
    customMessage: 'items.bulk_delete_confirm_body'.tr(),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref
        .read(itemNotifierProvider(houseId).notifier)
        .bulkDelete(selectedIds);

    if (context.mounted) {
      AppSnackBar.showSuccess(
        context,
        'items.bulk_delete_success'.tr(args: [count.toString()]),
      );
    }
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.showError(context, 'errors.delete_error'.tr());
    }
  }
}

/// Mostra un bottom sheet "Sposta in…" con la lista delle altre case.
///
/// Quando l'utente seleziona una casa di destinazione, chiama [bulkMove] sul
/// notifier e mostra una snackbar di conferma.
Future<void> handleBulkMove(
  BuildContext context,
  WidgetRef ref,
  String houseId,
) async {
  final selectionState = ref.read(itemSelectionNotifierProvider);
  final selectedIds = selectionState.selectedIds.toList();
  if (selectedIds.isEmpty) return;

  if (!context.mounted) return;

  final dest = await BulkMoveSheet.show(
    context,
    itemCount: selectedIds.length,
    sourceHouseId: houseId,
  );

  if (dest == null || !context.mounted) return;

  final destinationName = dest.houseDisplayName;
  final count = selectedIds.length;

  try {
    await ref
        .read(itemNotifierProvider(houseId).notifier)
        .bulkMove(selectedIds, dest.houseId, spaceId: dest.spaceId);

    if (context.mounted) {
      AppSnackBar.showSuccess(
        context,
        'items.bulk_move_success'.tr(args: [count.toString(), destinationName]),
      );
    }
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.showError(context, 'errors.save_error'.tr());
    }
  }
}

/// Mostra il picker "scegli un viaggio" e aggiunge gli item selezionati
/// al viaggio scelto (operazione additiva, idempotente — vedi
/// [TripRepository.addItemsToTrip]).
Future<void> handleAddToTrip(
  BuildContext context,
  WidgetRef ref,
  String houseId,
) async {
  final selectionState = ref.read(itemSelectionNotifierProvider);
  final selectedIds = selectionState.selectedIds.toList();
  if (selectedIds.isEmpty) return;

  if (!context.mounted) return;

  final trip = await TripPickerSheet.show(context);
  if (trip == null || !context.mounted) return;

  final allItems = ref.read(itemNotifierProvider(houseId)).value ?? const [];
  final selectedItems = allItems
      .where((item) => selectedIds.contains(item.id))
      .toList();

  final tripItems = selectedItems
      .map(
        (item) => TripItem(
          id: item.id,
          name: item.name,
          category: item.category,
          quantity: item.quantity ?? 1,
          originHouseId: item.houseId,
        ),
      )
      .toList();

  final count = tripItems.length;

  try {
    await ref
        .read(tripNotifierProvider.notifier)
        .addItemsToTrip(trip.id, tripItems);

    if (context.mounted) {
      AppSnackBar.showSuccess(
        context,
        'items.add_to_trip_success'.tr(args: [count.toString(), trip.name]),
      );
      ref.read(itemSelectionNotifierProvider.notifier).clear();
    }
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.showError(context, 'errors.save_error'.tr());
    }
  }
}
