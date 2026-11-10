import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/helpers/snack_bar_helper.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/ds_empty_state.dart';
import '../../../shared/widgets/ds_group_header.dart';
import '../providers/trip_provider.dart';
import '../providers/to_buy_provider.dart';
import 'widgets/slots/to_buy_slot_row.dart';

/// Le cose da comprare di tutti i viaggi, raggruppate per viaggio.
///
/// Ogni riga ha un'azione concordata col nome, che porta al viaggio con la barra aperta su quel
/// posto: lì l'utente scrive cosa ha preso e il posto si riempie.
class ToBuyScreen extends ConsumerWidget {
  const ToBuyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(toBuyEntriesProvider);
    final container = ProviderScope.containerOf(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: Text('trips.to_buy.title'.tr())),
      body: entries.isEmpty
          ? DsEmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'trips.to_buy.empty'.tr(),
            )
          : _ToBuyList(
              entries: entries,
              onRemove: (entry) => _removeEntry(context, container, entry),
            ),
    );
  }
}

class _ToBuyList extends StatelessWidget {
  const _ToBuyList({required this.entries, required this.onRemove});

  final List<ToBuyEntry> entries;
  final ValueChanged<ToBuyEntry> onRemove;

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
      children.add(
        _ToBuyRow(
          entry: entry,
          onRemove: () => onRemove(entry),
          onGotIt: () => context.push(
            Uri(
              path: '/trips/${entry.trip.id}',
              queryParameters: {'slot': entry.slot.id},
            ).toString(),
          ),
        ),
      );
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
  const _ToBuyRow({
    required this.entry,
    required this.onRemove,
    required this.onGotIt,
  });

  final ToBuyEntry entry;
  final VoidCallback onRemove;
  final VoidCallback onGotIt;

  @override
  Widget build(BuildContext context) {
    return ToBuySlotRow(slot: entry.slot, onGotIt: onGotIt, onRemove: onRemove);
  }
}

Future<void> _removeEntry(
  BuildContext context,
  ProviderContainer container,
  ToBuyEntry entry,
) async {
  final notifier = container.read(tripNotifierProvider.notifier);
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final tripId = entry.trip.id;
  final slot = entry.slot;

  try {
    await notifier.serializeEdit(
      tripId,
      () => notifier.updateAiSlot(
        tripId,
        slot.id,
        (current) => current.copyWith(removed: true),
      ),
    );
  } catch (_) {
    if (messenger.mounted) {
      AppSnackBar.showErrorOn(messenger, 'errors.save_error'.tr());
    }
    return;
  }
  if (!context.mounted) return;
  AppSnackBar.showUndo(
    context,
    'trips.slots.removed'.tr(args: [slot.name]),
    onUndo: () {
      unawaited(() async {
        try {
          await notifier.serializeEdit(
            tripId,
            () => notifier.updateAiSlot(
              tripId,
              slot.id,
              (current) => current.copyWith(removed: false),
            ),
          );
        } catch (_) {
          if (messenger.mounted) {
            AppSnackBar.showErrorOn(messenger, 'errors.save_error'.tr());
          }
        }
      }());
    },
  );
}
