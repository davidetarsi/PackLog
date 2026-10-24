import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/constants/app_constants.dart';
import '../../../../../shared/theme/theme.dart';
import '../../../../items/model/item_model.dart';

/// Riga di un oggetto della casa che si può aggiungere alla valigia: nome,
/// categoria e "Aggiungi" a destra. Il tocco su tutta la riga aggiunge.
class AiWardrobeRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback onAdd;

  const AiWardrobeRow({
    super.key,
    required this.name,
    required this.subtitle,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return InkWell(
      onTap: onAdd,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacingMd,
          vertical: context.spacingSm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                  ),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            SizedBox(width: context.spacingSm),
            Icon(Icons.add, size: context.iconSizeSm, color: cs.onSurface),
            SizedBox(width: context.spacingXs),
            Text(
              'trips.pack.ai.home_add'.tr(),
              style: tt.labelLarge?.copyWith(color: cs.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

/// Il riquadro "Dalla casa · N oggetti" in fondo alla valigia generata:
/// chiuso di partenza, aperto elenca gli oggetti con "Aggiungi". Senza oggetti
/// non si disegna. Gli oggetti sono quelli che la pagina ha già filtrato
/// (niente vestiti, niente cose già in valigia).
class AiHomeGroup extends StatefulWidget {
  final List<ItemModel> items;
  final ValueChanged<ItemModel> onAdd;

  const AiHomeGroup({super.key, required this.items, required this.onAdd});

  @override
  State<AiHomeGroup> createState() => _AiHomeGroupState();
}

class _AiHomeGroupState extends State<AiHomeGroup> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: context.groupSurface,
      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: EdgeInsets.all(context.spacingMd),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'trips.pack.ai.home_title'.plural(items.length),
                          style: tt.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: context.spacingXs),
                        Text(
                          'trips.pack.ai.home_subtitle'.tr(),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.expand_more,
                    size: context.iconSizeMd,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            for (final item in items)
              AiWardrobeRow(
                key: Key('ai_home_add_${item.id}'),
                name: item.name,
                subtitle: item.category.displayName,
                onAdd: () => widget.onAdd(item),
              ),
        ],
      ),
    );
  }
}
