import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../features/trips/model/suitcase_edit.dart';
import '../database.dart';
import '../tables/suitcase_edits_table.dart';

part 'suitcase_edits_dao.g.dart';

/// DAO della coda locale delle modifiche alla valigia proposta.
@DriftAccessor(tables: [SuitcaseEdits])
class SuitcaseEditsDao extends DatabaseAccessor<AppDatabase>
    with _$SuitcaseEditsDaoMixin {
  SuitcaseEditsDao(super.db);

  /// Mette in coda [edits] in una sola scrittura. Un id già presente viene
  /// sostituito. Le modifiche senza utente non si mettono in coda.
  Future<void> enqueue(List<SuitcaseEdit> input) async {
    final edits = [
      for (final e in input)
        if (e.userId != null) e,
    ];
    if (edits.isEmpty) return;
    await batch((b) {
      b.insertAll(suitcaseEdits, [
        for (final e in edits)
          SuitcaseEditsCompanion.insert(
            id: e.id,
            tripId: e.tripId,
            itemKey: e.itemKey,
            userId: e.userId!,
            at: e.at,
            action: e.action.dbValue,
            origin: e.origin.dbValue,
            copiesBefore: Value(e.copiesBefore),
            copiesAfter: Value(e.copiesAfter),
            cardJson: Value(jsonEncode(e.card)),
            contextJson: Value(jsonEncode(e.context)),
            generatorVersion: Value(e.generatorVersion),
            analysisAllowed: e.analysisAllowed,
          ),
      ], mode: InsertMode.insertOrReplace);
    });
  }

  /// Le modifiche in attesa, dalla più vecchia, al massimo [limit].
  Future<List<SuitcaseEdit>> pending({int limit = 200}) async {
    final rows =
        await (select(suitcaseEdits)
              ..orderBy([
                (t) => OrderingTerm.asc(t.at),
                (t) => OrderingTerm.asc(t.id),
              ])
              ..limit(limit))
            .get();
    final models = <SuitcaseEdit>[];
    final unreadable = <String>[];
    for (final r in rows) {
      final m = _toModel(r);
      if (m == null) {
        unreadable.add(r.id);
      } else {
        models.add(m);
      }
    }
    // Azione o origine sconosciute (versione futura, dati rovinati): non si
    // potranno mai inviare, quindi si tolgono invece di bloccare la coda.
    await deleteByIds(unreadable);
    return models;
  }

  /// Toglie dalla coda le modifiche inviate.
  Future<void> deleteByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    await (delete(suitcaseEdits)..where((t) => t.id.isIn(ids))).go();
  }

  /// Svuota la coda (cambio account, logout).
  Future<void> deleteAll() => delete(suitcaseEdits).go();

  SuitcaseEdit? _toModel(SuitcaseEditRow r) {
    final action = SuitcaseEditAction.values
        .where((a) => a.dbValue == r.action)
        .firstOrNull;
    final origin = SuitcaseEditOrigin.values
        .where((o) => o.dbValue == r.origin)
        .firstOrNull;
    if (action == null || origin == null) return null;
    return SuitcaseEdit(
      id: r.id,
      tripId: r.tripId,
      itemKey: r.itemKey,
      userId: r.userId,
      at: r.at,
      action: action,
      origin: origin,
      copiesBefore: r.copiesBefore,
      copiesAfter: r.copiesAfter,
      card: _decode(r.cardJson),
      context: _decode(r.contextJson),
      generatorVersion: r.generatorVersion,
      analysisAllowed: r.analysisAllowed,
    );
  }

  static Map<String, Object?> _decode(String json) {
    final decoded = jsonDecode(json);
    return decoded is Map ? Map<String, Object?>.from(decoded) : const {};
  }
}
