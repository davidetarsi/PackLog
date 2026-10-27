import 'trip_leg.dart';
import 'trip_model.dart';

/// Tipo di riga nell'itinerario della cartolina.
enum ItineraryKind { departure, place, transfer, moreStops, ret }

/// Riga dell'itinerario di una cartolina. Immutabile.
///
/// Campi per tipo: [name] e [from]/[to] solo per `place`; [date] per
/// `departure`, `transfer` e `ret`; [hiddenStops] solo per `moreStops`.
class ItineraryEntry {
  const ItineraryEntry({
    required this.kind,
    this.name,
    this.date,
    this.from,
    this.to,
    this.hiddenStops,
  });

  final ItineraryKind kind;
  final String? name;
  final DateTime? date;
  final DateTime? from;
  final DateTime? to;
  final int? hiddenStops;

  @override
  bool operator ==(Object other) {
    return other is ItineraryEntry &&
        other.kind == kind &&
        other.name == name &&
        other.date == date &&
        other.from == from &&
        other.to == to &&
        other.hiddenStops == hiddenStops;
  }

  @override
  int get hashCode => Object.hash(kind, name, date, from, to, hiddenStops);
}

/// Nome del luogo di una tappa: testo prima della prima virgola, senza spazi.
String legPlaceName(TripLeg leg) {
  final full = leg.locationDisplayName.trim();
  final comma = full.indexOf(',');
  return comma < 0 ? full : full.substring(0, comma).trim();
}

String? _nonEmpty(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return value;
}

/// Titolo della cartolina: il nome del viaggio. Quando l'utente non lo scrive
/// la creazione ci mette la meta, quindi c'è quasi sempre; se manca si usa
/// [destination].
String postcardTitle(TripModel trip, {required String destination}) {
  final name = trip.name.trim();
  return name.isNotEmpty ? name : destination;
}

/// Nome della destinazione mostrato sulla cartolina.
///
/// Ordine: nome della casa (intero), città, parte prima della virgola della
/// località, nome del viaggio.
String tripDestinationName(TripModel trip, {String? houseName}) {
  final house = _nonEmpty(houseName);
  if (house != null) return house;

  final location = trip.destinationLocation;
  final city = _nonEmpty(location?.city);
  if (city != null) return city;

  final display = _nonEmpty(location?.displayName);
  if (display != null) {
    final comma = display.indexOf(',');
    final head = (comma < 0 ? display : display.substring(0, comma)).trim();
    if (head.isNotEmpty) return head;
  }

  return trip.name;
}

/// Giorni di calendario tra [from] e [to]. Null se manca una data.
int? nightsBetween(DateTime? from, DateTime? to) {
  if (from == null || to == null) return null;
  final start = DateTime.utc(from.year, from.month, from.day);
  final end = DateTime.utc(to.year, to.month, to.day);
  return end.difference(start).inDays;
}

/// Nome di una tappa: il nome della casa se la tappa ne ha una presente in
/// [houseNames], altrimenti [legPlaceName].
String _legName(TripLeg leg, Map<String, String> houseNames) {
  final houseId = leg.houseId;
  final house = houseId == null ? null : _nonEmpty(houseNames[houseId]);
  return house ?? legPlaceName(leg);
}

/// Itinerario della cartolina: righe Andata, luoghi, spostamenti e Ritorno.
///
/// Con più di [maxPlaces] luoghi mostra il primo e l'ultimo, e riassume le
/// tappe centrali con una riga `moreStops`. [houseNames] mappa l'id di una casa
/// al suo nome: una tappa che è una casa mostra quel nome, intero.
///
/// Di default le tappe datate si ordinano per inizio (la cartolina). Con
/// [sortLegs] false l'ordine è quello di [TripModel.legs]: la catena del passo
/// 1, dove una tappa può finire prima di iniziare e l'ordine per data non è
/// quello in cui le righe vanno mostrate e toccate.
List<ItineraryEntry> buildItinerary(
  TripModel trip, {
  required String destination,
  int maxPlaces = 3,
  Map<String, String> houseNames = const {},
  bool sortLegs = true,
}) {
  assert(maxPlaces >= 2);

  final departure = trip.departureDateTime;
  final returnAt = trip.returnDateTime;

  final legs = trip.legs;
  final dated = <TripLeg>[];
  if (sortLegs) {
    // A parità di partenza vale l'ordine d'ingresso: List.sort non è stabile.
    final datedEntries =
        legs.indexed.where((entry) => entry.$2.from != null).toList()
          ..sort((a, b) {
            final byFrom = a.$2.from!.compareTo(b.$2.from!);
            return byFrom != 0 ? byFrom : a.$1.compareTo(b.$1);
          });
    dated.addAll([for (final (_, leg) in datedEntries) leg]);
  } else {
    dated.addAll(legs.where((leg) => leg.from != null));
  }
  final undated = legs.where((leg) => leg.from == null);

  final stops = [...dated, ...undated];

  final places = <ItineraryEntry>[
    ItineraryEntry(
      kind: ItineraryKind.place,
      name: destination,
      from: departure,
      to: dated.isNotEmpty ? dated.first.from : returnAt,
    ),
    for (final leg in stops)
      ItineraryEntry(
        kind: ItineraryKind.place,
        name: _legName(leg, houseNames),
        from: leg.from,
        to: leg.to,
      ),
  ];

  final entries = <ItineraryEntry>[
    ItineraryEntry(kind: ItineraryKind.departure, date: departure),
  ];

  if (places.length > maxPlaces) {
    final first = places.first;
    final last = places.last;
    entries
      ..add(first)
      ..add(
        ItineraryEntry(
          kind: ItineraryKind.moreStops,
          hiddenStops: places.length - 2,
        ),
      )
      ..add(ItineraryEntry(kind: ItineraryKind.transfer, date: last.from))
      ..add(last);
  } else {
    for (var i = 0; i < places.length; i++) {
      if (i > 0) {
        entries.add(
          ItineraryEntry(kind: ItineraryKind.transfer, date: places[i].from),
        );
      }
      entries.add(places[i]);
    }
  }

  entries.add(ItineraryEntry(kind: ItineraryKind.ret, date: returnAt));
  return entries;
}

/// Tipo di francobollo della cartolina. [StampKind.past] è un viaggio il cui
/// ritorno è già passato: niente giorni, né "oggi".
enum StampKind { daysLeft, today, traveling, past, noDate }

/// Francobollo della cartolina: stato e, per [StampKind.daysLeft], i giorni.
///
/// Lo stato "in viaggio" si calcola su [now], lo stesso istante usato per i
/// giorni, così il risultato non dipende dall'orologio di sistema.
({StampKind kind, int? days}) stampFor(TripModel trip, DateTime now) {
  final departure = trip.departureDateTime;
  final returnAt = trip.returnDateTime;

  final traveling =
      departure != null &&
      !now.isBefore(departure) &&
      (returnAt == null || !now.isAfter(returnAt));
  if (traveling) return (kind: StampKind.traveling, days: null);

  if (returnAt != null && now.isAfter(returnAt)) {
    return (kind: StampKind.past, days: null);
  }

  if (departure == null) return (kind: StampKind.noDate, days: null);

  final days = nightsBetween(now, departure)!;
  if (days == 0) return (kind: StampKind.today, days: null);
  return (kind: StampKind.daysLeft, days: days);
}

/// Azione primaria della cartolina in cima.
enum PostcardCta { prepare, ready, continuePacking }

/// Azione primaria in base allo stato degli oggetti. "In corso" non conta.
PostcardCta ctaFor(TripModel trip) {
  if (trip.items.isEmpty) return PostcardCta.prepare;
  if (trip.items.every((item) => item.isChecked)) return PostcardCta.ready;
  return PostcardCta.continuePacking;
}

/// Viaggi in corso o futuri, nell'ordine della pila.
List<TripModel> upcomingTrips(List<TripModel> trips) {
  int rank(TripModel trip) {
    if (trip.isActive) {
      return trip.returnDateTime != null ? 0 : 1;
    }
    return trip.departureDateTime != null ? 2 : 3;
  }

  DateTime key(TripModel trip) {
    switch (rank(trip)) {
      case 0:
        return trip.returnDateTime!;
      case 2:
        return trip.departureDateTime!;
      default:
        return trip.createdAt;
    }
  }

  final result = trips
      .where((trip) => trip.isActive || trip.isUpcoming)
      .toList();
  // A parità di chiave lo spareggio è l'id: List.sort non è stabile e la
  // pila non deve cambiare ordine tra un rebuild e l'altro.
  result.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    final byKey = key(a).compareTo(key(b));
    return byKey != 0 ? byKey : a.id.compareTo(b.id);
  });
  return result;
}

/// Viaggi conclusi, dal più recente. A parità di data, ordine per id.
List<TripModel> pastTrips(List<TripModel> trips) {
  DateTime key(TripModel trip) =>
      trip.returnDateTime ?? trip.departureDateTime ?? trip.createdAt;

  final result = trips.where((trip) => trip.isCompleted).toList();
  result.sort((a, b) {
    final byKey = key(b).compareTo(key(a));
    return byKey != 0 ? byKey : a.id.compareTo(b.id);
  });
  return result;
}

/// Viaggi salvati, per data di partenza decrescente. A parità di data, ordine
/// per id.
List<TripModel> savedTrips(List<TripModel> trips) {
  DateTime key(TripModel trip) => trip.departureDateTime ?? trip.createdAt;

  final result = trips.where((trip) => trip.isSaved).toList();
  result.sort((a, b) {
    final byKey = key(b).compareTo(key(a));
    return byKey != 0 ? byKey : a.id.compareTo(b.id);
  });
  return result;
}

/// Raggruppa per anno di partenza (o di creazione), anni decrescenti.
/// L'ordine interno ai gruppi resta quello in ingresso.
List<MapEntry<int, List<TripModel>>> groupByYear(List<TripModel> trips) {
  final groups = <int, List<TripModel>>{};
  for (final trip in trips) {
    final year = (trip.departureDateTime ?? trip.createdAt).year;
    groups.putIfAbsent(year, () => []).add(trip);
  }
  final years = groups.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final year in years) MapEntry(year, groups[year]!)];
}
