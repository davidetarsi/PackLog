import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import 'package:pack_log/shared/theme/cta_reserved_space.dart';
import 'package:pack_log/shared/widgets/ds_appear.dart';
import '../../../../shared/helpers/search_match.dart';
import '../../../../shared/widgets/ds_group_header.dart';
import '../../../items/model/item_model.dart';
import '../../../items/providers/item_provider.dart';
import '../../../items/view/item_card.dart';
import '../../../items/widgets/rapid_fire_input.dart';
import '../../../trips/providers/trip_items_status_provider.dart';

/// Pagina "aggiungi": mentre si scrive nel rapid fire la casa sparisce e
/// restano solo le risposte utili. "Già in casa": oggetti presenti
/// all'apertura che somigliano al testo. "Aggiunti ora": quelli salvati in
/// questa pagina. Vuota se non c'è niente da dire.
class AddPage extends ConsumerWidget {
  final String houseId;
  final String query;
  final Set<String> baselineIds;
  final void Function(int position) onExistingOpened;

  /// La scheda di un oggetto aperta dalla pagina si è chiusa.
  final VoidCallback onSheetClosed;

  const AddPage({
    super.key,
    required this.houseId,
    required this.query,
    required this.baselineIds,
    required this.onExistingOpened,
    required this.onSheetClosed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(itemNotifierProvider(houseId)).valueOrNull ??
        const <ItemModel>[];
    final quantitiesOnTrip = ref.watch(
      itemQuantitiesOnTripFromHouseProvider(houseId),
    );
    final matches = query.trim().length < 2
        ? const <ItemModel>[]
        : items
              .where(
                (i) =>
                    baselineIds.contains(i.id) && matchesSearch(i.name, query),
              )
              .toList();
    final added = items.where((i) => !baselineIds.contains(i.id)).toList();

    Widget card(ItemModel item, {VoidCallback? onOpened}) => ItemCard(
      item: item,
      houseId: houseId,
      quantityOnTrip: quantitiesOnTrip[item.id] ?? 0,
      onOpened: onOpened,
      // Qui la selezione non parte: il campo resta il centro della pagina.
      allowSelection: false,
      onSheetClosed: onSheetClosed,
    );

    return SingleChildScrollView(
      key: const Key('house_add_page'),
      // CtaReservedSpaceScope riflette la barra reale, la riga di pillole e
      // la tastiera, così l'ultima riga può scrollare sopra tutta la CTA.
      padding: EdgeInsets.only(
        left: context.spacingMd,
        right: context.spacingMd,
        bottom: context.ctaReservedHeight,
      ),
      // Solo il contenuto è "dentro" il campo: toccare lo spazio vuoto sotto
      // chiude la pagina, toccare una riga apre l'oggetto.
      child: TapRegion(
        groupId: rapidFireTapRegionGroup,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (matches.isNotEmpty) ...[
              DsGroupHeader(
                label: 'items.already_here'.tr(),
                count: matches.length,
              ),
              for (final (i, item) in matches.indexed)
                card(item, onOpened: () => onExistingOpened(i + 1)),
            ],
            if (added.isNotEmpty) ...[
              DsGroupHeader(label: 'items.added_now'.tr(), count: added.length),
              // Solo le righe nuove compaiono con la dissolvenza: la chiave
              // dell'id fa sì che le altre non si rianimino.
              for (final item in added)
                DsAppear(key: ValueKey(item.id), child: card(item)),
            ],
          ],
        ),
      ),
    );
  }
}
