import 'package:flutter/material.dart';

import '../../../model/ai_packing.dart';
import '../../../model/trip_model.dart';

/// Cosa si può fare sui posti della valigia; li gestisce lo schermo.
class SlotActions {
  const SlotActions({
    required this.open,
    required this.close,
    required this.markToBuy,
    required this.toggle,
    required this.toggleItem,
    required this.remove,
    required this.dismiss,
    required this.popDone,
    required this.rowKey,
  });

  final ValueChanged<AiSlot> open;

  /// Richiude il posto aperto (un tocco sul resto spento).
  final VoidCallback close;
  final ValueChanged<AiSlot> markToBuy;
  final ValueChanged<AiSlot> toggle;

  /// La casella di un oggetto scritto nel posto aperto.
  final ValueChanged<TripItem> toggleItem;

  /// La X di un importante: chiede conferma prima di togliere.
  final ValueChanged<AiSlot> remove;

  /// Lo scorrimento di una proposta: toglie subito, con Annulla.
  final ValueChanged<AiSlot> dismiss;

  /// Il posto aperto ha finito di scoppiare ([OpenSlotState.popping]).
  final VoidCallback popDone;

  /// La chiave della riga di un oggetto, per farlo volare fino a lì.
  final GlobalKey Function(String itemId) rowKey;
}

/// Il posto aperto nel dettaglio: quale, gli oggetti scritti in questa
/// apertura, la chiave della card che lo contiene (per portarla in cima) e
/// se sta scoppiando ([popping]: copie finite o "Da comprare").
class OpenSlotState {
  const OpenSlotState({
    required this.slot,
    required this.written,
    required this.cardKey,
    this.popping = false,
  });

  final AiSlot slot;
  final List<TripItem> written;
  final GlobalKey cardKey;
  final bool popping;
}
