import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/catalog/catalog_choices.dart';
import '../../../../core/catalog/catalog_provider.dart';
import '../../../../shared/theme/app_spacing.dart';
import '../../../../shared/theme/cta_reserved_space.dart';
import '../../../../shared/widgets/ds_field_label.dart';
import '../../../../shared/widgets/ds_settings.dart';
import '../../../items/providers/item_provider.dart';
import '../../../spaces/providers/space_provider.dart';
import '../../model/kit_model.dart';
import 'kit_item_row.dart';
import 'kit_use_pill.dart';

/// Dopo quanti sì in valigia una pillola nasce dall'uso.
const int _kLearnedAfterYes = 2;

/// Il kit aperto: le pillole d'uso con la provenienza di quelle imparate e gli
/// oggetti con le copie e lo spazio dove stanno. Gli oggetti che la casa non
/// ha più non compaiono.
class KitDetailBody extends ConsumerWidget {
  const KitDetailBody({super.key, required this.kit});

  final KitModel kit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(catalogRevisionProvider);
    final theme = Theme.of(context);
    final houseItems =
        ref.watch(itemNotifierProvider(kit.houseId)).valueOrNull ?? const [];
    final spaces =
        ref.watch(spaceNotifierProvider(kit.houseId)).valueOrNull ?? const [];
    final itemsById = {for (final item in houseItems) item.id: item};
    final spaceNames = {for (final space in spaces) space.id: space.name};

    final uses = [
      for (final id in kit.activities) ('activity', id),
      for (final id in kit.transports) ('transport', id),
    ];
    final learned = [
      for (final (domain, id) in uses)
        if ((kit.learned.yes[id] ?? 0) >= _kLearnedAfterYes)
          etichettaDi(domain, id),
    ];
    final rows = [
      for (final line in kit.items)
        if (itemsById[line.itemId] != null) (itemsById[line.itemId]!, line),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.spacingMd,
        0,
        context.spacingMd,
        context.spacingMd + context.ctaReservedHeight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (uses.isNotEmpty) ...[
            DsFieldLabel('kits.auto_title'.tr()),
            Wrap(
              spacing: context.spacingXs,
              runSpacing: context.spacingXs,
              children: [
                for (final (domain, id) in uses)
                  KitUsePill(label: etichettaDi(domain, id)),
              ],
            ),
            for (final label in learned)
              Padding(
                padding: EdgeInsets.only(top: context.spacingXs),
                child: Text(
                  'kits.learned_from'.tr(args: [label]),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
          DsFieldLabel.prominent('kits.in_kit'.tr(args: ['${rows.length}'])),
          if (rows.isNotEmpty)
            DsSettingsGroup(
              children: [
                for (final (item, line) in rows)
                  KitItemRow(
                    name: item.name,
                    copies: line.copies,
                    spaceName: spaceNames[item.spaceId],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
