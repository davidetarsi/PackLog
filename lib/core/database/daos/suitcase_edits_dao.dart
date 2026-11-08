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
  /// sostituito.
  Future<void> enqueue(List<SuitcaseEdit> edits) async {
    if (edits.isEmpty) return;
    await batch((b) {
      b.insertAll(suitcaseEdits, [
        for (final e in edits)
          SuitcaseEditsCompanion.insert(
            id: e.id,
            tripId: e.tripId,
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
    return [for (final r in rows) _toModel(r)];
  }

  /// Toglie dalla coda le modifiche inviate.
  Future<void> deleteByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    await (delete(suitcaseEdits)..where((t) => t.id.isIn(ids))).go();
  }

  /// Svuota la coda (cambio account, logout).
  Future<void> deleteAll() => delete(suitcaseEdits).go();

  SuitcaseEdit _toModel(SuitcaseEditRow r) => SuitcaseEdit(
    id: r.id,
    tripId: r.tripId,
    at: r.at,
    action: SuitcaseEditAction.values.firstWhere((a) => a.dbValue == r.action),
    origin: SuitcaseEditOrigin.values.firstWhere((o) => o.dbValue == r.origin),
    copiesBefore: r.copiesBefore,
    copiesAfter: r.copiesAfter,
    card: _decode(r.cardJson),
    context: _decode(r.contextJson),
    generatorVersion: r.generatorVersion,
    analysisAllowed: r.analysisAllowed,
  );

  static Map<String, Object?> _decode(String json) {
    final decoded = jsonDecode(json);
    return decoded is Map ? Map<String, Object?>.from(decoded) : const {};
  }
}
