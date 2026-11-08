import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../model/ai_packing.dart';
import '../model/suitcase_edit.dart';
import '../model/trip_model.dart';

/// Campi della scheda che possono entrare in un evento. Il nome scritto
/// dall'utente non c'è, e non deve mai arrivarci.
const kSuitcaseEditCardFields = <String>{
  'category',
  'subCategory',
  'warmth',
  'waterResistance',
  'formality',
  'activityTags',
};

const _uuid = Uuid();

/// Chiave dell'oggetto di un evento: SHA-256 esadecimale di
/// `<viaggio>:<oggetto>` (o `<viaggio>:slot:<posto>`). Stabile per lo stesso
/// oggetto nello stesso viaggio, non risale al nome.
String suitcaseItemKey(String tripId, String itemId, {bool slot = false}) =>
    sha256
        .convert(utf8.encode('$tripId:${slot ? 'slot:' : ''}$itemId'))
        .toString();

/// Le modifiche fatte dall'utente alla valigia proposta tra [before] e [after].
///
/// Funzione pura: non legge orologio, consenso né rete. Restituisce `[]` se il
/// viaggio non ha una valigia AI in entrambe le versioni, se la valigia è
/// stata rigenerata o adottata (`generatedAt` diverso) o se [now] non è prima
/// della partenza (senza data di partenza il viaggio conta come non partito). Le spunte non contano.
///
/// [cardOf] dà la scheda di un oggetto (null = nessuna scheda); ne passano solo
/// i campi di [kSuitcaseEditCardFields]. [weather], se passato, finisce nel
/// contesto così com'è (medie per tappa).
List<SuitcaseEdit> suitcaseEdits({
  required TripModel before,
  required TripModel after,
  required DateTime now,
  required bool analysisAllowed,
  required Map<String, Object?>? Function(String itemId) cardOf,
  Map<String, Object?>? weather,
  String Function()? newId,
}) {
  final beforeResult = before.aiResult;
  final afterResult = after.aiResult;
  if (beforeResult == null || afterResult == null) return const [];
  if (beforeResult.generatedAt != afterResult.generatedAt) return const [];
  final departure = after.departureDateTime;
  // Senza data di partenza il viaggio non è ancora partito: si registra.
  if (departure != null && !now.isBefore(departure)) return const [];

  final makeId = newId ?? () => _uuid.v4();
  final context = _context(after);
  final edits = <SuitcaseEdit>[];

  SuitcaseEdit edit(
    SuitcaseEditAction action,
    SuitcaseEditOrigin origin,
    Map<String, Object?> card,
    String itemKey, {
    int? copiesBefore,
    int? copiesAfter,
  }) => SuitcaseEdit(
    id: makeId(),
    tripId: after.id,
    itemKey: itemKey,
    at: now,
    action: action,
    origin: origin,
    copiesBefore: copiesBefore,
    copiesAfter: copiesAfter,
    card: card,
    context: {...context, if (weather != null) 'weather': weather},
    generatorVersion: afterResult.generatorVersion,
    analysisAllowed: analysisAllowed,
  );

  // Posti: confronto per id.
  final beforeSlots = {
    for (final s in beforeResult.slots ?? <AiSlot>[]) s.id: s,
  };
  final slotEdits = <SuitcaseEdit>[];
  // Quanti oggetti nuovi di una categoria possono aver riempito un posto.
  final filledByCategory = <Object, int>{};
  for (final slot in afterResult.slots ?? const <AiSlot>[]) {
    final old = beforeSlots[slot.id];
    if (old == null) continue;
    final slotKey = suitcaseItemKey(after.id, slot.id, slot: true);
    final card = <String, Object?>{
      'type': slot.type,
      'level': slot.level.dbValue,
    };
    if (!old.removed && slot.removed) {
      slotEdits.add(
        edit(
          SuitcaseEditAction.suggestionRemoved,
          SuitcaseEditOrigin.slot,
          card,
          slotKey,
        ),
      );
    }
    if (!old.toBuy && slot.toBuy) {
      slotEdits.add(
        edit(SuitcaseEditAction.toBuy, SuitcaseEditOrigin.slot, card, slotKey),
      );
    }
    if (!slot.removed && slot.remaining < old.remaining) {
      slotEdits.add(
        edit(
          SuitcaseEditAction.slotFilled,
          SuitcaseEditOrigin.slot,
          card,
          slotKey,
        ),
      );
      filledByCategory.update(
        slot.category,
        (n) => n + old.remaining - slot.remaining,
        ifAbsent: () => old.remaining - slot.remaining,
      );
    }
  }

  // Oggetti del viaggio: confronto per id.
  final proposed = {for (final p in afterResult.proposal) p.itemId};
  proposed.addAll(beforeResult.proposal.map((p) => p.itemId));
  final kitItems = {
    for (final k in [...beforeResult.kitAdded, ...afterResult.kitAdded])
      k.itemId,
  };
  // Primo id vince se un elenco ripete lo stesso oggetto.
  final beforeItems = <String, TripItem>{};
  for (final i in before.items) {
    beforeItems.putIfAbsent(i.id, () => i);
  }
  final afterItems = <String, TripItem>{};
  for (final i in after.items) {
    afterItems.putIfAbsent(i.id, () => i);
  }

  // Oggetti nuovi che non vengono dalla proposta né da un kit, per categoria:
  // solo se ce n'è uno solo il posto riempito è sicuramente il suo.
  final candidates = <Object, int>{};
  for (final i in afterItems.values) {
    if (!beforeItems.containsKey(i.id) &&
        !proposed.contains(i.id) &&
        !kitItems.contains(i.id)) {
      candidates.update(i.category, (n) => n + 1, ifAbsent: () => 1);
    }
  }

  SuitcaseEditOrigin originOf(String id, {Object? slotCategory}) {
    if (proposed.contains(id)) return SuitcaseEditOrigin.proposal;
    if (kitItems.contains(id)) return SuitcaseEditOrigin.kit;
    if (slotCategory != null &&
        candidates[slotCategory] == 1 &&
        (filledByCategory[slotCategory] ?? 0) > 0) {
      return SuitcaseEditOrigin.slot;
    }
    return SuitcaseEditOrigin.user;
  }

  for (final item in afterItems.values) {
    final old = beforeItems[item.id];
    if (old == null) {
      edits.add(
        edit(
          SuitcaseEditAction.added,
          originOf(item.id, slotCategory: item.category),
          _card(cardOf(item.id), item),
          suitcaseItemKey(after.id, item.id),
          copiesAfter: item.quantity,
        ),
      );
    } else if (old.quantity != item.quantity) {
      edits.add(
        edit(
          SuitcaseEditAction.copies,
          originOf(item.id),
          _card(cardOf(item.id), item),
          suitcaseItemKey(after.id, item.id),
          copiesBefore: old.quantity,
          copiesAfter: item.quantity,
        ),
      );
    }
  }
  for (final old in beforeItems.values) {
    if (afterItems.containsKey(old.id)) continue;
    edits.add(
      edit(
        SuitcaseEditAction.removed,
        originOf(old.id),
        _card(cardOf(old.id), old),
        suitcaseItemKey(after.id, old.id),
        copiesBefore: old.quantity,
      ),
    );
  }

  return [...slotEdits, ...edits];
}

/// La scheda dell'evento: i campi ammessi di [raw] più la categoria dell'app
/// dell'oggetto (`ItemCategory`, mai testo dell'utente) sotto `appCategory`.
Map<String, Object?> _card(Map<String, Object?>? raw, TripItem item) => {
  if (raw != null)
    for (final e in raw.entries)
      if (kSuitcaseEditCardFields.contains(e.key)) e.key: e.value,
  'appCategory': item.category.name,
};

/// Giorni del viaggio, risposte per tappa e mezzi. Niente nomi.
Map<String, Object?> _context(TripModel trip) {
  final from = trip.departureDateTime;
  final to = trip.returnDateTime;
  final days = (from == null || to == null)
      ? null
      : DateTime.utc(
          to.year,
          to.month,
          to.day,
        ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
  return {
    'days': days,
    'stops': {
      for (final e
          in (trip.aiSetup?.stops ?? const <String, AiStopAnswers>{}).entries)
        e.key: {
          'activities': e.value.activities,
          'stay': e.value.stay,
          'washer': e.value.washer,
        },
    },
    'transports': trip.transports,
  };
}
