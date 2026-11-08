import '../../luggages/model/luggage_model.dart';
import '../model/trip_model.dart';
import '../model/trip_weather.dart';

/// Funzioni pure per gli eventi della valigia AI: trasformano viaggio, meteo
/// e armadio in proprietà piatte (solo testo, numeri e liste) per
/// `CoreAnalyticsService`. Mai la destinazione, i nomi delle tappe o dei capi.

/// La fascia di una temperatura in °C. Le soglie seguono il generatore
/// (21 è la soglia dei capi estivi).
String tempBand(double celsius) {
  if (celsius < 5) return 'lt5';
  if (celsius < 15) return '5_15';
  if (celsius < 21) return '15_21';
  if (celsius < 26) return '21_26';
  return 'gte26';
}

/// Il contesto di un viaggio: le risposte del foglio della valigia AI (id di
/// catalogo), il bagaglio, i mezzi e, se il meteo c'è, le fasce di
/// temperatura e i giorni di pioggia.
Map<String, Object> tripContext(
  TripModel trip, {
  LuggageModel? luggage,
  TripWeather? weather,
}) {
  final stops = trip.aiSetup?.stops.values ?? const [];
  final context = <String, Object>{
    'activities': {for (final s in stops) ...s.activities}.toList()..sort(),
    'stays': {for (final s in stops) ?s.stay}.toList()..sort(),
    'washer': stops.any((s) => s.washer),
    if (luggage != null) 'luggage_size': luggage.sizeType.name,
    'transports': trip.transports,
  };
  if (weather == null) return context;

  final maxima = weather.stops.map((s) => s.tempMax).whereType<double>();
  final minima = weather.stops.map((s) => s.tempMin).whereType<double>();
  final rain = weather.stops.map((s) => s.rainDays).whereType<double>();
  if (maxima.isNotEmpty) {
    context['temp_max_band'] = tempBand(maxima.reduce((a, b) => a > b ? a : b));
  }
  if (minima.isNotEmpty) {
    context['temp_min_band'] = tempBand(minima.reduce((a, b) => a < b ? a : b));
  }
  if (rain.isNotEmpty) context['rain_days'] = rain.reduce((a, b) => a + b);
  if (maxima.isNotEmpty || minima.isNotEmpty) {
    context['weather_source'] = weather.source?.name ?? 'mixed';
  }
  return context;
}

/// Giorni di calendario da [now] alla partenza; null senza partenza,
/// negativo se è già passata.
int? daysToDeparture(DateTime? departure, DateTime now) {
  if (departure == null) return null;
  final from = DateTime.utc(now.year, now.month, now.day);
  final to = DateTime.utc(departure.year, departure.month, departure.day);
  return to.difference(from).inDays;
}
