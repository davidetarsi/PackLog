import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../model/ai_packing.dart';
import '../../../model/trip_model.dart';

/// Fa entrare in valigia gli oggetti di un kit: [save] li scrive e, a
/// scrittura fatta, volano dalla riga del kit ([from], coordinate dello
/// schermo) alla loro riga. Se [save] fallisce non vola nulla e l'errore sale.
typedef FlyKitItems =
    Future<void> Function({
      required Rect from,
      required List<TripItem> items,
      required Future<void> Function() save,
    });

/// Cosa si può fare sui posti della valigia; li gestisce lo schermo.
class SlotActions {
  const SlotActions({
    required this.open,
    required this.markToBuy,
    required this.toggle,
    required this.remove,
    required this.dismiss,
    required this.removeItem,
    required this.toggleItem,
    required this.changeTrip,
    required this.runMutation,
    required this.rowKey,
    required this.flying,
    required this.flyKitItems,
  });

  /// Apre il foglio per riempire il posto con i propri oggetti.
  final ValueChanged<AiSlot> open;
  final ValueChanged<AiSlot> markToBuy;
  final ValueChanged<AiSlot> toggle;

  /// La X di un importante: chiede conferma prima di togliere.
  final ValueChanged<AiSlot> remove;

  /// Lo scorrimento di una proposta: toglie subito, con Annulla.
  final ValueChanged<AiSlot> dismiss;
  final ValueChanged<TripItem> removeItem;
  final ValueChanged<TripItem> toggleItem;
  final Future<void> Function(TripModel Function(TripModel) change) changeTrip;
  final Future<void> Function(Future<void> Function() change) runMutation;

  /// La chiave della riga di un oggetto, per farlo volare fino a lì.
  final GlobalKey Function(String itemId) rowKey;

  /// Gli oggetti che stanno volando verso la loro riga: la riga resta
  /// invisibile finché non atterrano.
  final ValueListenable<Set<String>> flying;

  /// Il volo degli oggetti di un kit verso i loro gruppi.
  final FlyKitItems flyKitItems;
}
