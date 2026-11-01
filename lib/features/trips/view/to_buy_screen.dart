import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/ds_empty_state.dart';
import '../../../shared/widgets/ds_group_header.dart';
import '../../../shared/widgets/ds_text_button.dart';
import '../model/ai_packing.dart';
import '../providers/to_buy_provider.dart';

/// Le cose da comprare di tutti i viaggi, raggruppate per viaggio.
///
/// Ogni riga ha "Presa", che porta al viaggio con la barra aperta su quel
/// posto: lì l'utente scrive cosa ha preso e il posto si riempie.
class ToBuyScreen extends ConsumerWidget {
  const ToBuyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(toBuyEntriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text('trips.to_buy.title'.tr())),
      body: entries.isEmpty
          ? DsEmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'trips.to_buy.empty'.tr(),
            )
          : _ToBuyList(entries: entries),
    );
  }
}

class _ToBuyList extends StatelessWidget {
  const _ToBuyList({required this.entries});

  final List<ToBuyEntry> entries;

  @override
  Widget build(BuildContext context) {
    // Le voci arrivano già in ordine: un viaggio dopo l'altro.
    final children = <Widget>[];
    String? currentTripId;
    for (final entry in entries) {
      if (entry.trip.id != currentTripId) {
        currentTripId = entry.trip.id;
        children.add(
          DsGroupHeader(
            key: Key('to_buy_trip_${entry.trip.id}'),
            label: entry.trip.name,
            prominent: true,
          ),
        );
      }
      children.add(_ToBuyRow(entry: entry));
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.spacingMd,
        0,
        context.spacingMd,
        context.spacingLg,
      ),
      children: children,
    );
  }
}

class _ToBuyRow extends StatelessWidget {
  const _ToBuyRow({required this.entry});

  final ToBuyEntry entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final slot = entry.slot;
    final muted = cs.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacingXs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (slot.level == AiSlotLevel.important) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        size: context.iconSizeXs,
                        color: muted,
                      ),
                      SizedBox(width: context.spacingXs),
                      Text(
                        'trips.slots.important'.tr(),
                        style: tt.labelLarge?.strong.copyWith(color: muted),
                      ),
                    ],
                  ),
                  SizedBox(height: context.spacingXxs),
                ],
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        slot.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyLarge,
                      ),
                    ),
                    if (slot.remaining > 1) ...[
                      SizedBox(width: context.spacingXs),
                      Text(
                        '×${slot.remaining}',
                        style: tt.bodyLarge?.copyWith(color: muted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          DsTextButton(
            key: Key('to_buy_got_it_${slot.id}'),
            label: 'trips.slots.got_it'.tr(),
            onPressed: () => context.push(
              Uri(
                path: '/trips/${entry.trip.id}',
                queryParameters: {'slot': slot.id},
              ).toString(),
            ),
          ),
        ],
      ),
    );
  }
}
