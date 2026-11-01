import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/app_spacing.dart';
import '../model/item_model.dart';
import '../providers/item_provider.dart';
import '../providers/item_selection_provider.dart';

/// Elimina un oggetto della lista della casa con lo swipe verso sinistra.
///
/// Niente conferma: l'oggetto sparisce e uno snackbar dice cosa è successo con
/// "Annulla", che lo rimette. Non si attiva in selezione multipla (lì il tocco
/// seleziona) né per un oggetto in viaggio, come il tocco prolungato.
class SwipeToDeleteItem extends ConsumerStatefulWidget {
  const SwipeToDeleteItem({
    super.key,
    required this.item,
    required this.houseId,
    required this.enabled,
    required this.child,
  });

  final ItemModel item;
  final String houseId;

  /// `false` per un oggetto che non si può eliminare con lo swipe.
  final bool enabled;
  final Widget child;

  @override
  ConsumerState<SwipeToDeleteItem> createState() => _SwipeToDeleteItemState();
}

class _SwipeToDeleteItemState extends ConsumerState<SwipeToDeleteItem> {
  /// Dopo lo swipe la riga è già via: Dismissible non può restare nell'albero
  /// mentre l'eliminazione scrive sul database.
  bool _dismissed = false;

  Future<void> _delete() async {
    final item = widget.item;
    final notifier = ref.read(itemNotifierProvider(widget.houseId).notifier);
    setState(() => _dismissed = true);
    AppSnackBar.showUndo(
      context,
      'items.item_deleted'.tr(args: [item.name]),
      onUndo: () => notifier.restoreItem(item.id, widget.houseId),
    );
    try {
      await notifier.deleteItem(item.id, widget.houseId);
    } catch (_) {
      // L'eliminazione non è riuscita: la riga torna e l'errore sostituisce
      // l'"Annulla", che ora non avrebbe niente da annullare.
      if (!mounted) return;
      setState(() => _dismissed = false);
      AppSnackBar.showError(
        context,
        'errors.delete_item_failed'.tr(args: [item.name]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selecting = ref.watch(
      itemSelectionNotifierProvider.select((s) => s.isActive),
    );
    if (!widget.enabled || selecting) return widget.child;
    if (_dismissed) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('swipe_delete_${widget.item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _delete(),
      background: ColoredBox(
        color: cs.error,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: context.spacingMd),
            child: Icon(
              Icons.delete_outline,
              size: context.iconSizeMd,
              color: cs.onError,
            ),
          ),
        ),
      ),
      child: widget.child,
    );
  }
}
