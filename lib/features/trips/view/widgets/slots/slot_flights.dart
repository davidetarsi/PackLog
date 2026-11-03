import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/theme/theme.dart';
import '../../../model/trip_model.dart';
import '../../trip_detail_screen.dart';
import 'item_flight.dart';
import 'trip_items_card.dart';

/// Il volo degli oggetti di un kit fino alla loro riga fra quelli dell'utente,
/// nel gruppo della loro categoria ([flyKitItems]).
mixin TripSlotFlights on ConsumerState<TripDetailScreen> {
  final _rowKeys = <String, GlobalKey>{};

  /// Gli oggetti in volo: la loro riga nel gruppo c'è già ma resta invisibile
  /// finché il volo non è finito, così non si vede il doppione.
  final flying = ValueNotifier<Set<String>>(const {});

  @override
  void dispose() {
    flying.dispose();
    super.dispose();
  }

  /// La chiave della riga di un oggetto nel suo gruppo.
  GlobalKey rowKey(String itemId) =>
      _rowKeys.putIfAbsent(itemId, GlobalKey.new);

  /// Gli oggetti di un kit entrano in valigia: [save] li scrive, poi ognuno
  /// vola da [from] (la riga del kit) alla sua riga nel gruppo. Mentre
  /// volano le loro righe restano invisibili. Se [save] fallisce niente vola.
  Future<void> flyKitItems({
    required Rect from,
    required List<TripItem> items,
    required Future<void> Function() save,
  }) async {
    final start = Rect.fromCenter(
      center: from.center,
      width: from.width,
      height: kMinInteractiveDimension,
    );
    final flights = [
      for (final item in items)
        ItemFlight(
          from: start,
          to: rowKey(item.id),
          child: Material(
            color: context.groupSurface,
            child: PackedRow(item: item, onToggle: () {}),
          ),
        ),
    ];
    flying.value = {for (final item in items) item.id};
    try {
      await save();
    } catch (_) {
      if (mounted) flying.value = const {};
      rethrow;
    }
    flyAfterFrame(flights);
  }

  /// Vola quando le righe nuove sono sul foglio.
  void flyAfterFrame(List<ItemFlight> flights) {
    if (flights.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        flyItems(context, flights: flights).whenComplete(() {
          if (mounted) flying.value = const {};
        }),
      );
    });
  }
}
