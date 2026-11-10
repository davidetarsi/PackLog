import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../../../shared/widgets/ds_divider.dart';
import '../../../../../shared/widgets/ds_icon_button.dart';
import '../../../../../shared/widgets/ds_text_button.dart';
import '../../../../kits/view/widgets/kit_use_pill.dart';

/// La riga del kit in valigia, su tre livelli: la pillola neutra con quanti
/// oggetti sono già dentro e la X; i nomi di quelli che mancano; "Aggiungili
/// in valigia". È una riga, non una card: niente sfondo, solo una linea sotto.
class KitSuggestionRow extends StatelessWidget {
  const KitSuggestionRow({
    super.key,
    required this.kitName,
    required this.taken,
    required this.total,
    required this.missing,
    required this.onAdd,
    required this.onDismiss,
  });

  final String kitName;
  final int taken;
  final int total;

  /// I mancanti con le copie che entrerebbero.
  final List<({String name, int copies})> missing;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(top: context.spacingXs),
          child: Row(
            children: [
              // Pillola e avanzamento stanno in un solo Expanded: con due
              // figli flessibili il Row divide lo spazio a metà e, se la
              // pillola ne usa meno, il resto resta vuoto e la X si stacca
              // dal bordo.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: KitUsePill(
                        icon: Icons.inventory_2_outlined,
                        label: 'kits.trip_pill'.tr(args: [kitName]),
                      ),
                    ),
                    SizedBox(width: context.spacingSm),
                    Flexible(
                      child: Text(
                        'kits.trip_progress'.tr(args: ['$taken', '$total']),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              DsIconButton(
                key: const Key('kit_row_dismiss'),
                icon: Icons.close,
                tooltip: 'kits.trip_dismiss'.tr(),
                color: context.textTertiary,
                flushEnd: true,
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
        Text(
          'kits.trip_missing'.tr(args: [_names(missing)]),
          key: const Key('kit_row_missing'),
          style: theme.textTheme.bodyMedium,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DsTextButton(
            key: const Key('kit_row_add'),
            label: 'kits.trip_add'.tr(),
            accent: true,
            flushStart: true,
            onPressed: onAdd,
          ),
        ),
        const DsDivider(),
      ],
    );
  }
}

/// "A", "A e B", "A, B e C"; le copie oltre la prima dopo il nome: "A ×2".
String _names(List<({String name, int copies})> missing) {
  final parts = [
    for (final m in missing) m.copies > 1 ? '${m.name} ×${m.copies}' : m.name,
  ];
  if (parts.length == 1) return parts.first;
  final head = parts.sublist(0, parts.length - 1).join(', ');
  return '$head ${'kits.trip_and'.tr()} ${parts.last}';
}
