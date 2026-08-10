import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/ds_button.dart';
import '../../../shared/widgets/ds_empty_state.dart';
import '../../../shared/widgets/refreshable_empty_state.dart';
import '../view/add_edit_item_screen.dart';

/// Stato vuoto della lista oggetti, unico per la casa e per il selettore del
/// viaggio.
///
/// Le due schermate mostravano lo stesso vuoto in due modi diversi: dentro la
/// casa senza alcuna azione, nel form di creazione viaggio con un testo
/// cliccabile. Entrambe finivano in un vicolo cieco o in una CTA che non
/// sembrava tale, quindi ora passano da qui e ottengono lo stesso bottone.
///
/// La CTA compare solo quando [houseId] è noto: senza una casa in cui creare
/// l'oggetto il bottone non avrebbe dove scrivere. Con un filtro di categoria
/// attivo i chiamanti passano `null`, perché lì la risposta è togliere il
/// filtro, non creare un oggetto che il filtro nasconderebbe comunque.
class ItemsEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  /// Casa in cui creare l'oggetto. `null` nasconde la CTA.
  final String? houseId;

  /// Key applicata al bottone, per i test che lo cercano.
  final Key? actionKey;

  /// Quando presente, il vuoto diventa scorrevole con pull-to-refresh.
  final Future<void> Function()? onRefresh;

  const ItemsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.houseId,
    this.actionKey,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final action = houseId == null
        ? null
        : DsButton(
            key: actionKey,
            label: 'items.add_item_to_house'.tr(),
            icon: Icons.add,
            onPressed: () => showAddEditItemSheet(context, houseId: houseId),
          );

    if (onRefresh != null) {
      return RefreshableEmptyState(
        onRefresh: onRefresh!,
        icon: icon,
        title: title,
        subtitle: subtitle,
        action: action,
      );
    }

    return DsEmptyState(
      icon: icon,
      title: title,
      subtitle: subtitle,
      action: action,
    );
  }
}
