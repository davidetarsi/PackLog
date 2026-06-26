import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/standard_bottom_sheet_layout.dart';
import 'space_form_content.dart';

/// Mostra il bottom sheet per creare o modificare uno spazio
Future<void> showAddEditSpaceSheet(
  BuildContext context, {
  required String houseId,
  String? spaceId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AddEditSpaceSheet(houseId: houseId, spaceId: spaceId),
  );
}

/// Bottom sheet per creare o modificare uno spazio
class AddEditSpaceSheet extends StatefulWidget {
  final String houseId;
  final String? spaceId;

  const AddEditSpaceSheet({super.key, required this.houseId, this.spaceId});

  @override
  State<AddEditSpaceSheet> createState() => _AddEditSpaceSheetState();
}

class _AddEditSpaceSheetState extends State<AddEditSpaceSheet> {
  final GlobalKey<SpaceFormContentState> _formKey = GlobalKey();
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
      title: widget.spaceId != null
          ? 'spaces.edit'.tr()
          : 'spaces.add_new'.tr(),
      onCancel: () => Navigator.pop(context),
      onSave: () => _handleSave(),
      isLoading: _isSaving,
      saveLabel: widget.spaceId != null
          ? 'common.save'.tr()
          : 'common.create'.tr(),
      child: SpaceFormContent(
        key: _formKey,
        houseId: widget.houseId,
        spaceId: widget.spaceId,
        showButtons: false,
      ),
    );
  }
}
