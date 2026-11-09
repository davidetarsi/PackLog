import 'package:uuid/uuid.dart';

import '../../../shared/model/location_suggestion_model.dart';
import 'trip_leg.dart';
import 'trip_model.dart';

/// Un posto scelto nel passo "Nuovo viaggio": una casa o un luogo della ricerca.
class DraftPlace {
  const DraftPlace.house({required String id, required this.name})
    : houseId = id,
      location = null;

  DraftPlace.location(LocationSuggestionModel loc)
    : houseId = null,
      name = loc.displayName,
      location = loc;

  /// Id della casa, null se è un luogo.
  final String? houseId;

  /// Nome mostrato: nome della casa, oppure nome completo del luogo.
  final String name;

  /// Luogo della ricerca, con coordinate e paese se presenti.
  final LocationSuggestionModel? location;

  /// Nome breve, come in [tripDestinationName]: casa intera, altrimenti città,
  /// altrimenti il testo prima della virgola.
  String get shortName {
    if (houseId != null) return name;
    final city = location?.city?.trim();
    if (city != null && city.isNotEmpty) return city;
    final comma = name.indexOf(',');
    final head = (comma < 0 ? name : name.substring(0, comma)).trim();
    return head.isNotEmpty ? head : name.trim();
  }
}

/// Una tappa della catena: il posto e il giorno in cui finisce.
/// La partenza non si salva qui: è la fine della tappa precedente.
class DraftStop {
  const DraftStop({required this.place, required this.end});

  final DraftPlace place;
  final DateTime end;
}

/// Bozza immutabile del passo 1 di "Nuovo viaggio".
///
/// `stops[0]` è la meta, con la sua fine. La tappa `i` parte alla fine della
/// `i-1` (la prima alla partenza). Il ritorno è la fine dell'ultima tappa.
/// Le date sono solo giorno (mezzanotte locale).
class TripDraft {
  const TripDraft._({
    this.departure,
    this.stops = const [],
    this.destination,
    this.name = '',
    this.nameEdited = false,
    this.pendingEnd,
    this.transports = const [],
    this.pendingStops = const [],
  });

  const TripDraft.empty() : this._();

  /// Bozza di un viaggio esistente, per modificarlo con la stessa pagina del
  /// nuovo viaggio. [houseName] è il nome della casa di destinazione, se lo è.
  ///
  /// La catena delle tappe si ricostruisce dalle date salvate: la meta finisce
  /// dove parte la prima tappa, ogni tappa dove parte la successiva, l'ultima
  /// al ritorno. Se mancano date restano meta e nome senza tappe.
  factory TripDraft.fromTrip(TripModel trip, {String? houseName}) {
    final destination = _destinationOf(trip, houseName);

    final departure = trip.departureDateTime == null
        ? null
        : _dayOf(trip.departureDateTime!);
    final ret = trip.returnDateTime == null
        ? null
        : _dayOf(trip.returnDateTime!);

    final legs = [...trip.legs]
      ..sort(
        (a, b) =>
            (a.from ?? DateTime(9999)).compareTo(b.from ?? DateTime(9999)),
      );

    var stops = <DraftStop>[];
    DateTime? pendingEnd;
    if (destination != null && departure != null && ret != null) {
      DateTime? endAt(int i) {
        // Fine della tappa i (0 = meta): l'inizio della successiva, o il
        // ritorno per l'ultima.
        if (i == legs.length) return ret;
        final next = legs[i].from ?? legs[i].to;
        return next == null ? null : _dayOf(next);
      }

      final chain = <DraftStop>[];
      var complete = true;
      for (var i = 0; i <= legs.length; i++) {
        final end = endAt(i);
        if (end == null) {
          complete = false;
          break;
        }
        final place = i == 0 ? destination : _placeOfLeg(legs[i - 1]);
        chain.add(DraftStop(place: place, end: end));
      }
      stops = complete ? chain : [DraftStop(place: destination, end: ret)];
    } else if (ret != null) {
      pendingEnd = ret;
    }

    return TripDraft._(
      departure: departure,
      stops: List.unmodifiable(stops),
      destination: destination,
      name: trip.name,
      nameEdited:
          trip.name.trim().isNotEmpty &&
          trip.name.trim() != destination?.shortName,
      pendingEnd: pendingEnd,
      transports: List.unmodifiable(trip.transports),
    );
  }

  /// Bozza di "Riusa": meta, mezzi e nome del viaggio passato, e i posti delle
  /// sue tappe senza date ([pendingStops]). Le date non si portano dietro: si
  /// scelgono da capo.
  factory TripDraft.reuseOf(TripModel trip, {String? houseName}) {
    final destination = _destinationOf(trip, houseName);
    final legs = [...trip.legs]
      ..sort(
        (a, b) =>
            (a.from ?? DateTime(9999)).compareTo(b.from ?? DateTime(9999)),
      );
    return TripDraft._(
      destination: destination,
      name: trip.name,
      nameEdited:
          trip.name.trim().isNotEmpty &&
          trip.name.trim() != destination?.shortName,
      transports: List.unmodifiable(trip.transports),
      pendingStops: destination == null
          ? const []
          : List.unmodifiable(legs.map(_placeOfLeg)),
    );
  }

  /// Data di partenza del viaggio.
  final DateTime? departure;

  /// Meta (indice 0) e tappe successive, in ordine.
  final List<DraftStop> stops;

  /// Meta scelta, anche prima delle date.
  final DraftPlace? destination;

  /// Testo del campo nome.
  final String name;

  /// True se l'utente ha cambiato il nome a mano: da quel momento non segue più la meta.
  final bool nameEdited;

  /// Fine delle date scelte prima della meta. Vale solo finché [stops] è vuoto.
  final DateTime? pendingEnd;

  /// Mezzi scelti (id del dominio `transport`), nell'ordine dei tocchi.
  final List<String> transports;

  /// Tappe di un viaggio riusato, ancora senza date: diventano tappe vere
  /// quando si scelgono le date della meta. Vale solo finché [stops] è vuoto.
  final List<DraftPlace> pendingStops;

  /// Fine dell'ultima tappa, o null senza meta con date.
  DateTime? get lastEnd => stops.isEmpty ? null : stops.last.end;

  /// Ritorno: fine dell'ultima tappa.
  DateTime? get returnDate => lastEnd ?? pendingEnd;

  bool get hasDestination => destination != null;

  bool get hasDates => departure != null && returnDate != null;

  /// Inizio della tappa [index]: 0 è la partenza, i è la fine della tappa i-1.
  DateTime? stopStart(int index) {
    if (index == 0) return departure;
    if (index < 0 || index > stops.length) return null;
    return stops[index - 1].end;
  }

  /// Tappe che non hanno almeno una notte (fine non dopo l'inizio).
  Set<int> get stopsWithoutNights {
    final result = <int>{};
    for (var i = 0; i < stops.length; i++) {
      final start = stopStart(i);
      if (start == null) continue;
      if (!stops[i].end.isAfter(start)) result.add(i);
    }
    return result;
  }

  bool get canSave => hasDestination && hasDates && stopsWithoutNights.isEmpty;

  /// Il modulo conta come compilato: meta, date, tappe o nome cambiato a mano.
  /// Il nome proposto da solo non conta.
  bool get hasUserInput =>
      hasDestination || departure != null || stops.isNotEmpty || nameEdited;

  /// Sceglie la meta. Se il nome non è stato cambiato a mano, segue la meta.
  TripDraft withDestination(DraftPlace place) {
    final endOfMeta = stops.isNotEmpty ? stops.first.end : pendingEnd;
    return _copy(
      destination: place,
      name: nameEdited ? name : place.shortName,
      stops: endOfMeta == null
          ? null
          : [DraftStop(place: place, end: endOfMeta), ...stops.skip(1)],
      clearPendingEnd: endOfMeta != null,
    );
  }

  /// Toglie la meta. Ogni tappa parte dalla precedente e la prima è la meta,
  /// quindi senza meta vanno via anche le tappe successive. Le date restano
  /// come date in attesa (la fine della vecchia meta). Il nome proposto si
  /// svuota, quello scritto a mano resta.
  TripDraft clearDestination() {
    if (destination == null) return this;
    final keptEnd = stops.isEmpty ? pendingEnd : stops.first.end;
    return _copy(
      clearDestinationPlace: true,
      name: nameEdited ? name : '',
      stops: const [],
      pendingEnd: keptEnd,
      pendingStops: const [],
    );
  }

  /// Imposta partenza e fine della prima tappa ("Quando?").
  TripDraft withFirstDates(DateTime start, DateTime end) {
    final s = _dayOf(start);
    final e = _dayOf(end);
    if (stops.isNotEmpty) {
      return _copy(
        departure: s,
        stops: [
          DraftStop(place: stops.first.place, end: e),
          ...stops.skip(1),
        ],
      );
    }
    final dest = destination;
    if (dest == null) {
      return _copy(departure: s, pendingEnd: e);
    }
    // Le tappe di "Riusa" nascono con la fine uguale all'inizio: zero notti,
    // segnalate sotto la tappa finché l'utente non ne sceglie le date.
    return _copy(
      departure: s,
      stops: [
        DraftStop(place: dest, end: e),
        for (final place in pendingStops) DraftStop(place: place, end: e),
      ],
      clearPendingEnd: true,
      pendingStops: const [],
    );
  }

  /// Imposta partenza e ritorno di tutto il viaggio ("Quando?").
  ///
  /// Con una sola tappa (o con le tappe di "Riusa" ancora in attesa, che non
  /// sono tappe vere) è [withFirstDates]. Con più tappe cambia la partenza e la
  /// fine dell'ultima; le fine intermedie restano. Null se le date tagliano
  /// fuori una tappa: partenza non prima della fine della prima, o ritorno non
  /// dopo l'inizio dell'ultima.
  TripDraft? withTripDates(DateTime departure, DateTime returnDate) {
    if (stops.length < 2) return withFirstDates(departure, returnDate);
    final s = _dayOf(departure);
    final e = _dayOf(returnDate);
    if (!s.isBefore(stops.first.end)) return null;
    if (!e.isAfter(stopStart(stops.length - 1)!)) return null;
    return _copy(
      departure: s,
      stops: [
        ...stops.take(stops.length - 1),
        DraftStop(place: stops.last.place, end: e),
      ],
    );
  }

  /// Nome del campo. Vuoto o solo spazi: torna a seguire la meta.
  TripDraft withName(String text) =>
      _copy(name: text, nameEdited: text.trim().isNotEmpty);

  /// Sceglie i mezzi del viaggio. Non conta come modulo compilato.
  TripDraft withTransports(List<String> ids) =>
      _copy(transports: List.unmodifiable(ids));

  /// Aggiunge una tappa in coda. Richiede la meta con le date.
  TripDraft addStop(DraftPlace place, DateTime end) {
    assert(
      stops.isNotEmpty,
      'Una tappa si aggiunge solo dopo la meta con le date',
    );
    return _copy(
      stops: [
        ...stops,
        DraftStop(place: place, end: _dayOf(end)),
      ],
    );
  }

  /// Cambia la fine della meta (la prima tappa): sposta solo l'inizio della
  /// seconda. Il luogo non cambia: si cambia da "Dove vai?".
  TripDraft withDestinationEnd(DateTime end) {
    assert(stops.isNotEmpty);
    return _copy(
      stops: [
        DraftStop(place: stops.first.place, end: _dayOf(end)),
        ...stops.skip(1),
      ],
    );
  }

  /// Cambia luogo o fine della tappa [index] (>= 1). Cambiare la fine sposta
  /// solo l'inizio della tappa successiva.
  TripDraft updateStop(int index, {DraftPlace? place, DateTime? end}) {
    assert(index >= 1 && index < stops.length);
    final old = stops[index];
    final next = [...stops]
      ..[index] = DraftStop(
        place: place ?? old.place,
        end: end == null ? old.end : _dayOf(end),
      );
    return _copy(stops: next);
  }

  /// Elimina la tappa [index] (>= 1). La successiva parte dalla fine della precedente.
  TripDraft removeStop(int index) {
    assert(index >= 1 && index < stops.length);
    final next = [...stops]..removeAt(index);
    return _copy(stops: next);
  }

  /// Viaggio da salvare. Le tappe dalla seconda in poi diventano [TripLeg].
  TripModel toTripModel({required String id, required DateTime now}) {
    const uuid = Uuid();
    final dest = destination;
    final houseId = dest?.houseId;
    final trimmedName = name.trim();

    final legs = <TripLeg>[];
    for (var i = 1; i < stops.length; i++) {
      final stop = stops[i];
      final loc = stop.place.location;
      legs.add(
        TripLeg(
          id: uuid.v4(),
          locationDisplayName: stop.place.name,
          from: stopStart(i),
          to: stop.end,
          lat: loc?.lat,
          lon: loc?.lon,
          country: loc?.country,
          houseId: stop.place.houseId,
        ),
      );
    }

    return TripModel(
      id: id,
      name: trimmedName.isNotEmpty ? trimmedName : (dest?.shortName ?? ''),
      departureDateTime: departure,
      returnDateTime: returnDate,
      destinationHouseId: houseId,
      destinationLocation: dest == null
          ? null
          : houseId != null
          ? LocationSuggestionModel(placeId: '', displayName: dest.name)
          : dest.location,
      legs: legs,
      transports: transports,
      createdAt: now,
      updatedAt: now,
    );
  }

  TripDraft _copy({
    DateTime? departure,
    List<DraftStop>? stops,
    DraftPlace? destination,
    String? name,
    bool? nameEdited,
    DateTime? pendingEnd,
    List<String>? transports,
    List<DraftPlace>? pendingStops,
    bool clearPendingEnd = false,
    bool clearDestinationPlace = false,
  }) {
    return TripDraft._(
      departure: departure ?? this.departure,
      stops: List.unmodifiable(stops ?? this.stops),
      destination: clearDestinationPlace
          ? null
          : (destination ?? this.destination),
      name: name ?? this.name,
      nameEdited: nameEdited ?? this.nameEdited,
      pendingEnd: clearPendingEnd ? null : (pendingEnd ?? this.pendingEnd),
      transports: transports ?? this.transports,
      pendingStops: List.unmodifiable(pendingStops ?? this.pendingStops),
    );
  }
}

/// La meta di [trip] come posto della bozza: la casa, il luogo della ricerca
/// o niente.
DraftPlace? _destinationOf(TripModel trip, String? houseName) {
  final houseId = trip.destinationHouseId;
  final loc = trip.destinationLocation;
  if (houseId != null) {
    return DraftPlace.house(
      id: houseId,
      name: houseName ?? loc?.displayName ?? trip.name,
    );
  }
  if (loc != null && loc.displayName.trim().isNotEmpty) {
    return DraftPlace.location(loc);
  }
  return null;
}

DateTime _dayOf(DateTime value) => DateTime(value.year, value.month, value.day);

DraftPlace _placeOfLeg(TripLeg leg) => leg.houseId != null
    ? DraftPlace.house(id: leg.houseId!, name: leg.locationDisplayName)
    : DraftPlace.location(
        LocationSuggestionModel(
          placeId: '',
          displayName: leg.locationDisplayName,
          lat: leg.lat,
          lon: leg.lon,
          country: leg.country,
        ),
      );
