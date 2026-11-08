import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/suitcase_edit.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/services/suitcase_edits.dart';

final _gen = DateTime(2026, 11, 1, 10);
final _now = DateTime(2026, 11, 8, 12);
final _departure = DateTime(2026, 11, 20, 8);

TripItem _item(
  String id, {
  int q = 1,
  bool checked = false,
  ItemCategory cat = ItemCategory.vestiti,
}) => TripItem(
  id: id,
  name: 'Nome privato $id',
  category: cat,
  quantity: q,
  isChecked: checked,
);

AiSlot _slot(
  String id, {
  int remaining = 1,
  bool removed = false,
  bool toBuy = false,
  ItemCategory cat = ItemCategory.vestiti,
}) => AiSlot(
  id: id,
  type: 'giacca_pioggia',
  category: cat,
  level: AiSlotLevel.important,
  name: 'Nome del posto',
  copies: 1,
  remaining: remaining,
  addLabel: 'Aggiungi',
  removed: removed,
  toBuy: toBuy,
);

TripModel _trip({
  List<TripItem> items = const [],
  List<AiSlot>? slots,
  List<String> proposal = const [],
  List<AiKitAdded> kit = const [],
  DateTime? generatedAt,
  bool withResult = true,
  DateTime? departure,
}) => TripModel(
  id: 'trip-1',
  name: 'Roma segreta',
  items: items,
  departureDateTime: departure ?? _departure,
  returnDateTime: DateTime(2026, 11, 25, 18),
  transports: const ['treno'],
  aiSetup: const AiPackingSetup(
    stops: {
      'main': AiStopAnswers(activities: ['city'], stay: 'hotel', washer: true),
    },
  ),
  aiResult: withResult
      ? AiPackingResult(
          generatedAt: generatedAt ?? _gen,
          houseId: 'h',
          generatorVersion: 'v9',
          slots: slots,
          kitAdded: kit,
          proposal: [
            for (final id in proposal)
              AiPackedItem(
                itemId: id,
                quantity: 1,
                reason: const AiReason(code: 'c', label: 'l', sentence: 's'),
              ),
          ],
        )
      : null,
  createdAt: _gen,
  updatedAt: _gen,
);

Map<String, Object?>? _card(String id) => {
  'category': 'vestiti',
  'warmth': 'caldo',
  'name': 'NON DEVE PASSARE',
};

List<SuitcaseEdit> _run(
  TripModel before,
  TripModel after, {
  DateTime? now,
  Map<String, Object?>? Function(String)? cardOf,
  Map<String, Object?>? weather,
}) {
  var n = 0;
  return suitcaseEdits(
    before: before,
    after: after,
    now: now ?? _now,
    analysisAllowed: true,
    cardOf: cardOf ?? _card,
    weather: weather,
    newId: () => 'id-${n++}',
  );
}

void main() {
  test('dbValue italiani', () {
    expect(SuitcaseEditAction.values.map((a) => a.dbValue), [
      'aggiunto',
      'tolto',
      'copie',
      'suggerimento_tolto',
      'posto_riempito',
      'da_comprare',
    ]);
    expect(SuitcaseEditOrigin.values.map((o) => o.dbValue), [
      'proposta',
      'posto',
      'kit',
      'utente',
    ]);
  });

  test('aggiunta dell\'utente', () {
    final e = _run(_trip(), _trip(items: [_item('a', q: 2)]));
    expect(e, hasLength(1));
    expect(e.single.action, SuitcaseEditAction.added);
    expect(e.single.origin, SuitcaseEditOrigin.user);
    expect(e.single.copiesAfter, 2);
    expect(e.single.tripId, 'trip-1');
    expect(e.single.at, _now);
    expect(e.single.generatorVersion, 'v9');
    expect(e.single.analysisAllowed, isTrue);
    expect(e.single.id, 'id-0');
  });

  test('rimozione di un proposto: origine proposta', () {
    final e = _run(
      _trip(items: [_item('a')], proposal: ['a']),
      _trip(proposal: ['a']),
    );
    expect(e.single.action, SuitcaseEditAction.removed);
    expect(e.single.origin, SuitcaseEditOrigin.proposal);
    expect(e.single.copiesBefore, 1);
  });

  test('oggetto di un kit: origine kit', () {
    final e = _run(
      _trip(
        items: [_item('k')],
        kit: [const AiKitAdded(kitId: 'x', itemId: 'k')],
      ),
      _trip(
        kit: [const AiKitAdded(kitId: 'x', itemId: 'k')],
      ),
    );
    expect(e.single.origin, SuitcaseEditOrigin.kit);
  });

  test('copie 3 -> 2', () {
    final e = _run(
      _trip(items: [_item('a', q: 3)], proposal: ['a']),
      _trip(items: [_item('a', q: 2)], proposal: ['a']),
    );
    expect(e.single.action, SuitcaseEditAction.copies);
    expect(e.single.copiesBefore, 3);
    expect(e.single.copiesAfter, 2);
    expect(e.single.origin, SuitcaseEditOrigin.proposal);
  });

  test('la spunta è ignorata', () {
    final e = _run(
      _trip(items: [_item('a')]),
      _trip(items: [_item('a', checked: true)]),
    );
    expect(e, isEmpty);
  });

  test('posto tolto con la X', () {
    final e = _run(
      _trip(slots: [_slot('s')]),
      _trip(slots: [_slot('s', removed: true, remaining: 0)]),
    );
    expect(e.single.action, SuitcaseEditAction.suggestionRemoved);
    expect(e.single.card, {'type': 'giacca_pioggia', 'level': 'importante'});
  });

  test('posto da comprare', () {
    final e = _run(
      _trip(slots: [_slot('s')]),
      _trip(slots: [_slot('s', toBuy: true)]),
    );
    expect(e.single.action, SuitcaseEditAction.toBuy);
  });

  test(
    'posto riempito con un capo nuovo: slotFilled + added con origine posto',
    () {
      final e = _run(
        _trip(slots: [_slot('s')]),
        _trip(slots: [_slot('s', remaining: 0)], items: [_item('n')]),
      );
      expect(e, hasLength(2));
      expect(e[0].action, SuitcaseEditAction.slotFilled);
      expect(e[1].action, SuitcaseEditAction.added);
      expect(e[1].origin, SuitcaseEditOrigin.slot);
    },
  );

  test('un capo di altra categoria non è del posto', () {
    final e = _run(
      _trip(slots: [_slot('s')]),
      _trip(
        slots: [_slot('s', remaining: 0)],
        items: [_item('n', cat: ItemCategory.varie)],
      ),
    );
    expect(e.last.origin, SuitcaseEditOrigin.user);
  });

  test('rigenerazione: nessun evento', () {
    final e = _run(
      _trip(items: [_item('a')]),
      _trip(generatedAt: DateTime(2026, 11, 8), items: [_item('b')]),
    );
    expect(e, isEmpty);
  });

  test('adozione (prima senza risultato): nessun evento', () {
    expect(_run(_trip(withResult: false), _trip(items: [_item('a')])), isEmpty);
    expect(_run(_trip(items: [_item('a')]), _trip(withResult: false)), isEmpty);
  });

  test('dopo la partenza (o alla partenza): nessun evento', () {
    final after = _trip(items: [_item('a')]);
    expect(_run(_trip(), after, now: _departure), isEmpty);
    expect(
      _run(_trip(), after, now: _departure.add(const Duration(hours: 1))),
      isEmpty,
    );
  });

  test('senza scheda: card vuota', () {
    final e = _run(_trip(), _trip(items: [_item('a')]), cardOf: (_) => null);
    expect(e.single.card, isEmpty);
  });

  test('card filtrata, context completo, nessun nome', () {
    final e = _run(
      _trip(),
      _trip(items: [_item('a')]),
      weather: {
        'main': {'temp_min': 5.0},
      },
    );
    final edit = e.single;
    expect(edit.card, {'category': 'vestiti', 'warmth': 'caldo'});
    expect(edit.context['days'], 5);
    expect(edit.context['transports'], ['treno']);
    expect(edit.context['stops'], {
      'main': {
        'activities': ['city'],
        'stay': 'hotel',
        'washer': true,
      },
    });
    expect(edit.context['weather'], isNotNull);
    final dump = jsonEncode([edit.card, edit.context]);
    expect(dump, isNot(contains('"name"')));
    expect(dump, isNot(contains('Nome privato')));
    expect(dump, isNot(contains('Roma segreta')));
  });

  test('posto tolto e da comprare nello stesso salvataggio: due eventi', () {
    final e = _run(
      _trip(slots: [_slot('s')]),
      _trip(slots: [_slot('s', removed: true, toBuy: true)]),
    );
    expect(e.map((x) => x.action), [
      SuitcaseEditAction.suggestionRemoved,
      SuitcaseEditAction.toBuy,
    ]);
  });

  test('due nuovi della stessa categoria e un posto calato: tutti utente', () {
    final e = _run(
      _trip(slots: [_slot('s')]),
      _trip(
        slots: [_slot('s', remaining: 0)],
        items: [_item('n1'), _item('n2')],
      ),
    );
    expect(
      e.where((x) => x.action == SuitcaseEditAction.slotFilled),
      hasLength(1),
    );
    final added = e.where((x) => x.action == SuitcaseEditAction.added);
    expect(added, hasLength(2));
    expect(added.every((x) => x.origin == SuitcaseEditOrigin.user), isTrue);
  });

  test('un id ripetuto in after.items dà un solo added', () {
    final e = _run(_trip(), _trip(items: [_item('a'), _item('a')]));
    expect(e, hasLength(1));
  });

  test('quantità a 0: copies X -> 0', () {
    final e = _run(
      _trip(items: [_item('a', q: 2)]),
      _trip(items: [_item('a', q: 0)]),
    );
    expect(e.single.action, SuitcaseEditAction.copies);
    expect(e.single.copiesBefore, 2);
    expect(e.single.copiesAfter, 0);
  });

  test('oggetto in proposta e in kit: proposta', () {
    final e = _run(
      _trip(
        items: [_item('a')],
        proposal: ['a'],
        kit: [const AiKitAdded(kitId: 'x', itemId: 'a')],
      ),
      _trip(
        proposal: ['a'],
        kit: [const AiKitAdded(kitId: 'x', itemId: 'a')],
      ),
    );
    expect(e.single.origin, SuitcaseEditOrigin.proposal);
  });

  test('partenza senza data: il viaggio non e partito, si registra', () {
    final noDate = _trip(items: [_item('a')]).copyWith(departureDateTime: null);
    final e = _run(_trip().copyWith(departureDateTime: null), noDate);
    expect(e.single.action, SuitcaseEditAction.added);
  });

  test('posti null prima o dopo: nessun evento sui posti', () {
    expect(_run(_trip(), _trip(slots: [_slot('s', removed: true)])), isEmpty);
    expect(_run(_trip(slots: [_slot('s')]), _trip()), isEmpty);
  });

  test('slotFilled senza oggetti nuovi: un solo evento', () {
    final e = _run(
      _trip(slots: [_slot('s')]),
      _trip(slots: [_slot('s', remaining: 0)]),
    );
    expect(e.single.action, SuitcaseEditAction.slotFilled);
  });

  test('card con subCategory e activityTags', () {
    final e = _run(
      _trip(),
      _trip(items: [_item('a')]),
      cardOf: (_) => {
        'subCategory': 'giacca',
        'activityTags': ['city'],
        'brand': 'x',
      },
    );
    expect(e.single.card, {
      'subCategory': 'giacca',
      'activityTags': ['city'],
    });
  });
}
