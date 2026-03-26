import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/helpers/bottom_sheet_handle.dart';
import '../../../shared/theme/app_spacing.dart';

/// Bottom sheet per gestire azioni sul viaggio
/// 
/// Mostra un menu con le azioni disponibili:
/// - Modifica informazioni
/// - Modifica oggetti
Future<void> showTripManagementSheet(
  BuildContext context, {
  required String tripId,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => TripManagementSheet(tripId: tripId),
  );
}

class TripManagementSheet extends StatelessWidget {
  final String tripId;

  const TripManagementSheet({
    super.key,
    required this.tripId,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle per drag
            const BottomSheetHandle(),

            // Titolo
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.spacingMd,
                vertical: context.spacingSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'trips.manage_sheet_title'.tr(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Lista azioni
            ListTile(
              leading: Icon(Icons.edit, color: colorScheme.primary),
              title: Text('trips.edit_info'.tr()),
              onTap: () {
                Navigator.pop(context);
                context.push('/trips/$tripId/edit-info');
              },
            ),
            ListTile(
              leading: Icon(Icons.checklist, color: colorScheme.primary),
              title: Text('trips.edit_items'.tr()),
              onTap: () {
                Navigator.pop(context);
                context.push('/trips/$tripId/edit-items');
              },
            ),

            SizedBox(height: context.spacingMd),
          ],
        ),
      ),
    );
  }
}
