import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/catalog/catalog_choices.dart';
import '../../../../core/catalog/catalog_provider.dart';
import '../../../../shared/widgets/ds_choice_group.dart';

/// "Come ci vai?": i mezzi del viaggio, pillole a scelta multipla dal dominio
/// `transport` del catalogo. Facoltativa: si può non scegliere nulla.
class TripTransportChoice extends ConsumerWidget {
  const TripTransportChoice({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Il catalogo può cambiare in background.
    ref.watch(catalogRevisionProvider);
    return DsChoiceGroup<String>(
      title: 'trips.new.transport'.tr(),
      options: daProporre(
        vociDi('transport', activeOnly: false),
        giaUsate: selected,
        dominio: 'transport',
      ),
      labelOf: (id) => etichettaDi('transport', id),
      selected: selected.toSet(),
      multiple: true,
      required: false,
      // L'insieme tiene l'ordine dei tocchi.
      onChanged: (chosen) => onChanged(chosen.toList()),
    );
  }
}
