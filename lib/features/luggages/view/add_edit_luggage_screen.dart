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
    builder: (context) =>
        AddEditLuggageSheet(houseId: houseId, luggageId: luggageId),
  );
}

/// Bottom sheet per creare o modificare un bagaglio
class AddEditLuggageSheet extends StatefulWidget {
  final String houseId;
  final String? luggageId;

  const AddEditLuggageSheet({super.key, required this.houseId, this.luggageId});

  @override
  State<AddEditLuggageSheet> createState() => _AddEditLuggageSheetState();
}

class _AddEditLuggageSheetState extends State<AddEditLuggageSheet> {
  final GlobalKey<LuggageFormContentState> _formKey = GlobalKey();
  bool _isSaving = false;

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final saved = await _formKey.currentState?.save() ?? false;
    if (mounted) {
      setState(() => _isSaving = false);
      if (saved) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StandardBottomSheetLayout(
      title: widget.luggageId != null
          ? 'luggages.edit'.tr()
          : 'luggages.add_new'.tr(),
      onCancel: () => Navigator.pop(context),
      onSave: () => _handleSave(),
      isLoading: _isSaving,
      saveLabel: widget.luggageId != null
          ? 'common.save'.tr()
          : 'common.create'.tr(),
      child: LuggageFormContent(
        key: _formKey,
        houseId: widget.houseId,
        luggageId: widget.luggageId,
        showButtons: false,
      ),
    );
  }
}
