import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/standard_bottom_sheet_layout.dart';
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
class AddEditItemSheet extends StatefulWidget {
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
  State<AddEditItemSheet> createState() => _AddEditItemSheetState();
}

class _AddEditItemSheetState extends State<AddEditItemSheet> {
  final GlobalKey<ItemFormContentState> _formKey = GlobalKey();
  bool _isLoading = false;

  void _handleSave() {
    _formKey.currentState?.save();
  }

  void _handleLoadingChanged(bool loading) {
    setState(() => _isLoading = loading);
  }

  @override
  Widget build(BuildContext context) {
    return StandardBottomSheetLayout(
      title: widget.itemId != null
          ? 'items.edit'.tr()
          : 'items.add_new'.tr(),
      onCancel: () => Navigator.pop(context),
      onSave: _handleSave,
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

