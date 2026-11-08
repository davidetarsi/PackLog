import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/database/database.dart';
import 'package:pack_log/features/trips/model/suitcase_edit.dart';

import '../../helpers/test_database_setup.dart';

SuitcaseEdit _edit(String id, DateTime at, {bool allowed = true}) =>
    SuitcaseEdit(
      id: id,
      tripId: 't1',
      at: at,
      action: SuitcaseEditAction.removed,
      origin: SuitcaseEditOrigin.proposal,
      copiesBefore: 2,
      copiesAfter: 0,
      card: {
        'category': 'vestiti',
        'activityTags': ['city'],
      },
      context: {
        'days': 4,
        'stops': {
          'main': {'washer': true},
        },
      },
      generatorVersion: 'v9',
      analysisAllowed: allowed,
    );

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => closeTestDatabase(db));

  test('enqueue e pending restituiscono gli eventi in ordine di at', () async {
    await db.suitcaseEditsDao.enqueue([
      _edit('b', DateTime(2026, 11, 2)),
      _edit('a', DateTime(2026, 11, 1), allowed: false),
      _edit('c', DateTime(2026, 11, 3)),
    ]);

    final pending = await db.suitcaseEditsDao.pending();
    expect(pending.map((e) => e.id), ['a', 'b', 'c']);
    final first = pending.first;
    expect(first.analysisAllowed, isFalse);
    expect(first.action, SuitcaseEditAction.removed);
    expect(first.origin, SuitcaseEditOrigin.proposal);
    expect(first.copiesBefore, 2);
    expect(first.copiesAfter, 0);
    expect(first.card['activityTags'], ['city']);
    expect((first.context['stops'] as Map)['main'], {'washer': true});
    expect(first.generatorVersion, 'v9');
  });

  test('pending rispetta il limite', () async {
    await db.suitcaseEditsDao.enqueue([
      for (var i = 0; i < 5; i++) _edit('e$i', DateTime(2026, 11, 1 + i)),
    ]);
    final pending = await db.suitcaseEditsDao.pending(limit: 2);
    expect(pending.map((e) => e.id), ['e0', 'e1']);
  });

  test('deleteByIds toglie solo quelli indicati', () async {
    await db.suitcaseEditsDao.enqueue([
      _edit('a', DateTime(2026, 11, 1)),
      _edit('b', DateTime(2026, 11, 2)),
    ]);
    await db.suitcaseEditsDao.deleteByIds(['a']);
    expect((await db.suitcaseEditsDao.pending()).map((e) => e.id), ['b']);
  });

  test('deleteAll svuota la coda', () async {
    await db.suitcaseEditsDao.enqueue([_edit('a', DateTime(2026, 11, 1))]);
    await db.suitcaseEditsDao.deleteAll();
    expect(await db.suitcaseEditsDao.pending(), isEmpty);
  });
}
