import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/standard_bottom_sheet_layout.dart';
import 'house_form_content.dart';

/// Mostra il bottom sheet per creare o modificare una casa
Future<void> showAddEditHouseSheet(BuildContext context, {String? houseId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AddEditHouseSheet(houseId: houseId),
  );
}

/// Bottom sheet per creare o modificare una casa
class AddEditHouseSheet extends StatefulWidget {
  final String? houseId;

  const AddEditHouseSheet({super.key, this.houseId});

  @override
  State<AddEditHouseSheet> createState() => _AddEditHouseSheetState();
}

class _AddEditHouseSheetState extends State<AddEditHouseSheet> {
  final GlobalKey<HouseFormContentState> _formKey = GlobalKey();
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
      title: widget.houseId != null
          ? 'houses.edit'.tr()
          : 'houses.add_new'.tr(),
      onCancel: () => Navigator.pop(context),
      onSave: _handleSave,
      isLoading: _isLoading,
      saveLabel: widget.houseId != null ? 'common.save'.tr() : 'common.create'.tr(),
      child: HouseFormContent(
        key: _formKey,
        houseId: widget.houseId,
        onSaved: () => Navigator.pop(context),
        showButtons: false,
        onLoadingChanged: _handleLoadingChanged,
      ),
    );
  }
}

/// Versione full-screen (mantenuta per retrocompatibilità con le route)
class AddEditHouseScreen extends StatelessWidget {
  final String? houseId;

  const AddEditHouseScreen({super.key, this.houseId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(houseId != null ? 'houses.edit'.tr() : 'houses.add_new'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HouseFormContent(
            houseId: houseId,
            onSaved: () => context.go('/'),
          ),
        ],
      ),
    );
  }
}
