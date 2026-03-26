import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/standard_bottom_sheet_layout.dart';
import 'luggage_form_content.dart';

/// Mostra il bottom sheet per creare o modificare un bagaglio
Future<void> showAddEditLuggageSheet(
  BuildContext context, {
  required String houseId,
  String? luggageId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AddEditLuggageSheet(
      houseId: houseId,
      luggageId: luggageId,
    ),
  );
}

/// Bottom sheet per creare o modificare un bagaglio
class AddEditLuggageSheet extends StatefulWidget {
  final String houseId;
  final String? luggageId;

  const AddEditLuggageSheet({
    super.key,
    required this.houseId,
    this.luggageId,
  });

  @override
  State<AddEditLuggageSheet> createState() => _AddEditLuggageSheetState();
}

class _AddEditLuggageSheetState extends State<AddEditLuggageSheet> {
  final GlobalKey<LuggageFormContentState> _formKey = GlobalKey();
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
      title: widget.luggageId != null
          ? 'luggages.edit'.tr()
          : 'luggages.add_new'.tr(),
      onCancel: () => Navigator.pop(context),
      onSave: _handleSave,
      isLoading: _isLoading,
      saveLabel: widget.luggageId != null ? 'common.save'.tr() : 'common.create'.tr(),
      child: LuggageFormContent(
        key: _formKey,
        houseId: widget.houseId,
        luggageId: widget.luggageId,
        onSaved: () => Navigator.pop(context),
        showButtons: false,
        onLoadingChanged: _handleLoadingChanged,
      ),
    );
  }
}
