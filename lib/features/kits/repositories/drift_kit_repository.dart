import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/catalog/catalog_store.dart';
import '../../../core/database/daos/kits_dao.dart';
import '../../../core/database/database.dart';
import '../../../core/database/exceptions/database_exceptions.dart';
import '../model/kit_model.dart';
import 'kit_repository.dart';

/// [KitRepository] su Drift.
class DriftKitRepository implements KitRepository {
  DriftKitRepository(this._dao, this._getCurrentUserId);

  final KitsDao _dao;
  final String? Function() _getCurrentUserId;
  static const _uuid = Uuid();

  @override
  Stream<List<KitModel>> watchKits(String houseId) => _dao
      .watchKitsOfHouse(houseId)
      .map((list) => [for (final k in list) _toModel(k)]);

  @override
  Future<KitModel> createKit({
    required String houseId,
    required String name,
    List<String> activities = const [],
    List<String> transports = const [],
  }) async {
    final cleanName = _validName(name);
    return _dao.attachedDatabase.transaction(() async {
      if (await _dao.countLiveKitsOfHouse(houseId) >= kMaxKitsPerHouse) {
        throw const KitLimitException(kMaxKitsPerHouse);
      }
      final now = DateTime.now();
      final id = _uuid.v4();
      await _dao.upsertKit(
        KitsCompanion.insert(
          id: id,
          houseId: houseId,
          name: cleanName,
          activities: Value(jsonEncode(activities)),
          transports: Value(jsonEncode(transports)),
          createdAt: now,
          updatedAt: now,
          userId: Value(_getCurrentUserId()),
        ),
      );
      return _load(id);
    });
  }

  @override
  Future<void> updateKit(KitModel kit) async {
    final cleanName = _validName(kit.name);
    await _dao.attachedDatabase.transaction(() async {
      // Un kit inesistente o cancellato non si resuscita con un update.
      await _load(kit.id);
      await _dao.upsertKit(
        KitsCompanion(
          id: Value(kit.id),
          name: Value(cleanName),
          activities: Value(jsonEncode(kit.activities)),
          transports: Value(jsonEncode(kit.transports)),
          learned: Value(kit.learned.toJsonString()),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Il nome tagliato, da 1 a [kMaxKitNameLength] caratteri.
  String _validName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > kMaxKitNameLength) {
      throw ArgumentError.value(
        name,
        'name',
        'il nome del kit deve avere da 1 a $kMaxKitNameLength caratteri',
      );
    }
    return trimmed;
  }

  @override
  Future<void> deleteKit(String id) => _dao.softDeleteKit(id);

  @override
  Future<void> addItems(String kitId, Map<String, int> copiesByItemId) {
    return _dao.attachedDatabase.transaction(() async {
      final kit = await _load(kitId);
      // Solo oggetti vivi della casa del kit: gli altri sono ignorati.
      final valid = await _dao.liveItemIdsOfHouse(
        kit.houseId,
        copiesByItemId.keys.toList(),
      );
      final wanted = {
        for (final e in copiesByItemId.entries)
          if (valid.contains(e.key)) e.key: e.value,
      };
      final existing = {for (final r in kit.items) r.itemId};
      final added = wanted.keys.where((i) => !existing.contains(i));
      if (existing.length + added.length > kMaxItemsPerKit) {
        throw const KitLimitException(kMaxItemsPerKit);
      }
      final now = DateTime.now();
      for (final entry in wanted.entries) {
        await _dao.upsertKitItem(
          KitItemsCompanion.insert(
            id: _uuid.v4(),
            kitId: kitId,
            itemId: entry.key,
            copies: Value(entry.value < 1 ? 1 : entry.value),
            createdAt: now,
            updatedAt: now,
            userId: Value(_getCurrentUserId()),
          ),
        );
      }
    });
  }

  @override
  Future<void> removeItem(String kitId, String itemId) =>
      _dao.softDeleteKitItem(kitId, itemId);

  @override
  Future<KitModel> recordYes(String kitId, List<String> uses) async {
    final kit = await _load(kitId);
    final yes = {...kit.learned.yes};
    for (final use in uses.toSet()) {
      if (kit.activities.contains(use) || kit.transports.contains(use)) {
        continue;
      }
      // Gli usi in learned.no si contano lo stesso: la domanda non viene mai
      // riproposta per quelli, e se riproporla o no lo decide il Task 11.
      yes[use] = (yes[use] ?? 0) + 1;
    }
    final updated = kit.copyWith(
      learned: KitLearned(yes: yes, no: kit.learned.no),
    );
    await updateKit(updated);
    return updated;
  }

  @override
  Future<void> learnUse(String kitId, String use) async {
    final kit = await _load(kitId);
    if (kit.activities.contains(use) || kit.transports.contains(use)) return;
    final isTransport = CatalogStore.current.find('transport', use) != null;
    await updateKit(
      isTransport
          ? kit.copyWith(transports: [...kit.transports, use])
          : kit.copyWith(activities: [...kit.activities, use]),
    );
  }

  @override
  Future<void> refuseUse(String kitId, String use) async {
    final kit = await _load(kitId);
    if (kit.learned.no.contains(use)) return;
    await updateKit(
      kit.copyWith(
        learned: KitLearned(yes: kit.learned.yes, no: [...kit.learned.no, use]),
      ),
    );
  }

  Future<KitModel> _load(String id) async {
    final row = await _dao.getKitWithItems(id);
    if (row == null) throw EntityNotFoundException('kit($id)');
    return _toModel(row);
  }

  KitModel _toModel(KitWithItems row) {
    final kit = row.kit;
    return KitModel(
      id: kit.id,
      houseId: kit.houseId,
      name: kit.name,
      activities: _stringList(kit.activities),
      transports: _stringList(kit.transports),
      learned: KitLearned.fromJsonString(kit.learned),
      items: [
        for (final r in row.items)
          KitItem(id: r.id, kitId: r.kitId, itemId: r.itemId, copies: r.copies),
      ],
      createdAt: kit.createdAt,
      updatedAt: kit.updatedAt,
    );
  }

  List<String> _stringList(String source) {
    try {
      final json = jsonDecode(source);
      return json is List ? [for (final e in json) e.toString()] : const [];
    } on FormatException {
      return const [];
    }
  }
}
