import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_provider.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/ds_dialog.dart';
import '../../../shared/widgets/ds_inline_error.dart';
import '../../../shared/widgets/ds_settings.dart';
import '../../../shared/widgets/ds_text_button.dart';

/// Dialog di dettaglio aperto dal tap sulla SyncStatusTile quando ci sono
/// modifiche non ancora sincronizzate. Mostra, per tipo di entità, quante
/// modifiche sono in attesa e un motivo in linguaggio semplice — mai il
/// testo tecnico grezzo dell'eccezione (vedi `syncErrorReasonKey` in
/// `shared/helpers/sync_error_reason.dart`).
class SyncDetailsDialog extends ConsumerWidget {
  const SyncDetailsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDsDialog<void>(
      context,
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

    return DsDialog(
      title: 'profile.sync_details_dialog_title'.tr(),
      content: SizedBox(
        width: double.maxFinite,
        child: breakdownAsync.when(
          data: (breakdown) {
            if (breakdown.isEmpty) {
              return Text('profile.sync_status_synced'.tr());
            }
            return DsSettingsGroup(
              children: [
                for (final status in breakdown)
                  DsSettingsRow(
                    label: '${status.entityLabelKey.tr()} — ${status.count}',
                    leading: Icon(
                      _entityIcons[status.entityLabelKey] ?? Icons.info_outline,
                    ),
                    subtitle: status.reasonKey.tr(),
                  ),
              ],
            );
          },
          loading: () => Padding(
            padding: EdgeInsets.all(context.spacingMd),
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => DsInlineError(
            message: 'profile.sync_details_load_failed'.tr(),
            onRetry: () => ref.invalidate(syncUnsyncedBreakdownProvider),
          ),
        ),
      ),
      actions: [
        DsTextButton(
          onPressed: () => Navigator.of(context).pop(),
          label: 'common.close'.tr(),
        ),
      ],
    );
  }
}
