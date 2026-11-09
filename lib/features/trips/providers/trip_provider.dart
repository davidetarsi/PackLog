import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SentryLevel;

import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/consent/consent_provider.dart';
import '../../../core/monitoring/monitoring_service.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../shared/notifier/synced_crud_notifier.dart';
import '../../items/model/item_model.dart';
import '../../items/providers/item_provider.dart';
import '../../items/repositories/item_repository.dart';
import '../model/ai_packing.dart';
import '../model/suitcase_edit.dart';
import '../model/trip_model.dart';
import '../model/trip_weather.dart';
import '../repositories/trip_repository.dart';
import '../services/packing_progress_tracker.dart';
import '../services/suitcase_analytics.dart';
import '../services/suitcase_edits.dart';
import '../services/trip_lifecycle_service.dart';
import '../services/trip_weather_service.dart';
import 'suitcase_edits_provider.dart';

part 'trip_provider.g.dart';

/// Margine sopra l'orario di scadenza del viaggio, prima del ricaricamento.
const _kRefreshBuffer = Duration(seconds: 2);

@Riverpod(keepAlive: true)
class TripNotifier extends _$TripNotifier with SyncedCrudNotifier<TripModel> {
  final Map<String, Future<void>> _editQueues = {};

  TripRepository get _repo => ref.read(tripRepositoryProvider);
  CoreAnalyticsService get _analytics => ref.read(coreAnalyticsServiceProvider);

  /// Serializza le scritture concorrenti dello stesso viaggio.
  Future<void> serializeEdit(String tripId, Future<void> Function() operation) {
    final previous = _editQueues[tripId] ?? Future<void>.value();
    final next = previous.then((_) => operation());
    late final Future<void> tail;
    tail = next.catchError((Object _, StackTrace _) {});
    _editQueues[tripId] = tail;
    tail.whenComplete(() {
      if (identical(_editQueues[tripId], tail)) _editQueues.remove(tripId);
    });
    return next;
  }

  @override
  Future<List<TripModel>> build() async {
    final TripLifecycleService lifecycle = ref.read(
      tripLifecycleServiceProvider,
    );

    // Trasferisce gli item alla casa di destinazione per i viaggi completati.
    // Idempotente: il filtro SQL in moveItemsToHouse esclude item già spostati.
    final List<TripModel> trips = await _repo.getAllTrips();
    final Set<String> affectedHouseIds = await lifecycle
        .transferItemsForCompletedTrips(trips);
    if (affectedHouseIds.isNotEmpty) {
      // I record toccati da moveItemsToHouse sono ora `pendingUpdate`:
      // chiediamo subito un push così la tile "Stato sincronizzazione" e il
      // dialog di logout riflettono il vero stato senza attendere il
      // prossimo trigger (mutazione utente, app_resume, connectivity).
      ref.read(syncOrchestratorProvider).requestSync();
    }

    // Auto-refresh allo scatto del prossimo cambio di status (upcoming→active
    // o active→completed). Timer locale al provider, cancellato in onDispose.
    _scheduleRefreshAt(lifecycle.computeNextStatusChange(trips));

    return trips;
  }

  @override
  void onMutationSuccess(List<TripModel> updated) {
    ref.read(syncOrchestratorProvider).requestSync();
  }

  void _scheduleRefreshAt(DateTime? at) {
    if (at == null) return;
    // +2s buffer per assorbire imprecisioni di scheduling del SO.
    final Duration delay = at.difference(DateTime.now()) + _kRefreshBuffer;
    final Timer timer = Timer(delay, () {
      debugPrint('[TripNotifier] Auto-refresh: cambio di stato viaggio');
      ref.invalidateSelf();
    });
    ref.onDispose(timer.cancel);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  /// [source] dice da dove nasce il viaggio (`'new'` | `'reuse'`) e va solo
  /// nell'evento `trip_created`.
  Future<void> addTrip(TripModel model, {String? source}) => mutate(
    operation: () => _repo.addTrip(model),
    reload: _repo.getAllTrips,
    rethrowOnly: true,
    onSuccess: (trips) => _analytics.trackTripCreated(
      tripId: model.id,
      totalTrips: trips.length,
      daysToDeparture: daysToDeparture(model.departureDateTime, DateTime.now()),
      source: source,
    ),
  );

  Future<void> updateTrip(TripModel model) async {
    final TripModel? before = _tripInState(model.id);
    await mutate(
      operation: () => _repo.updateTrip(model),
      reload: _repo.getAllTrips,
      rethrowOnly: true,
      onSuccess: (_) {
        _analytics.trackTripUpdated();
        _emitSuitcaseEvents(before, model);
      },
    );
    // Stato già aggiornato: la registrazione non blocca né cambia l'esito.
    _recordEditsInBackground(before, _tripInState(model.id));
  }

  Future<void> addItemsToTrip(String tripId, List<TripItem> items) async {
    final TripModel? before = _tripInState(tripId);
    await mutate(
      operation: () => _repo.addItemsToTrip(tripId, items),
      reload: _repo.getAllTrips,
      rethrowOnly: true,
      onSuccess: (trips) {
        _analytics.trackItemsAddedToTrip(tripId: tripId, count: items.length);
        final TripModel? after = trips.where((t) => t.id == tripId).firstOrNull;
        if (after != null) _emitSuitcaseEvents(before, after);
      },
    );
    _recordEditsInBackground(before, _tripInState(tripId));
  }

  Future<void> deleteTrip(String id) => mutate(
    operation: () => _repo.deleteTrip(id),
    reload: _repo.getAllTrips,
    rethrowOnly: true,
    onSuccess: (_) => _analytics.trackTripDeleted(),
  );

  Future<void> toggleItemCheck(String tripId, String itemId) async {
    try {
      final List<TripModel>? trips = state.value;
      if (trips == null) return;

      final int tripIndex = trips.indexWhere((t) => t.id == tripId);
      if (tripIndex == -1) return;

      final TripModel trip = trips[tripIndex];
      final int itemIndex = trip.items.indexWhere((i) => i.id == itemId);
      if (itemIndex == -1) return;

      final bool newChecked = !trip.items[itemIndex].isChecked;

      // Optimistic state update: l'UI riflette il toggle subito, senza
      // ricaricare tutta la lista trip dal DB.
      final List<TripItem> updatedItems = [...trip.items];
      updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(
        isChecked: newChecked,
      );
      final TripModel updatedTrip = trip.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
      );
      final List<TripModel> newTrips = [...trips];
      newTrips[tripIndex] = updatedTrip;
      state = AsyncData(newTrips);

      // Fast-path persistenza: una sola colonna toccata invece di
      // `replaceTripItems` (DELETE all + INSERT all) seguito da
      // `getAllTrips()`. Path caldo durante il packing.
      await _repo.setTripItemChecked(tripId, itemId, newChecked);

      // Funnel della preparazione valigia. Emesso **dopo** la persistenza:
      // se il salvataggio fallisce l'evento non deve partire, altrimenti si
      // misurerebbero intenzioni invece di fatti. Niente
      // `_emitSuitcaseEvents`: una spunta non cambia la valigia.
      _emitPackingEvents(
        tripId: tripId,
        trip: trip,
        updatedItems: updatedItems,
      );

      ref.read(syncOrchestratorProvider).requestSync();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Cambia il posto [slotId] della valigia AI del viaggio con [change]
  /// ("da comprare", spunta di un proposto...).
  ///
  /// Come [toggleItemCheck], lo stato cambia subito e poi si salva il
  /// viaggio, senza ricaricare la lista. Se il salvataggio fallisce torna lo
  /// stato di prima e l'errore sale al chiamante. Viaggio, risultato senza
  /// posti o posto sconosciuto: nessuna scrittura.
  Future<void> updateAiSlot(
    String tripId,
    String slotId,
    AiSlot Function(AiSlot) change,
  ) async {
    final List<TripModel>? trips = state.valueOrNull;
    if (trips == null) return;

    final int tripIndex = trips.indexWhere((t) => t.id == tripId);
    if (tripIndex == -1) return;

    final TripModel trip = trips[tripIndex];
    final AiPackingResult? result = trip.aiResult;
    if (result == null ||
        !(result.slots?.any((s) => s.id == slotId) ?? false)) {
      return;
    }

    final TripModel updatedTrip = trip.copyWith(
      aiResult: result.withSlot(slotId, change),
      updatedAt: DateTime.now(),
    );
    final List<TripModel> newTrips = [...trips];
    newTrips[tripIndex] = updatedTrip;
    state = AsyncData(newTrips);

    try {
      await _repo.updateTrip(updatedTrip);
    } catch (_) {
      // Torna il viaggio di prima; gli altri restano come sono adesso.
      final List<TripModel>? current = state.valueOrNull;
      if (current != null) {
        state = AsyncData([for (final t in current) t.id == tripId ? trip : t]);
      }
      rethrow;
    }
    ref.read(syncOrchestratorProvider).requestSync();
    _emitSuitcaseEvents(trip, updatedTrip);
    _recordEditsInBackground(trip, updatedTrip);
  }

  /// Riempie il posto [slotId] con [item]: l'oggetto entra fra gli `items`
  /// del viaggio (se c'è già lo stesso id, le quantità si sommano) e le copie
  /// rimaste del posto scendono di `item.quantity`, mai sotto zero.
  ///
  /// Una sola scrittura per entrambe le modifiche. Pubblica il nuovo viaggio
  /// solo dopo il salvataggio; un errore sale al chiamante senza stato
  /// ottimistico da ripristinare. Viaggio, risultato senza posti o posto
  /// sconosciuto: nessuna scrittura.
  Future<void> fillAiSlot(String tripId, String slotId, TripItem item) async {
    final List<TripModel>? trips = state.valueOrNull;
    if (trips == null) return;

    final int tripIndex = trips.indexWhere((t) => t.id == tripId);
    if (tripIndex == -1) return;

    final TripModel trip = trips[tripIndex];
    final AiPackingResult? result = trip.aiResult;
    if (result == null ||
        !(result.slots?.any((s) => s.id == slotId) ?? false)) {
      return;
    }

    final bool alreadyThere = trip.items.any((i) => i.id == item.id);
    final List<TripItem> items = alreadyThere
        ? [
            for (final i in trip.items)
              i.id == item.id
                  ? i.copyWith(
                      quantity: i.quantity + item.quantity,
                      isChecked: false,
                    )
                  : i,
          ]
        : [...trip.items, item];

    final TripModel updatedTrip = trip.copyWith(
      items: items,
      aiResult: result.withSlot(
        slotId,
        (s) => s.copyWith(remaining: max(0, s.remaining - item.quantity)),
      ),
      updatedAt: DateTime.now(),
    );
    final AiSlotLevel level = result.slots!
        .firstWhere((s) => s.id == slotId)
        .level;
    await _repo.updateTrip(updatedTrip);
    final List<TripModel>? current = state.valueOrNull;
    if (current != null) {
      state = AsyncData([
        for (final currentTrip in current)
          currentTrip.id == tripId ? updatedTrip : currentTrip,
      ]);
    }
    ref.read(syncOrchestratorProvider).requestSync();
    _recordEditsInBackground(trip, updatedTrip);

    // Dopo il salvataggio: si misurano i fatti, non le intenzioni.
    _analytics.trackSlotFilled(level: level.name, copies: item.quantity);
    _emitSuitcaseEvents(trip, updatedTrip);
  }

  /// Gli eventi della valigia AI dopo una scrittura riuscita, confrontando il
  /// viaggio [before] e [after]:
  /// - `ai_suitcase_changed` se la distanza dalla proposta è cambiata. Con
  ///   una proposta nuova (altro `generatedAt`, o nessun viaggio prima) non
  ///   parte: è la proposta appena salvata, non una modifica dell'utente;
  /// - `ai_warning_dismissed` per ogni avviso appena scartato;
  /// - `ai_slot_removed` per ogni posto appena tolto.
  ///
  /// Armadio e meteo si leggono solo se già caricati: qui non si avviano
  /// richieste.
  void _emitSuitcaseEvents(TripModel? before, TripModel after) {
    // Un errore dell'analytics non deve far fallire una scrittura riuscita.
    try {
      _emitSuitcaseEventsOrThrow(before, after);
    } catch (e) {
      debugPrint('[TripNotifier] eventi della valigia non emessi: $e');
    }
  }

  void _emitSuitcaseEventsOrThrow(TripModel? before, TripModel after) {
    final AiPackingResult? result = after.aiResult;
    final AiPackingResult? previous = before?.aiResult;
    if (result == null ||
        previous == null ||
        previous.generatedAt != result.generatedAt) {
      return;
    }

    final List<ItemModel> houseItems = _loadedItems(result.houseId);
    final types = subCategoryByIdOf(houseItems);
    // Senza armadio caricato la proposta non si confronta con i pezzi in casa.
    final available = houseItems.isEmpty
        ? null
        : {for (final item in houseItems) item.id: item.quantity};
    final SuitcaseDiff? now = suitcaseDiff(after, types, available: available);
    final SuitcaseDiff? then = suitcaseDiff(
      before!,
      types,
      available: available,
    );
    if (now != null && then != null && !sameSuitcaseDiff(now, then)) {
      unawaited(_trackSuitcaseChanged(after, now));
    }

    for (final id in result.dismissedWarnings) {
      if (previous.dismissedWarnings.contains(id)) continue;
      final warning = result.warnings.where((w) => w.id == id).firstOrNull;
      if (warning == null) continue;
      _analytics.trackAiWarningDismissed(
        code: warning.code,
        level: warning.level.name,
      );
    }

    final wasRemoved = {
      for (final s in previous.slots ?? const <AiSlot>[]) s.id: s.removed,
    };
    for (final slot in result.slots ?? const <AiSlot>[]) {
      if (slot.removed && wasRemoved[slot.id] == false) {
        _analytics.trackAiSlotRemoved(type: slot.type, level: slot.level.name);
      }
    }
  }

  List<ItemModel> _loadedItems(String houseId) {
    final provider = itemNotifierProvider(houseId);
    if (!ref.exists(provider)) return const [];
    return ref.read(provider).valueOrNull ?? const [];
  }

  /// Il meteo viene dalla copia sul telefono: il provider del meteo dipende
  /// da questo notifier e leggerlo da qui sarebbe un ciclo. La copia non
  /// avvia richieste e, se manca, l'evento parte senza clima.
  /// Dopo l'attesa `ref` non si usa: il notifier potrebbe non esserci più.
  Future<void> _trackSuitcaseChanged(TripModel trip, SuitcaseDiff diff) async {
    final analytics = _analytics;
    final TripWeather? weather = await ref
        .read(tripWeatherCacheProvider)
        .read(trip.id);
    analytics.trackAiSuitcaseChanged(
      tripId: trip.id,
      counts: suitcaseDiffProperties(diff),
      context: tripContext(
        trip,
        luggage: trip.luggages
            .where((l) => l.id == trip.aiSetup?.luggageId)
            .firstOrNull,
        weather: weather,
      ),
    );
  }

  TripModel? _tripInState(String id) =>
      state.valueOrNull?.where((t) => t.id == id).firstOrNull;

  /// Lancia [_recordEdits] senza aspettarla: il salvataggio è finito, la coda
  /// non deve né rallentarlo né cambiarne l'esito.
  void _recordEditsInBackground(TripModel? before, TripModel? after) {
    if (before == null || after == null) return;
    try {
      // Ora e consenso si fissano subito, non quando la scrittura gira.
      final DateTime now = DateTime.now();
      final bool allowed = ref.read(consentServiceProvider).analyticsEnabled;
      unawaited(_recordEdits(before, after, now, allowed));
    } catch (error) {
      // Anche la parte sincrona è protetta: il salvataggio è già riuscito.
      try {
        debugPrint('[TripNotifier] modifiche valigia non registrate: $error');
      } catch (_) {}
    }
  }

  /// Mette in coda le modifiche alla valigia proposta fra [before] e [after].
  /// Non lancia mai: se la registrazione fallisce il viaggio resta salvato e
  /// si perde solo l'evento.
  Future<void> _recordEdits(
    TripModel before,
    TripModel after,
    DateTime now,
    bool analysisAllowed,
  ) async {
    try {
      final Map<String, Map<String, Object?>?> cards = await _cardsOfChanged(
        before,
        after,
      );
      // Meteo: non si legge. Lo stato del provider potrebbe far partire una
      // richiesta nuova; senza garanzia di non farla, si omette.
      final List<SuitcaseEdit> edits = suitcaseEdits(
        before: before,
        after: after,
        now: now,
        analysisAllowed: analysisAllowed,
        cardOf: (id) => cards[id],
      );
      if (edits.isEmpty) return;
      // Senza utente non si mette in coda: l'invio non saprebbe di chi sono.
      final String? userId = ref.read(currentUserIdProvider);
      if (userId == null) return;
      await ref.read(suitcaseEditsDaoProvider).enqueue([
        for (final e in edits) e.copyWith(userId: userId),
      ]);
    } catch (error, stackTrace) {
      // Anche la segnalazione è protetta: un errore qui non deve salire.
      try {
        debugPrint('[TripNotifier] modifiche valigia non registrate: $error');
        ref
            .read(monitoringServiceProvider)
            .captureException(
              error,
              stackTrace: stackTrace,
              level: SentryLevel.warning,
              tags: {'operation': 'recordSuitcaseEdits', 'trip_id': after.id},
            );
      } catch (_) {}
    }
  }

  /// Le schede degli oggetti che differiscono fra [before] e [after], lette
  /// dal database locale in un solo accesso (nessuna rete). Un oggetto senza
  /// scheda o non più in casa vale null.
  Future<Map<String, Map<String, Object?>?>> _cardsOfChanged(
    TripModel before,
    TripModel after,
  ) async {
    if (before.aiResult == null || after.aiResult == null) return const {};
    final Map<String, int> was = {
      for (final i in before.items) i.id: i.quantity,
    };
    final Set<String> ids = {
      for (final i in after.items)
        if (was.remove(i.id) != i.quantity) i.id,
      ...was.keys,
    };
    if (ids.isEmpty) return const {};
    final Map<String, Map<String, Object?>?> cards = {
      for (final id in ids) id: null,
    };
    final List<ItemModel> found = await ref
        .read(itemRepositoryProvider)
        .getItemsByIds(ids.toList());
    for (final item in found) {
      try {
        final String? raw = item.aiMetadata;
        final Object? decoded = raw == null || raw.isEmpty
            ? null
            : jsonDecode(raw);
        cards[item.id] = decoded is Map
            ? Map<String, Object?>.from(decoded)
            : null;
      } catch (_) {}
    }
    return cards;
  }

  void _emitPackingEvents({
    required String tripId,
    required TripModel trip,
    required List<TripItem> updatedItems,
  }) {
    final events = packingEventsFor(
      tripId: tripId,
      checkedBefore: trip.items.where((i) => i.isChecked).length,
      checkedAfter: updatedItems.where((i) => i.isChecked).length,
      totalItems: trip.items.length,
      departureDateTime: trip.departureDateTime,
      now: DateTime.now(),
    );
    if (events.isEmpty) return;

    for (final event in events) {
      final p = event.properties;
      switch (event.name) {
        case 'packing_started':
          _analytics.trackPackingStarted(
            tripId: tripId,
            totalItems: p['total_items'] as int,
            daysToDeparture: p['days_to_departure'] as int?,
          );
        case 'packing_progress':
          _analytics.trackPackingProgress(
            tripId: tripId,
            threshold: p['threshold'] as int,
            daysToDeparture: p['days_to_departure'] as int?,
          );
        case 'packing_completed':
          _analytics.trackPackingCompleted(
            tripId: tripId,
            totalItems: p['total_items'] as int,
            daysToDeparture: p['days_to_departure'] as int?,
          );
      }
    }
  }

  /// Duplica un viaggio (Deep Copy: viaggio + tutti gli items).
  ///
  /// Returns: ID del nuovo viaggio creato.
  Future<String> duplicateTrip(String tripId, {String? nameSuffix}) async {
    late String newTripId;
    await mutate(
      operation: () async {
        newTripId = await _repo.duplicateTrip(
          tripId,
          nameSuffix: nameSuffix ?? ' (Copia)',
        );
      },
      reload: _repo.getAllTrips,
      rethrowOnly: true,
      onSuccess: (_) => _analytics.trackTripDuplicated(),
    );
    return newTripId;
  }

  Future<void> refresh() => mutate(
    operation: () async {},
    reload: _repo.getAllTrips,
    showLoading: true,
    // refresh() è wired a ErrorState.onRetry (VoidCallback) — niente rethrow.
    rethrowOnError: false,
  );

  /// Toggle dello stato salvato/preferito di un viaggio.
  Future<void> toggleSaved(String tripId) async {
    final List<TripModel>? trips = state.valueOrNull;
    if (trips == null) return;

    final int tripIndex = trips.indexWhere((t) => t.id == tripId);
    if (tripIndex == -1) return;

    final TripModel updatedTrip = trips[tripIndex].copyWith(
      isSaved: !trips[tripIndex].isSaved,
      updatedAt: DateTime.now(),
    );
    await mutate(
      operation: () => _repo.updateTrip(updatedTrip),
      reload: _repo.getAllTrips,
      rethrowOnly: true,
      onSuccess: (_) =>
          _analytics.trackTripSavedToggled(isSaved: updatedTrip.isSaved),
    );
  }
}
