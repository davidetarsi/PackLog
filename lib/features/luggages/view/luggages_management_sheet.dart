import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/helpers/design_system.dart';
import '../../../shared/widgets/ds_form_sheet.dart';
import '../../../shared/widgets/ds_settings.dart';
import '../providers/luggage_provider.dart';
import 'add_edit_luggage_screen.dart';

Future<void> showLuggagesManagementSheet(BuildContext context) =>
    showDsFormSheet<void>(
      context,
      builder: (_) => const LuggagesManagementSheet(),
    );

/// Bagagli riutilizzabili in tutti i viaggi, anche senza alcuna casa.
class LuggagesManagementSheet extends ConsumerWidget {
  const LuggagesManagementSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DsFormSheet(
    key: const Key('luggages_management'),
    title: 'luggages.manage'.tr(),
    child: ref
        .watch(luggageNotifierProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => DsErrorState(
            error: error,
            message: 'storage.load_failed'.tr(),
            onRetry: () => ref.invalidate(luggageNotifierProvider),
          ),
          data: (luggages) => DsSettingsGroup(
            children: [
              for (final luggage in luggages)
                DsSettingsRow(
                  key: Key('storage_luggage_${luggage.id}'),
                  leading: const Icon(Icons.luggage_outlined),
                  label: luggage.name,
                  subtitle: luggage.sizeDescription,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      showAddEditLuggageSheet(context, luggageId: luggage.id),
                ),
              DsSettingsRow(
                key: const Key('storage_add_luggage'),
                leading: const Icon(Icons.add),
                label: 'luggages.add_new'.tr(),
                onTap: () => showAddEditLuggageSheet(context),
              ),
            ],
          ),
        ),
  );
}
