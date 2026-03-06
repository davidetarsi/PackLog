import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/helpers/design_system.dart';
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
class AddEditHouseSheet extends StatelessWidget {
  final String? houseId;

  const AddEditHouseSheet({super.key, this.houseId});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BottomSheetHandle(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  houseId != null ? 'houses.edit'.tr() : 'houses.add_new'.tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16 + AppConstants.bottomSheetBottomPadding,
            ),
            child: HouseFormContent(
              houseId: houseId,
              onSaved: () => Navigator.pop(context),
            ),
          ),
        ],
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
            onSaved: () => context.pop(),
          ),
        ],
      ),
    );
  }
}
