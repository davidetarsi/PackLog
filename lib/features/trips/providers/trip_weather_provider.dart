import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../houses/providers/house_provider.dart';
import '../model/trip_weather.dart';
import '../services/trip_weather_service.dart';
import 'trip_provider.dart';

part 'trip_weather_provider.g.dart';

/// Cosa mostra la sezione meteo della pagina valigia.
sealed class TripWeatherState {
  const TripWeatherState();
}

/// Il meteo c'è. Può essere vecchio se la richiesta nuova non è andata.
class TripWeatherReady extends TripWeatherState {
  const TripWeatherReady(this.weather);

  final TripWeather weather;
}

/// Il viaggio non può avere meteo: vedi [WeatherUnavailable.isShown].
class TripWeatherNotAvailable extends TripWeatherState {
  const TripWeatherNotAvailable(this.reason);

  final WeatherUnavailable reason;
}

/// Il tetto giornaliero dell'utente è finito e non c'è una copia da mostrare.
class TripWeatherCapReached extends TripWeatherState {
  const TripWeatherCapReached();
}

/// La richiesta non è andata e non c'è una copia da mostrare.
class TripWeatherFailed extends TripWeatherState {
  const TripWeatherFailed();
}

/// Il meteo di un viaggio, per tappa.
///
/// Si chiama la funzione solo se in cache non c'è un meteo fresco per lo
/// stesso viaggio (stesse tappe e date). Resta vivo: "Avanti" del nuovo
/// viaggio lo avvia e la pagina valigia, che si apre subito dopo, trova la
/// stessa richiesta in corso invece di farne un'altra.
@Riverpod(keepAlive: true)
class TripWeatherNotifier extends _$TripWeatherNotifier {
  /// Età oltre la quale "Aggiorna" richiede di nuovo. All'apertura invece
  /// vale [TripWeather.isFresh] (24 ore): così il tetto si consuma solo per
  /// una richiesta esplicita.
  static const manualRefreshAge = Duration(hours: 1);

  /// Il prossimo caricamento salta la cache: lo chiede "Aggiorna".
  bool _skipCache = false;

  @override
  Future<TripWeatherState> build(String tripId) async {
    final trips = await ref.watch(tripNotifierProvider.future);
    final houses = await ref.watch(houseNotifierProvider.future);
    final trip = trips.where((t) => t.id == tripId).firstOrNull;
    if (trip == null) {
      return const TripWeatherNotAvailable(WeatherUnavailable.noDates);
    }

    final plan = planTripWeather(trip, houses: houses, today: DateTime.now());
    switch (plan) {
      case TripWeatherNotPossible(:final reason):
        return TripWeatherNotAvailable(reason);
      case TripWeatherRequest():
        return _load(plan);
    }
  }

  Future<TripWeatherState> _load(TripWeatherRequest request) async {
    final cache = ref.read(tripWeatherCacheProvider);
    final cached = await cache.read(tripId);
    final sameTrip = cached != null && cached.signature == request.signature;
    final skipCache = _skipCache;
    _skipCache = false;
    if (!skipCache && sameTrip && cached.isFresh(DateTime.now())) {
      return TripWeatherReady(cached);
    }

    try {
      final weather = await ref.read(tripWeatherServiceProvider).fetch(request);
      await cache.write(tripId, weather);
      return TripWeatherReady(weather);
    } on TripWeatherCapException {
      // Una copia dello stesso viaggio, anche vecchia, è meglio di niente.
      if (sameTrip) return TripWeatherReady(cached);
      return const TripWeatherCapReached();
    } on TripWeatherException catch (e) {
      debugPrint('[TripWeatherNotifier] $e');
      if (sameTrip) return TripWeatherReady(cached);
      return const TripWeatherFailed();
    }
  }

  /// "Aggiorna": con un meteo arrivato da meno di [manualRefreshAge] non fa
  /// nulla e restituisce `false` (la pagina dice che è già aggiornato).
  /// Altrimenti richiede, anche se la copia ha meno di 24 ore, e restituisce
  /// `true`.
  Future<bool> refresh() async {
    final current = state.valueOrNull;
    if (state.isLoading) return false;
    if (current is TripWeatherReady) {
      final cached = await ref.read(tripWeatherCacheProvider).read(tripId);
      if (cached != null &&
          cached.signature == current.weather.signature &&
          cached.isFresh(DateTime.now(), maxAge: manualRefreshAge)) {
        return false;
      }
    }
    _skipCache = true;
    ref.invalidateSelf();
    await future;
    return true;
  }
}
