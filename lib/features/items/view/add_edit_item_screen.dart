import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/item_provider.dart';
import '../../../shared/widgets/standard_bottom_sheet_layout.dart';
import '../../../shared/widgets/error_retry_dialog.dart';
import '../../../shared/helpers/dialog_helpers.dart';
import 'item_form_content.dart';

/// Mostra il bottom sheet per creare o modificare un item
Future<void> showAddEditItemSheet(
  BuildContext context, {
  String? houseId,
  String? itemId,
  void Function(String itemId, String houseId)? onItemSaved,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AddEditItemSheet(
      houseId: houseId,
      itemId: itemId,
      onItemSaved: onItemSaved,
    ),
  );
}

/// Bottom sheet per creare o modificare un item
class AddEditItemSheet extends ConsumerStatefulWidget {
  final String? houseId;
  final String? itemId;
  final void Function(String itemId, String houseId)? onItemSaved;

  const AddEditItemSheet({
    super.key,
    this.houseId,
    this.itemId,
    this.onItemSaved,
  });

  @override
  ConsumerState<AddEditItemSheet> createState() => _AddEditItemSheetState();
}

class _AddEditItemSheetState extends ConsumerState<AddEditItemSheet> {
  final GlobalKey<ItemFormContentState> _formKey = GlobalKey();
  bool _isLoading = false;

  void _handleSave() {
    _formKey.currentState?.save();
  }

  void _handleLoadingChanged(bool loading) {
    setState(() => _isLoading = loading);
  }

  /// Gestisce l'eliminazione dell'item (stessa logica del kebab menu)
  Future<void> _handleDelete() async {
    if (widget.itemId == null || widget.houseId == null) return;

    // Ottieni il nome dell'item dal form (TextField)
    final itemName = _formKey.currentState?.itemName ?? 'items.this_item'.tr();

    // Conferma eliminazione
    final confirmed = await DialogHelpers.showDeleteConfirmation(
      context: context,
      itemType: 'common.item_type'.tr(),
      itemName: itemName,
    );

    if (confirmed == true && mounted) {
      // Chiudi il bottom sheet prima di eliminare
      Navigator.pop(context);
      
      // Esegui eliminazione con retry
      await ErrorRetryDialog.executeWithRetry(
        context: context,
        operation: () => ref.read(itemNotifierProvider(widget.houseId!).notifier).deleteItem(widget.itemId!, widget.houseId!),
        errorTitle: 'common.error'.tr(),
        errorMessage: 'errors.delete_item_failed'.tr(args: [itemName]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StandardBottomSheetLayout(
      title: widget.itemId != null
          ? 'items.edit'.tr()
          : 'items.add_new'.tr(),
      onCancel: () => Navigator.pop(context),
      onSave: _handleSave,
      showDeleteButton: widget.itemId != null, // Solo in edit mode
      onDelete: widget.itemId != null ? _handleDelete : null,
      isLoading: _isLoading,
      saveLabel: widget.itemId != null ? 'common.save'.tr() : 'common.create'.tr(),
      child: ItemFormContent(
        key: _formKey,
        houseId: widget.houseId,
        itemId: widget.itemId,
        onSaved: (itemId, houseId) {
          widget.onItemSaved?.call(itemId, houseId);
          Navigator.pop(context);
        },        
        showButtons: false,
        onLoadingChanged: _handleLoadingChanged,
      ),
    );
  }
}

