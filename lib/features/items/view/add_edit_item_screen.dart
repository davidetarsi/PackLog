import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/design_system/design_system.dart';
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
class AddEditItemSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.responsive(20)),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BottomSheetHandle(),
            Padding(
              padding: context.responsiveScreenPadding,
              child: Row(
                children: [
                  Text(
                    itemId != null ? 'Modifica oggetto' : 'Nuovo oggetto',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: context.iconSizeMd),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.spacingMd,
                0,
                context.spacingMd,
                context.spacingMd + AppConstants.bottomSheetBottomPadding,
              ),
              child: ItemFormContent(
                houseId: houseId,
                itemId: itemId,
                onSaved: (itemId, houseId) {
                  onItemSaved?.call(itemId, houseId);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Versione full-screen (mantenuta per retrocompatibilità con le route)
class AddEditItemScreen extends StatelessWidget {
  final String? houseId;
  final String? itemId;
  final void Function(String itemId, String houseId)? onItemSaved;

  const AddEditItemScreen({
    super.key,
    this.houseId,
    this.itemId,
    this.onItemSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(itemId != null ? 'Modifica oggetto' : 'Nuovo oggetto'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ItemFormContent(
            houseId: houseId,
            itemId: itemId,
            onSaved: (itemId, houseId) {
              onItemSaved?.call(itemId, houseId);
              context.pop();
            },
          ),
        ],
      ),
    );
  }
}
