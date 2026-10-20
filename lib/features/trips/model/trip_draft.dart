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
  });

  const TripDraft.empty() : this._();

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
    return _copy(
      departure: s,
      stops: [DraftStop(place: dest, end: e)],
      clearPendingEnd: true,
    );
  }

  /// Nome del campo. Vuoto o solo spazi: torna a seguire la meta.
  TripDraft withName(String text) =>
      _copy(name: text, nameEdited: text.trim().isNotEmpty);

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
    bool clearPendingEnd = false,
  }) {
    return TripDraft._(
      departure: departure ?? this.departure,
      stops: List.unmodifiable(stops ?? this.stops),
      destination: destination ?? this.destination,
      name: name ?? this.name,
      nameEdited: nameEdited ?? this.nameEdited,
      pendingEnd: clearPendingEnd ? null : (pendingEnd ?? this.pendingEnd),
    );
  }
}

DateTime _dayOf(DateTime value) => DateTime(value.year, value.month, value.day);
