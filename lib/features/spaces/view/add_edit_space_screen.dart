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
    builder: (context) => AddEditSpaceSheet(
      houseId: houseId,
      spaceId: spaceId,
    ),
  );
}

/// Bottom sheet per creare o modificare uno spazio
class AddEditSpaceSheet extends StatefulWidget {
  final String houseId;
  final String? spaceId;

  const AddEditSpaceSheet({
    super.key,
    required this.houseId,
    this.spaceId,
  });

  @override
  State<AddEditSpaceSheet> createState() => _AddEditSpaceSheetState();
}

class _AddEditSpaceSheetState extends State<AddEditSpaceSheet> {
  final GlobalKey<SpaceFormContentState> _formKey = GlobalKey();
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
      title: widget.spaceId != null
          ? 'spaces.edit'.tr()
          : 'spaces.add_new'.tr(),
      onCancel: () => Navigator.pop(context),
      onSave: _handleSave,
      isLoading: _isLoading,
      saveLabel: widget.spaceId != null ? 'common.save'.tr() : 'common.create'.tr(),
      child: SpaceFormContent(
        key: _formKey,
        houseId: widget.houseId,
        spaceId: widget.spaceId,
        onSaved: () => Navigator.pop(context),
        showButtons: false,
        onLoadingChanged: _handleLoadingChanged,
      ),
    );
  }
}

