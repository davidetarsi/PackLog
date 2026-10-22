import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:pack_log/features/luggages/repositories/luggage_repository.dart';
import 'package:pack_log/features/spaces/model/space_model.dart';
import 'package:pack_log/features/spaces/repositories/space_repository.dart';
import 'package:pack_log/features/trips/model/trip_leg.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';

/// Id stabili, usati dagli scenari per navigare (`/houses/$kHomeId`...).
const kHomeId = 'house-milano';
const kSeaHouseId = 'house-mare';
const kMountainHouseId = 'house-baita';
const kEmptyHouseId = 'house-vuota';

const kActiveTripId = 'trip-mare';
const kUpcomingTripId = 'trip-lisbona';
const kSavedTripId = 'trip-matrimonio';
const kPastTripId = 'trip-barcellona';
const kEmptyTripId = 'trip-vuoto';

/// Quanto popolare il database.
enum SeedLevel {
  /// Nessuna casa, nessun viaggio: primo avvio dopo il login.
  empty,

  /// Utente attivo: tre case, spazi, bagagli, oggetti, viaggi in ogni stato.
  full,
}

DateTime _day(int offset) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).add(Duration(days: offset));
}

/// Coordinate dei luoghi del seed: servono al meteo della pagina valigia.
const _coords = {
  'Milano': (45.4642, 9.19),
  'Riccione': (43.9998, 12.6559),
  'Courmayeur': (45.7969, 6.9690),
  'Lisbona': (38.7223, -9.1393),
  'Sintra': (38.7980, -9.3900),
  'Firenze': (43.7696, 11.2558),
  'Barcellona': (41.3874, 2.1686),
};

LocationSuggestionModel _place(String name, {String? country}) =>
    LocationSuggestionModel(
      placeId: 'place-$name',
      displayName: country == null ? name : '$name, $country',
      name: name,
      city: name,
      country: country,
      lat: _coords[name]?.$1,
      lon: _coords[name]?.$2,
    );

/// Popola il DB passando dai repository veri, così le righe hanno esattamente
/// la forma che l'app scrive in produzione (userId, syncStatus, relazioni).
Future<void> seed(ProviderContainer c, SeedLevel level) async {
  if (level == SeedLevel.empty) return;

  final stamp = DateTime(2026, 9, 1);
  final houses = c.read(houseRepositoryProvider);
  final spaces = c.read(spaceRepositoryProvider);
  final items = c.read(itemRepositoryProvider);
  final luggages = c.read(luggageRepositoryProvider);
  final trips = c.read(tripRepositoryProvider);

  // ── Case ────────────────────────────────────────────────────────────────
  await houses.addHouse(
    HouseModel(
      id: kHomeId,
      name: 'Casa Milano',
      location: _place('Milano', country: 'Italia'),
      iconName: 'apartment',
      isPrimary: true,
      createdAt: stamp,
      updatedAt: stamp,
    ),
  );
  await houses.addHouse(
    HouseModel(
      id: kSeaHouseId,
      name: 'Casa al mare',
      location: _place('Riccione', country: 'Italia'),
      iconName: 'sailing',
      createdAt: stamp,
      updatedAt: stamp,
    ),
  );
  await houses.addHouse(
    HouseModel(
      id: kMountainHouseId,
      name: 'Baita dei nonni a Courmayeur, Valle d\'Aosta',
      location: _place('Courmayeur', country: 'Italia'),
      iconName: 'landscape',
      createdAt: stamp,
      updatedAt: stamp,
    ),
  );
  await houses.addHouse(
    HouseModel(
      id: kEmptyHouseId,
      name: 'Monolocale Torino',
      createdAt: stamp,
      updatedAt: stamp,
    ),
  );

  // ── Spazi ───────────────────────────────────────────────────────────────
  final spaceDefs = {
    'space-armadio': ('Armadio camera', 'door_sliding'),
    'space-cassettiera': ('Cassettiera', 'storage'),
    'space-bagno': ('Bagno', 'bathroom'),
  };
  for (final e in spaceDefs.entries) {
    await spaces.addSpace(
      SpaceModel(
        id: e.key,
        houseId: kHomeId,
        name: e.value.$1,
        iconName: e.value.$2,
        createdAt: stamp,
        updatedAt: stamp,
      ),
    );
  }

  // ── Oggetti ─────────────────────────────────────────────────────────────
  final itemDefs = <(String, ItemCategory, int, String?)>[
    ('T-shirt bianca', ItemCategory.vestiti, 5, 'space-armadio'),
    ('Jeans blu', ItemCategory.vestiti, 2, 'space-armadio'),
    ('Maglione di lana', ItemCategory.vestiti, 1, 'space-armadio'),
    ('Giacca impermeabile', ItemCategory.vestiti, 1, 'space-armadio'),
    ('Calzini', ItemCategory.vestiti, 7, 'space-cassettiera'),
    ('Costume da bagno', ItemCategory.vestiti, 2, 'space-cassettiera'),
    (
      'Camicia di lino a maniche lunghe azzurra per le cene eleganti',
      ItemCategory.vestiti,
      1,
      'space-armadio',
    ),
    ('Spazzolino', ItemCategory.toiletries, 1, 'space-bagno'),
    ('Dentifricio', ItemCategory.toiletries, 1, 'space-bagno'),
    ('Shampoo', ItemCategory.toiletries, 1, 'space-bagno'),
    ('Crema solare SPF 50', ItemCategory.toiletries, 1, null),
    ('Caricatore telefono', ItemCategory.elettronica, 2, null),
    ('Power bank', ItemCategory.elettronica, 1, null),
    ('Cuffie', ItemCategory.elettronica, 1, null),
    ('Adattatore presa UK', ItemCategory.elettronica, 1, null),
    ('Passaporto', ItemCategory.varie, 1, null),
    ('Occhiali da sole', ItemCategory.varie, 1, null),
    ('Borraccia', ItemCategory.varie, 1, null),
  ];
  final homeItems = <ItemModel>[];
  for (var i = 0; i < itemDefs.length; i++) {
    final (name, cat, qty, space) = itemDefs[i];
    homeItems.add(
      ItemModel(
        id: 'item-$i',
        houseId: kHomeId,
        name: name,
        category: cat,
        quantity: qty,
        spaceId: space,
        createdAt: stamp,
        updatedAt: stamp,
      ),
    );
  }
  await items.insertMultipleItems(homeItems);

  await items.insertMultipleItems([
    for (final (i, (name, cat)) in [
      ('Telo mare', ItemCategory.varie),
      ('Infradito', ItemCategory.vestiti),
      ('Doposole', ItemCategory.toiletries),
    ].indexed)
      ItemModel(
        id: 'sea-item-$i',
        houseId: kSeaHouseId,
        name: name,
        category: cat,
        quantity: 1,
        createdAt: stamp,
        updatedAt: stamp,
      ),
  ]);

  await items.insertMultipleItems([
    for (final (i, (name, cat)) in [
      ('Scarponi da sci', ItemCategory.vestiti),
      ('Tuta da sci', ItemCategory.vestiti),
      ('Guanti termici', ItemCategory.vestiti),
    ].indexed)
      ItemModel(
        id: 'mountain-item-$i',
        houseId: kMountainHouseId,
        name: name,
        category: cat,
        quantity: 1,
        createdAt: stamp,
        updatedAt: stamp,
      ),
  ]);

  // ── Bagagli ─────────────────────────────────────────────────────────────
  final cabin = LuggageModel(
    id: 'lug-cabina',
    houseId: kHomeId,
    name: 'Trolley cabina',
    sizeType: LuggageSize.cabinBaggage,
    volumeLiters: 40,
    createdAt: stamp,
    updatedAt: stamp,
  );
  final backpack = LuggageModel(
    id: 'lug-zaino',
    houseId: kHomeId,
    name: 'Zaino',
    sizeType: LuggageSize.smallBackpack,
    volumeLiters: 20,
    createdAt: stamp,
    updatedAt: stamp,
  );
  final hold = LuggageModel(
    id: 'lug-stiva',
    houseId: kHomeId,
    name: 'Valigia grande',
    sizeType: LuggageSize.holdBaggage,
    volumeLiters: 90,
    createdAt: stamp,
    updatedAt: stamp,
  );
  for (final l in [cabin, backpack, hold]) {
    await luggages.addLuggage(l);
  }

  // ── Viaggi ──────────────────────────────────────────────────────────────
  TripItem fromHome(int index, {bool checked = false}) {
    final item = homeItems[index];
    return TripItem(
      id: item.id,
      name: item.name,
      category: item.category,
      quantity: item.quantity ?? 1,
      originHouseId: kHomeId,
      isChecked: checked,
    );
  }

  await trips.addTrip(
    TripModel(
      id: kActiveTripId,
      name: 'Weekend al mare',
      departureDateTime: _day(-1),
      returnDateTime: _day(2),
      destinationHouseId: kSeaHouseId,
      items: [
        fromHome(0, checked: true),
        fromHome(5, checked: true),
        fromHome(10, checked: true),
        fromHome(16),
      ],
      luggages: [backpack],
      createdAt: stamp,
      updatedAt: stamp,
    ),
  );

  await trips.addTrip(
    TripModel(
      id: kUpcomingTripId,
      name: 'Lisbona',
      description: 'Ponte di ottobre con Marta',
      departureDateTime: _day(10),
      returnDateTime: _day(15),
      destinationLocation: _place('Lisbona', country: 'Portogallo'),
      items: [
        fromHome(0, checked: true),
        fromHome(1, checked: true),
        fromHome(3),
        fromHome(4),
        fromHome(6),
        fromHome(7, checked: true),
        fromHome(8),
        fromHome(11),
        fromHome(12),
        fromHome(15, checked: true),
        fromHome(16),
      ],
      luggages: [cabin, backpack],
      legs: [
        TripLeg(
          id: 'leg-sintra',
          locationDisplayName: 'Sintra, Portogallo',
          from: _day(13),
          to: _day(15),
          lat: _coords['Sintra']!.$1,
          lon: _coords['Sintra']!.$2,
          country: 'Portogallo',
        ),
      ],
      createdAt: stamp,
      updatedAt: stamp,
    ),
  );

  await trips.addTrip(
    TripModel(
      id: kSavedTripId,
      name: 'Matrimonio Giulia',
      departureDateTime: _day(40),
      returnDateTime: _day(42),
      destinationLocation: _place('Firenze', country: 'Italia'),
      items: [fromHome(6), fromHome(1)],
      luggages: [cabin],
      isSaved: true,
      createdAt: stamp,
      updatedAt: stamp,
    ),
  );

  await trips.addTrip(
    TripModel(
      id: kEmptyTripId,
      name: 'Weekend a Torino',
      departureDateTime: _day(25),
      returnDateTime: _day(27),
      destinationHouseId: kEmptyHouseId,
      createdAt: stamp,
      updatedAt: stamp,
    ),
  );

  await trips.addTrip(
    TripModel(
      id: kPastTripId,
      name: 'Barcellona',
      departureDateTime: _day(-60),
      returnDateTime: _day(-55),
      destinationLocation: _place('Barcellona', country: 'Spagna'),
      items: [
        fromHome(0, checked: true),
        fromHome(1, checked: true),
        fromHome(5, checked: true),
      ],
      luggages: [cabin],
      createdAt: stamp,
      updatedAt: stamp,
    ),
  );

  await trips.addTrip(
    TripModel(
      id: 'trip-sci',
      name: 'Settimana bianca',
      departureDateTime: _day(-240),
      returnDateTime: _day(-233),
      destinationHouseId: kMountainHouseId,
      items: [fromHome(2, checked: true), fromHome(3, checked: true)],
      luggages: [hold],
      createdAt: stamp,
      updatedAt: stamp,
    ),
  );
}
