import 'dart:convert';

import '../../houses/model/house_model.dart';
import 'trip_model.dart';
import 'trip_postcard.dart';

/// Limiti della funzione `trip-weather` (`_shared/valigia/ingresso.ts`): oltre,
/// risponde 400. Si controllano prima, così non si spende una chiamata.
const kWeatherMaxDays = 60;
const kWeatherMaxStops = 8;
const kWeatherMaxDaysAhead = 730;

/// Lunghezza massima dei testi accettata dalla funzione.
const _kMaxText = 80;

/// Da dove viene il meteo di una tappa: previsione (entro 14 giorni dalla
/// fine) o media degli anni passati.
enum WeatherSource { forecast, climate }

/// Una tappa come la chiede l'app: un luogo e i giorni passati lì, in fila
/// dalla data di partenza della richiesta.
class WeatherStopRequest {
  const WeatherStopRequest({
    required this.name,
    required this.country,
    required this.lat,
    required this.lon,
    required this.from,
    required this.days,
  });

  final String name;
  final String? country;
  final double lat;
  final double lon;

  /// Primo giorno della tappa (mezzanotte locale).
  final DateTime from;
  final int days;

  /// Ultimo giorno della tappa.
  DateTime get to => _addDays(from, days - 1);

  Map<String, dynamic> toJson() => {
    'nome': name,
    if (country != null) 'paese': country,
    'lat': lat,
    'lon': lon,
    'giorni': days,
  };
}

/// Perché un viaggio non ha meteo. Alcuni motivi si dicono all'utente, altri
/// tolgono la sezione e basta (un viaggio passato non ha niente da mostrare).
enum WeatherUnavailable {
  /// Senza date.
  noDates,

  /// Già finito.
  past,

  /// Parte fra più di due anni.
  tooFar,

  /// Più di [kWeatherMaxDays] giorni.
  tooLong,

  /// Più di [kWeatherMaxStops] tappe.
  tooManyStops,

  /// Una tappa senza coordinate: un luogo salvato prima che le avessimo, o una
  /// casa senza località.
  missingPlace;

  /// Vero se la pagina valigia lo dice; falso se nasconde la sezione.
  bool get isShown => switch (this) {
    noDates || past || tooFar => false,
    tooLong || tooManyStops || missingPlace => true,
  };
}

/// La richiesta per un viaggio, oppure il motivo per cui non si fa.
sealed class TripWeatherPlan {
  const TripWeatherPlan();
}

class TripWeatherRequest extends TripWeatherPlan {
  const TripWeatherRequest(this.stops);

  /// Tappe in fila, senza buchi: la prima parte da [start].
  final List<WeatherStopRequest> stops;

  DateTime get start => stops.first.from;

  Map<String, dynamic> toJson() => {
    'trip': {
      'data_inizio': _isoDay(start),
      'tappe': [for (final stop in stops) stop.toJson()],
    },
  };

  /// La richiesta come testo: due viaggi con la stessa firma hanno lo stesso
  /// meteo, quindi è la chiave che rende valida la cache.
  String get signature => jsonEncode(toJson());
}

class TripWeatherNotPossible extends TripWeatherPlan {
  const TripWeatherNotPossible(this.reason);

  final WeatherUnavailable reason;
}

/// Il meteo di una tappa, già pronto da mostrare.
class StopWeather {
  const StopWeather({
    required this.name,
    required this.from,
    required this.to,
    required this.source,
    this.years,
    this.tempMin,
    this.tempMax,
    this.rainDays,
    this.rainMm,
    this.windMaxKmh,
    this.uvMax,
    this.forecastDays = const [],
  });

  final String name;
  final DateTime from;
  final DateTime to;
  final WeatherSource source;

  /// Anni mediati per le medie climatiche.
  final int? years;

  /// Medie delle minime e delle massime, in °C.
  final double? tempMin;
  final double? tempMax;

  /// Giorni con più di 1 mm di pioggia: per le medie climatiche è una media,
  /// quindi può avere i decimali.
  final double? rainDays;
  final double? rainMm;
  final double? windMaxKmh;
  final double? uvMax;

  /// I giorni della tappa che cadono nei prossimi 7, con le fasce orarie.
  /// Vuoto oltre, o se il dettaglio non è arrivato: allora la tappa non si
  /// apre.
  final List<DayWeather> forecastDays;

  int get days => _daysBetween(from, to) + 1;

  Map<String, dynamic> toJson() => {
    'name': name,
    'from': _isoDay(from),
    'to': _isoDay(to),
    'source': source.name,
    'years': years,
    'temp_min': tempMin,
    'temp_max': tempMax,
    'rain_days': rainDays,
    'rain_mm': rainMm,
    'wind_max_kmh': windMaxKmh,
    'uv_max': uvMax,
    'forecast_days': [for (final day in forecastDays) day.toJson()],
  };

  factory StopWeather.fromJson(Map<String, dynamic> json) => StopWeather(
    name: json['name'] as String,
    from: _parseDay(json['from'] as String),
    to: _parseDay(json['to'] as String),
    source: WeatherSource.values.byName(json['source'] as String),
    years: (json['years'] as num?)?.toInt(),
    tempMin: _double(json['temp_min']),
    tempMax: _double(json['temp_max']),
    rainDays: _double(json['rain_days']),
    rainMm: _double(json['rain_mm']),
    windMaxKmh: _double(json['wind_max_kmh']),
    uvMax: _double(json['uv_max']),
    forecastDays: [
      for (final day in json['forecast_days'] as List? ?? const [])
        DayWeather.fromJson(day as Map<String, dynamic>),
    ],
  );
}

/// Ore di una fascia: il giorno ne ha sei, 0-4, 4-8, … 20-24.
const kBandHours = 4;

/// Una fascia di quattro ore di un giorno di previsione.
class BandWeather {
  const BandWeather({
    required this.startHour,
    this.code,
    this.temp,
    this.rainProbability,
    this.rainMm,
    this.windKmh,
  });

  /// Ora di inizio: 0, 4, 8, 12, 16 o 20.
  final int startHour;

  /// Codice WMO più severo della fascia.
  final int? code;

  /// Temperatura media della fascia, in °C.
  final double? temp;

  /// Probabilità di pioggia più alta della fascia, in %.
  final int? rainProbability;
  final double? rainMm;
  final double? windKmh;

  int get endHour => startHour + kBandHours;

  Map<String, dynamic> toJson() => {
    'da': startHour,
    'codice': code,
    'temp_media': temp,
    'prob_pioggia': rainProbability,
    'pioggia_mm': rainMm,
    'vento_kmh': windKmh,
  };

  /// Dalla fascia di `trip-weather`: la cache usa la stessa forma.
  factory BandWeather.fromJson(Map<String, dynamic> json) => BandWeather(
    startHour: (json['da'] as num).toInt(),
    code: (json['codice'] as num?)?.toInt(),
    temp: _double(json['temp_media']),
    rainProbability: (json['prob_pioggia'] as num?)?.round(),
    rainMm: _double(json['pioggia_mm']),
    windKmh: _double(json['vento_kmh']),
  );
}

/// Un giorno di previsione: il riepilogo e le sei fasce.
class DayWeather {
  const DayWeather({
    required this.date,
    this.code,
    this.tempMin,
    this.tempMax,
    this.rainProbability,
    this.rainMm,
    this.windMaxKmh,
    this.uvMax,
    this.bands = const [],
  });

  final DateTime date;

  /// Codice WMO del giorno (il più severo, come lo dà Open-Meteo).
  final int? code;
  final double? tempMin;
  final double? tempMax;
  final int? rainProbability;
  final double? rainMm;
  final double? windMaxKmh;
  final double? uvMax;
  final List<BandWeather> bands;

  Map<String, dynamic> toJson() => {
    'data': _isoDay(date),
    'codice': code,
    'temp_min': tempMin,
    'temp_max': tempMax,
    'prob_pioggia': rainProbability,
    'pioggia_mm': rainMm,
    'vento_max_kmh': windMaxKmh,
    'uv_max': uvMax,
    'fasce': [for (final band in bands) band.toJson()],
  };

  /// Dal giorno di `trip-weather`: la cache usa la stessa forma.
  factory DayWeather.fromJson(Map<String, dynamic> json) => DayWeather(
    date: _parseDay(json['data'] as String),
    code: (json['codice'] as num?)?.toInt(),
    tempMin: _double(json['temp_min']),
    tempMax: _double(json['temp_max']),
    rainProbability: (json['prob_pioggia'] as num?)?.round(),
    rainMm: _double(json['pioggia_mm']),
    windMaxKmh: _double(json['vento_max_kmh']),
    uvMax: _double(json['uv_max']),
    bands: [
      for (final band in json['fasce'] as List? ?? const [])
        BandWeather.fromJson(band as Map<String, dynamic>),
    ],
  );
}

/// Il meteo di un viaggio, tappa per tappa, con il momento in cui è arrivato.
class TripWeather {
  const TripWeather({
    required this.signature,
    required this.fetchedAt,
    required this.stops,
  });

  /// Firma della richiesta che l'ha prodotto: vedi
  /// [TripWeatherRequest.signature].
  final String signature;
  final DateTime fetchedAt;
  final List<StopWeather> stops;

  /// Da dove viene il meteo di tutto il viaggio; `null` se le tappe sono miste.
  WeatherSource? get source {
    final sources = stops.map((s) => s.source).toSet();
    return sources.length == 1 ? sources.single : null;
  }

  /// Anni delle medie climatiche (il massimo fra le tappe).
  int? get years => stops
      .map((s) => s.years)
      .whereType<int>()
      .fold<int?>(null, (a, b) => a == null || b > a ? b : a);

  /// Vero se è arrivato da meno di [maxAge]: allora non si richiede.
  bool isFresh(DateTime now, {Duration maxAge = const Duration(hours: 24)}) =>
      now.difference(fetchedAt) < maxAge;

  Map<String, dynamic> toJson() => {
    'signature': signature,
    'fetched_at': fetchedAt.toUtc().toIso8601String(),
    'stops': [for (final stop in stops) stop.toJson()],
  };

  factory TripWeather.fromJson(Map<String, dynamic> json) => TripWeather(
    signature: json['signature'] as String,
    fetchedAt: DateTime.parse(json['fetched_at'] as String).toLocal(),
    stops: [
      for (final stop in json['stops'] as List)
        StopWeather.fromJson(stop as Map<String, dynamic>),
    ],
  );

  /// Legge la risposta di `trip-weather` per [request]. La richiesta è sempre
  /// a tappe, anche con una sola, quindi il dettaglio sta in `geo.per_tappa`.
  factory TripWeather.fromResponse(
    Map<String, dynamic> json, {
    required TripWeatherRequest request,
    required DateTime fetchedAt,
  }) {
    final perStop = (json['geo'] as Map<String, dynamic>)['per_tappa'] as List;
    if (perStop.length != request.stops.length) {
      throw const FormatException(
        'trip-weather: tappe diverse dalla richiesta',
      );
    }
    return TripWeather(
      signature: request.signature,
      fetchedAt: fetchedAt,
      stops: [
        for (var i = 0; i < perStop.length; i++)
          _stopFromResponse(
            perStop[i] as Map<String, dynamic>,
            request.stops[i],
          ),
      ],
    );
  }
}

StopWeather _stopFromResponse(
  Map<String, dynamic> perStop,
  WeatherStopRequest stop,
) {
  final meteo = perStop['meteo'] as Map<String, dynamic>;
  // "previsione" oppure "storico N anni".
  final fonte = meteo['fonte'] as String? ?? '';
  return StopWeather(
    name: stop.name,
    from: stop.from,
    to: stop.to,
    source: fonte == 'previsione'
        ? WeatherSource.forecast
        : WeatherSource.climate,
    years: (meteo['anni_mediati'] as num?)?.toInt(),
    tempMin: _double(meteo['temp_min_media']),
    tempMax: _double(meteo['temp_max_media']),
    rainDays: _double(meteo['giorni_di_pioggia']),
    rainMm: _double(meteo['pioggia_totale_mm']),
    windMaxKmh: _double(meteo['vento_max_kmh']),
    uvMax: _double(meteo['uv_max']),
    // Manca finché la funzione non lo manda: la tappa resta senza dettaglio.
    forecastDays: [
      for (final day in perStop['dettaglio'] as List? ?? const [])
        DayWeather.fromJson(day as Map<String, dynamic>),
    ],
  );
}

/// Un luogo del viaggio con il giorno da cui ci si sta.
class _Place {
  const _Place({
    required this.start,
    required this.name,
    this.country,
    this.lat,
    this.lon,
  });

  final DateTime start;
  final String name;
  final String? country;
  final double? lat;
  final double? lon;
}

/// Prepara la richiesta del meteo di [trip] a partire da [today].
///
/// Ogni giorno va al luogo dove si dorme quella notte: la meta dalla partenza,
/// poi ogni tappa dal suo inizio; l'ultimo giorno resta all'ultimo luogo. I
/// giorni già passati si tolgono, così un viaggio in corso chiede il meteo di
/// quello che manca. Le coordinate di una casa vengono dalla sua località.
TripWeatherPlan planTripWeather(
  TripModel trip, {
  required List<HouseModel> houses,
  required DateTime today,
}) {
  final departure = trip.departureDateTime;
  final returnAt = trip.returnDateTime;
  if (departure == null || returnAt == null) {
    return const TripWeatherNotPossible(WeatherUnavailable.noDates);
  }

  final todayDay = _day(today);
  final first = _day(departure);
  final last = _day(returnAt);
  if (last.isBefore(todayDay)) {
    return const TripWeatherNotPossible(WeatherUnavailable.past);
  }
  if (_daysBetween(todayDay, first) > kWeatherMaxDaysAhead) {
    return const TripWeatherNotPossible(WeatherUnavailable.tooFar);
  }

  final housesById = {for (final house in houses) house.id: house};
  final destinationHouse = housesById[trip.destinationHouseId];
  final destination = trip.destinationLocation;
  final places = <_Place>[
    _Place(
      start: first,
      name: tripDestinationName(trip, houseName: destinationHouse?.displayName),
      country: destinationHouse?.location?.country ?? destination?.country,
      lat: destinationHouse?.location?.lat ?? destination?.lat,
      lon: destinationHouse?.location?.lon ?? destination?.lon,
    ),
    for (final leg in trip.legs)
      if (leg.from != null)
        _Place(
          start: _day(leg.from!),
          name:
              housesById[leg.houseId]?.displayName ??
              _shortName(leg.locationDisplayName),
          country: leg.country ?? housesById[leg.houseId]?.location?.country,
          lat: leg.lat ?? housesById[leg.houseId]?.location?.lat,
          lon: leg.lon ?? housesById[leg.houseId]?.location?.lon,
        ),
  ];
  // A parità di inizio vince la tappa: è lei che parte quel giorno.
  final ordered = [
    places.first,
    ...places.skip(1).toList()..sort((a, b) => a.start.compareTo(b.start)),
  ];

  // Il luogo di ogni giorno, dal primo che conta (oggi o la partenza).
  final from = first.isBefore(todayDay) ? todayDay : first;
  final dayCount = _daysBetween(from, last) + 1;
  if (dayCount > kWeatherMaxDays) {
    return const TripWeatherNotPossible(WeatherUnavailable.tooLong);
  }
  final runs = <({_Place place, DateTime from, int days})>[];
  for (var i = 0; i < dayCount; i++) {
    final day = _addDays(from, i);
    final place = ordered.lastWhere((p) => !p.start.isAfter(day));
    if (runs.isNotEmpty && identical(runs.last.place, place)) {
      final run = runs.removeLast();
      runs.add((place: run.place, from: run.from, days: run.days + 1));
    } else {
      runs.add((place: place, from: day, days: 1));
    }
  }

  if (runs.length > kWeatherMaxStops) {
    return const TripWeatherNotPossible(WeatherUnavailable.tooManyStops);
  }
  if (runs.any((run) => run.place.lat == null || run.place.lon == null)) {
    return const TripWeatherNotPossible(WeatherUnavailable.missingPlace);
  }

  return TripWeatherRequest([
    for (final run in runs)
      WeatherStopRequest(
        name: _clip(run.place.name),
        country: run.place.country == null ? null : _clip(run.place.country!),
        lat: run.place.lat!,
        lon: run.place.lon!,
        from: run.from,
        days: run.days,
      ),
  ]);
}

/// Il testo prima della virgola: "Sintra, Lisbona, Portogallo" → "Sintra".
String _shortName(String display) {
  final comma = display.indexOf(',');
  final head = (comma < 0 ? display : display.substring(0, comma)).trim();
  return head.isNotEmpty ? head : display.trim();
}

String _clip(String text) {
  final trimmed = text.trim();
  return trimmed.length <= _kMaxText
      ? trimmed
      : trimmed.substring(0, _kMaxText).trim();
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

/// Con il costruttore, non con una [Duration]: un giorno col cambio dell'ora
/// non dura 24 ore.
DateTime _addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

String _isoDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

DateTime _parseDay(String iso) {
  final parsed = DateTime.parse(iso);
  return DateTime(parsed.year, parsed.month, parsed.day);
}

double? _double(Object? value) => (value as num?)?.toDouble();
