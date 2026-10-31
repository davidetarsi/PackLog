import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/item_metadata_merge.dart';
import '../model/item_model.dart';
import '../repositories/item_repository.dart';
import 'item_metadata_service.dart';

/// Quanti oggetti al giorno, al massimo, il recupero completa. Resta sotto
/// il limite giornaliero dei nomi lato server (`item_name_daily_cap`), così le
/// aggiunte a mano dell'utente hanno sempre la precedenza.
const kItemMetadataBackfillDailyLimit = 30;

/// Il recupero non riparte prima di questo intervallo.
const kItemMetadataBackfillInterval = Duration(hours: 1);

/// Completa in background la scheda degli oggetti che non ce l'hanno:
/// aggiunti offline, o scritti a mano prima che la scheda arrivasse da
/// `item-metadata` (anche quelli con solo le scelte dell'utente, vedi
/// [needsAiMetadata]). Parte all'accesso (vedi `AuthNotifier`).
///
/// Lavora un oggetto alla volta, dal più vecchio, entro
/// [kItemMetadataBackfillDailyLimit] al giorno; si ferma alla prima risposta
/// mancata (rete, limite raggiunto) e riprova al giro dopo. La categoria non
/// cambia: questi oggetti l'utente li ha già visti e magari sistemati.
class ItemMetadataBackfill {
  ItemMetadataBackfill({
    required ItemRepository repository,
    required ItemMetadataService service,
    Future<SharedPreferences>? prefs,
    DateTime Function()? now,
  }) : _repo = repository,
       _service = service,
       _prefs = prefs,
       _now = now ?? DateTime.now;

  static const _dayKey = 'item_metadata_backfill_day';
  static const _countKey = 'item_metadata_backfill_count';
  static const _lastRunKey = 'item_metadata_backfill_last_run';

  final ItemRepository _repo;
  final ItemMetadataService _service;
  final Future<SharedPreferences>? _prefs;
  final DateTime Function() _now;
  bool _running = false;

  /// Un giro di recupero. Restituisce le case con oggetti aggiornati, da
  /// ricaricare; vuoto se non c'era niente da fare o non era il momento.
  Future<Set<String>> run() async {
    if (_running) return const {};
    _running = true;
    try {
      return await _run();
    } catch (e) {
      debugPrint('[Backfill] giro interrotto: $e');
      return const {};
    } finally {
      _running = false;
    }
  }

  Future<Set<String>> _run() async {
    final prefs = await (_prefs ?? SharedPreferences.getInstance());
    final now = _now();
    final lastRun = DateTime.tryParse(prefs.getString(_lastRunKey) ?? '');
    if (lastRun != null &&
        now.difference(lastRun) < kItemMetadataBackfillInterval) {
      return const {};
    }
    await prefs.setString(_lastRunKey, now.toIso8601String());

    final today = now.toIso8601String().substring(0, 10);
    var done = prefs.getString(_dayKey) == today
        ? prefs.getInt(_countKey) ?? 0
        : 0;
    if (done >= kItemMetadataBackfillDailyLimit) return const {};

    final pending =
        (await _repo.getAllItems())
            .where(
              (i) => needsAiMetadata(i.aiMetadata) && i.name.trim().isNotEmpty,
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final houses = <String>{};
    for (final item in pending) {
      if (done >= kItemMetadataBackfillDailyLimit) break;
      final scheda = await _service.fromName(item.name);
      if (scheda == null) break;
      done++;
      await prefs.setString(_dayKey, today);
      await prefs.setInt(_countKey, done);
      if (await _save(item, scheda)) houses.add(item.houseId);
    }
    return houses;
  }

  /// Scrive la scheda solo se l'oggetto c'è ancora, con lo stesso nome e
  /// ancora da completare. I campi scelti dall'utente restano suoi (vedi
  /// [mergeAiMetadata]).
  Future<bool> _save(ItemModel item, ItemMetadataResult scheda) async {
    try {
      final current = await _repo.getItemById(item.id);
      if (current.name != item.name || !needsAiMetadata(current.aiMetadata)) {
        return false;
      }
      await _repo.updateItem(
        current.copyWith(
          aiMetadata: mergeAiMetadata(
            current: current.aiMetadata,
            ai: scheda.metadata,
          ),
          updatedAt: _now(),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[Backfill] ${item.id} non aggiornato: $e');
      return false;
    }
  }
}
