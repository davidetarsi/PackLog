import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/ds_group_header.dart';
import '../../../../shared/widgets/ds_settings.dart';
import '../../../items/model/item_model.dart';

/// "Già in casa": gli oggetti della casa che somigliano a ciò che si sta
/// scrivendo. Toccarne uno lo mette nel kit senza crearne un altro.
class KitHouseMatches extends StatelessWidget {
  const KitHouseMatches({
    super.key,
    required this.matches,
    required this.onPick,
  });

  final List<ItemModel> matches;
  final ValueChanged<ItemModel> onPick;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsGroupHeader(label: 'items.already_here'.tr(), count: matches.length),
        DsSettingsGroup(
          children: [
            for (final item in matches)
              DsSettingsRow(
                key: Key('kit_match_${item.id}'),
                label: item.name,
                onTap: () => onPick(item),
              ),
          ],
        ),
      ],
    );
  }
}
