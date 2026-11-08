import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show SentryLevel;

import '../../../core/analytics/analytics_service.dart';
import '../../../core/analytics/core_analytics_service.dart';
import '../../../core/consent/consent_provider.dart';
import '../../../core/monitoring/monitoring_service.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../shared/notifier/synced_crud_notifier.dart';
import '../../items/repositories/item_repository.dart';
import '../model/ai_packing.dart';
import '../model/suitcase_edit.dart';
import '../model/trip_model.dart';
import '../repositories/trip_repository.dart';
import '../services/packing_progress_tracker.dart';
import '../services/suitcase_edits.dart';
import '../services/trip_lifecycle_service.dart';
import 'suitcase_edits_provider.dart';
import 'trip_weather_provider.dart';

part 'trip_provider.g.dart';

/// Margine sopra l'orario di scadenza del viaggio, prima del ricaricamento.
const _kRefreshBuffer = Duration(seconds: 2);

@Riverpod(keepAlive: true)
class TripNotifier extends _$TripNotifier with SyncedCrudNotifier<TripModel> {
  TripRepository get _repo => ref.read(tripRepositoryProvider);
  CoreAnalyticsService get _analytics => ref.read(coreAnalyticsServiceProvider);

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

  Future<void> addTrip(TripModel model) => mutate(
    operation: () => _repo.addTrip(model),
    reload: _repo.getAllTrips,
    rethrowOnly: true,
    onSuccess: (trips) =>
        _analytics.trackTripCreated(tripId: model.id, totalTrips: trips.length),
  );

  Future<void> updateTrip(TripModel model) {
    final TripModel? before = _tripInState(model.id);
    return mutate(
      operation: () => _repo.updateTrip(model),
      reload: _repo.getAllTrips,
      rethrowOnly: true,
      onSuccess: (trips) async {
        _analytics.trackTripUpdated();
        await _recordEdits(before, _tripIn(trips, model.id));
      },
    );
  }

  Future<void> addItemsToTrip(String tripId, List<TripItem> items) {
    final TripModel? before = _tripInState(tripId);
    return mutate(
      operation: () => _repo.addItemsToTrip(tripId, items),
      reload: _repo.getAllTrips,
      rethrowOnly: true,
      onSuccess: (trips) async {
        _analytics.trackItemsAddedToTrip(tripId: tripId, count: items.length);
        await _recordEdits(before, _tripIn(trips, tripId));
      },
    );
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
      // misurerebbero intenzioni invece di fatti.
      //
      // `logEvent` grezzo e non `CoreAnalyticsService`: le proprietà sono
      // calcolate dal tracker, e far conoscere al livello tipato in `core/`
      // un tipo che vive in `features/trips/` invertirebbe la dipendenza.
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
    await _recordEdits(trip, updatedTrip);
  }

  /// Riempie il posto [slotId] con [item]: l'oggetto entra fra gli `items`
  /// del viaggio (se c'è già lo stesso id, le quantità si sommano) e le copie
  /// rimaste del posto scendono di `item.quantity`, mai sotto zero.
  ///
  /// Una sola scrittura per tutte e due le cose, con lo stesso schema di
  /// [updateAiSlot]: lo stato cambia subito; se il salvataggio fallisce torna
  /// quello di prima e l'errore sale al chiamante. Viaggio, risultato senza
  /// posti o posto sconosciuto: nessuna scrittura.
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
                  ? i.copyWith(quantity: i.quantity + item.quantity)
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
    final List<TripModel> newTrips = [...trips];
    newTrips[tripIndex] = updatedTrip;
    state = AsyncData(newTrips);

    try {
      await _repo.updateTrip(updatedTrip);
    } catch (_) {
      final List<TripModel>? current = state.valueOrNull;
      if (current != null) {
        state = AsyncData([for (final t in current) t.id == tripId ? trip : t]);
      }
      rethrow;
    }
    ref.read(syncOrchestratorProvider).requestSync();
    await _recordEdits(trip, updatedTrip);

    // Dopo il salvataggio: si misurano i fatti, non le intenzioni.
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            'slot_filled',
            properties: {'level': level.name, 'copies': item.quantity},
          ),
    );
  }

  TripModel? _tripInState(String id) =>
      state.valueOrNull?.where((t) => t.id == id).firstOrNull;

  TripModel? _tripIn(List<TripModel> trips, String id) =>
      trips.where((t) => t.id == id).firstOrNull;

  /// Mette in coda le modifiche alla valigia proposta fra [before] e [after],
  /// dopo che il salvataggio è riuscito. Mai un errore da qui: se la
  /// registrazione fallisce il viaggio resta salvato e si perde solo l'evento.
  Future<void> _recordEdits(TripModel? before, TripModel? after) async {
    if (before == null || after == null) return;
    try {
      final Map<String, Map<String, Object?>?> cards = await _cardsOfChanged(
        before,
        after,
      );
      final List<SuitcaseEdit> edits = suitcaseEdits(
        before: before,
        after: after,
        now: DateTime.now(),
        analysisAllowed: ref.read(consentServiceProvider).analyticsEnabled,
        cardOf: (id) => cards[id],
        weather: _weatherContext(after.id),
      );
      if (edits.isEmpty) return;
      await ref.read(suitcaseEditsDaoProvider).enqueue(edits);
    } catch (error, stackTrace) {
      debugPrint('[TripNotifier] modifiche valigia non registrate: $error');
      ref
          .read(monitoringServiceProvider)
          .captureException(
            error,
            stackTrace: stackTrace,
            level: SentryLevel.warning,
            tags: {'operation': 'recordSuitcaseEdits', 'trip_id': after.id},
          );
    }
  }

  /// Le schede degli oggetti che differiscono fra [before] e [after], lette
  /// dal database locale (nessuna rete). Un oggetto senza scheda o non più
  /// in casa vale null.
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
    final ItemRepository items = ref.read(itemRepositoryProvider);
    final Map<String, Map<String, Object?>?> cards = {};
    for (final id in ids) {
      try {
        final String? raw = (await items.getItemById(id)).aiMetadata;
        final Object? decoded = raw == null || raw.isEmpty
            ? null
            : jsonDecode(raw);
        cards[id] = decoded is Map ? Map<String, Object?>.from(decoded) : null;
      } catch (_) {
        cards[id] = null;
      }
    }
    return cards;
  }

  /// Le medie per tappa del meteo del viaggio, solo se è già in memoria:
  /// nessuna chiamata in più. Senza i nomi dei luoghi.
  Map<String, Object?>? _weatherContext(String tripId) {
    final provider = tripWeatherNotifierProvider(tripId);
    // Il meteo dipende da questo notifier: `ref.exists` va bene, `ref.read`
    // dà CircularDependencyError. Qui serve solo il valore già in memoria,
    // senza creare dipendenze: si legge dal container.
    if (!ref.exists(provider)) return null;
    final TripWeatherState? weather = ref.container.read(provider).valueOrNull;
    if (weather is! TripWeatherReady) return null;
    return {
      'stops': [
        for (final s in weather.weather.stops)
          {
            'source': s.source.name,
            'days': s.days,
            'temp_min': s.tempMin,
            'temp_max': s.tempMax,
            'rain_days': s.rainDays,
            'rain_mm': s.rainMm,
            'wind_max_kmh': s.windMaxKmh,
            'uv_max': s.uvMax,
          },
      ],
    };
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

    final analytics = ref.read(analyticsServiceProvider);
    for (final event in events) {
      analytics.logEvent(event.name, properties: event.properties);
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

  /// Riusa un viaggio: crea una copia senza date, con tappe, oggetti
  /// (non spuntati) e bagagli.
  ///
  /// Returns: ID del nuovo viaggio creato.
  Future<String> reuseTrip(String tripId) async {
    late String newTripId;
    await mutate(
      operation: () async {
        newTripId = await _repo.reuseTrip(tripId);
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
