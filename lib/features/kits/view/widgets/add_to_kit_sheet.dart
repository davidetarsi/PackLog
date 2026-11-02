import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/catalog/catalog_provider.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/widgets/ds_form_sheet.dart';
import '../../../../shared/widgets/ds_settings.dart';
import '../../helpers/kit_use_labels.dart';
import '../../model/kit_model.dart';
import '../../providers/kit_provider.dart';

/// La scelta del foglio: un kit della casa, oppure ([kit] nullo) uno nuovo.
class AddToKitChoice {
  const AddToKitChoice(this.kit);

  final KitModel? kit;
}

/// Il foglio "Metti N oggetti in un kit": prima "Nuovo kit", poi i kit della
/// casa. Gli oggetti non si spostano: il kit li tiene insieme.
class AddToKitSheet extends ConsumerWidget {
  const AddToKitSheet({
    super.key,
    required this.houseId,
    required this.itemCount,
  });

  final String houseId;
  final int itemCount;

  static Future<AddToKitChoice?> show(
    BuildContext context, {
    required String houseId,
    required int itemCount,
  }) => showDsSheet<AddToKitChoice>(
    context,
    builder: (_) => AddToKitSheet(houseId: houseId, itemCount: itemCount),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(catalogRevisionProvider);
    final theme = Theme.of(context);
    final kits =
        ref.watch(kitNotifierProvider(houseId)).valueOrNull ?? const [];
    final muted = theme.colorScheme.onSurfaceVariant;

    return DsFormSheet(
      title: 'kits.sheet_title'.plural(itemCount, args: ['$itemCount']),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: context.spacingSm),
            child: Text(
              'kits.sheet_hint'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ),
          DsSettingsGroup(
            children: [
              DsSettingsRow(
                key: const Key('add_to_kit_new'),
                leading: Icon(Icons.add, color: muted),
                label: 'kits.new_title'.tr(),
                onTap: () =>
                    Navigator.of(context).pop(const AddToKitChoice(null)),
              ),
              for (final kit in kits)
                DsSettingsRow(
                  key: Key('add_to_kit_${kit.id}'),
                  leading: Icon(Icons.inventory_2_outlined, color: muted),
                  label: kit.name,
                  subtitle: kitUseLabels(kit).isEmpty
                      ? null
                      : kitUseLabels(kit).join(', '),
                  onTap: () => Navigator.of(context).pop(AddToKitChoice(kit)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
