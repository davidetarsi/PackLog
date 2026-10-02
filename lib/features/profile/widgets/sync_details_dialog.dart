import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_provider.dart';

/// Dialog di dettaglio aperto dal tap sulla SyncStatusTile quando ci sono
/// modifiche non ancora sincronizzate. Mostra, per tipo di entità, quante
/// modifiche sono in attesa e un motivo in linguaggio semplice — mai il
/// testo tecnico grezzo dell'eccezione (vedi `syncErrorReasonKey` in
/// `shared/helpers/sync_error_reason.dart`).
class SyncDetailsDialog extends ConsumerWidget {
  const SyncDetailsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const SyncDetailsDialog(),
    );
  }

  static const _entityIcons = <String, IconData>{
    'houses.title': Icons.home_outlined,
    'spaces.title': Icons.inventory_2_outlined,
    'luggages.title': Icons.work_outline,
    'profile.sync_entity_items': Icons.category_outlined,
    'trips.title': Icons.luggage_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdownAsync = ref.watch(syncUnsyncedBreakdownProvider);

    return AlertDialog(
      title: Text('profile.sync_details_dialog_title'.tr()),
      content: SizedBox(
        width: double.maxFinite,
        child: breakdownAsync.when(
          data: (breakdown) {
            if (breakdown.isEmpty) {
              return Text('profile.sync_status_synced'.tr());
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: breakdown
                  .map(
                    (status) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _entityIcons[status.entityLabelKey] ??
                            Icons.info_outline,
                      ),
                      title: Text(
                        '${status.entityLabelKey.tr()} — ${status.count}',
                      ),
                      subtitle: Text(status.reasonKey.tr()),
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Text('errors.load_failed'.tr()),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.close'.tr()),
        ),
      ],
    );
  }
}
