import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../model/trip_model.dart';
import '../../../providers/trip_provider.dart';
import '../../trip_detail_screen.dart';
import 'item_flight.dart';
import 'trip_items_card.dart';

/// Il volo degli oggetti scritti in un posto fino alla loro riga fra quelli
/// dell'utente, nel gruppo della loro categoria.
///
/// Si prendono i punti di partenza ([captureFlights]) prima di chiudere il
/// posto, poi si vola ([flyAfterFrame]) quando le righe nuove sono sul foglio.
mixin TripSlotFlights on ConsumerState<TripDetailScreen> {
  final _rowKeys = <String, GlobalKey>{};

  /// La chiave della riga di un oggetto: prima sta nel riquadro, poi nel suo
  /// gruppo.
  GlobalKey rowKey(String itemId) =>
      _rowKeys.putIfAbsent(itemId, GlobalKey.new);

  /// Un volo per ogni oggetto di [written] (una volta sola anche se è stato
  /// sommato a uno già presente), dalla riga che ha adesso.
  List<ItemFlight> captureFlights(List<TripItem> written) {
    final trips = ref.read(tripNotifierProvider).valueOrNull;
    final items = trips?.where((t) => t.id == widget.tripId).firstOrNull?.items;
    final flights = <ItemFlight>[];
    for (final id in {for (final w in written) w.id}) {
      final key = rowKey(id);
      final box = key.currentContext?.findRenderObject();
      final item = items?.where((i) => i.id == id).firstOrNull;
      if (box is! RenderBox || !box.hasSize || item == null) continue;
      flights.add(
        ItemFlight(
          from: box.localToGlobal(Offset.zero) & box.size,
          to: key,
          child: Material(
            color: context.groupSurface,
            child: PackedRow(item: item, onToggle: () {}),
          ),
        ),
      );
    }
    return flights;
  }

  /// Vola al frame dopo la chiusura, quando le righe nuove sono sul foglio.
  void flyAfterFrame(List<ItemFlight> flights) {
    if (flights.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) flyItems(context, flights: flights);
    });
  }
}
