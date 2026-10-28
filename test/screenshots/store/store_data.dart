import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pack_log/features/ai_input/model/ai_import_state.dart';
import 'package:pack_log/features/ai_input/model/clothing_analysis_result.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/repositories/house_repository.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:pack_log/features/luggages/repositories/luggage_repository.dart';
import 'package:pack_log/features/spaces/model/space_model.dart';
import 'package:pack_log/features/spaces/repositories/space_repository.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/trip_leg.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/repositories/trip_repository.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';

/// Dati degli screenshot dello Store, in italiano o in inglese.
///
/// Sono separati da `seed.dart` perché devono sembrare l'armadio di una
/// persona vera, non coprire ogni caso della UI.
class StoreData {
  StoreData({required this.english});

  final bool english;

  String t(String it, String en) => english ? en : it;

  static const homeId = 'store-home';
  static const seaHouseId = 'store-sea';
  static const mountainHouseId = 'store-mountain';
  static const tripId = 'store-lisbon';
  static const weekendTripId = 'store-florence';

  static final _stamp = DateTime(2026, 9, 1);

  static DateTime _day(int offset) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: offset));
  }

  LocationSuggestionModel _place(
    String name,
    String country,
    double lat,
    double lon,
  ) => LocationSuggestionModel(
    placeId: 'place-$name',
    displayName: '$name, $country',
    name: name,
    city: name,
    country: country,
    lat: lat,
    lon: lon,
  );

  /// Oggetti di casa: indice = id (`store-item-<indice>`).
  late final List<(String, ItemCategory, int, String?)> _items = [
    (t('T-shirt bianca', 'White T-shirt'), ItemCategory.vestiti, 5, 'wardrobe'),
    (t('Jeans blu', 'Blue jeans'), ItemCategory.vestiti, 2, 'wardrobe'),
    (
      t('Maglione di lana', 'Wool sweater'),
      ItemCategory.vestiti,
      2,
      'wardrobe',
    ),
    (
      t('Giacca impermeabile', 'Rain jacket'),
      ItemCategory.vestiti,
      1,
      'wardrobe',
    ),
    (t('Calzini', 'Socks'), ItemCategory.vestiti, 8, 'drawers'),
    (
      t('Camicia di lino azzurra', 'Light blue linen shirt'),
      ItemCategory.vestiti,
      2,
      'wardrobe',
    ),
    (t('Sneakers bianche', 'White sneakers'), ItemCategory.vestiti, 1, null),
    (t('Felpa grigia', 'Grey hoodie'), ItemCategory.vestiti, 1, 'wardrobe'),
    (t('Pantaloni chino', 'Chinos'), ItemCategory.vestiti, 1, 'wardrobe'),
    (t('Blazer blu', 'Navy blazer'), ItemCategory.vestiti, 1, 'wardrobe'),
    (t('Costume da bagno', 'Swimsuit'), ItemCategory.vestiti, 2, 'drawers'),
    (t('Spazzolino', 'Toothbrush'), ItemCategory.toiletries, 1, 'bathroom'),
    (t('Dentifricio', 'Toothpaste'), ItemCategory.toiletries, 1, 'bathroom'),
    (
      t('Crema solare SPF 50', 'Sunscreen SPF 50'),
      ItemCategory.toiletries,
      1,
      'bathroom',
    ),
    (
      t('Caricatore telefono', 'Phone charger'),
      ItemCategory.elettronica,
      2,
      null,
    ),
    ('Power bank', ItemCategory.elettronica, 1, null),
    (t('Passaporto', 'Passport'), ItemCategory.varie, 1, null),
    (t('Occhiali da sole', 'Sunglasses'), ItemCategory.varie, 1, null),
  ];

  String itemName(int index) => _items[index].$1;

  Future<void> seed(ProviderContainer c) async {
    final houses = c.read(houseRepositoryProvider);
    final spaces = c.read(spaceRepositoryProvider);
    final items = c.read(itemRepositoryProvider);
    final luggages = c.read(luggageRepositoryProvider);
    final trips = c.read(tripRepositoryProvider);
    final italy = t('Italia', 'Italy');

    await houses.addHouse(
      HouseModel(
        id: homeId,
        name: t('Casa', 'Home'),
        location: _place(t('Milano', 'Milan'), italy, 45.4642, 9.19),
        iconName: 'apartment',
        isPrimary: true,
        createdAt: _stamp,
        updatedAt: _stamp,
      ),
    );
    await houses.addHouse(
      HouseModel(
        id: seaHouseId,
        name: t('Casa al mare', 'Beach house'),
        location: _place('Riccione', italy, 43.9998, 12.6559),
        iconName: 'sailing',
        createdAt: _stamp,
        updatedAt: _stamp,
      ),
    );
    await houses.addHouse(
      HouseModel(
        id: mountainHouseId,
        name: t('Baita in montagna', 'Mountain cabin'),
        location: _place('Courmayeur', italy, 45.7969, 6.9690),
        iconName: 'landscape',
        createdAt: _stamp,
        updatedAt: _stamp,
      ),
    );

    final spaceDefs = {
      'wardrobe': (t('Armadio', 'Wardrobe'), 'door_sliding'),
      'drawers': (t('Cassettiera', 'Chest of drawers'), 'storage'),
      'bathroom': (t('Bagno', 'Bathroom'), 'bathroom'),
    };
    for (final e in spaceDefs.entries) {
      await spaces.addSpace(
        SpaceModel(
          id: e.key,
          houseId: homeId,
          name: e.value.$1,
          iconName: e.value.$2,
          createdAt: _stamp,
          updatedAt: _stamp,
        ),
      );
    }

    await items.insertMultipleItems([
      for (final (i, (name, cat, qty, space)) in _items.indexed)
        ItemModel(
          id: 'store-item-$i',
          houseId: homeId,
          name: name,
          category: cat,
          quantity: qty,
          spaceId: space,
          createdAt: _stamp,
          updatedAt: _stamp,
        ),
    ]);

    final cabin = LuggageModel(
      id: 'store-cabin',
      houseId: homeId,
      name: t('Trolley cabina', 'Carry-on'),
      sizeType: LuggageSize.cabinBaggage,
      volumeLiters: 40,
      createdAt: _stamp,
      updatedAt: _stamp,
    );
    final backpack = LuggageModel(
      id: 'store-backpack',
      houseId: homeId,
      name: t('Zaino', 'Backpack'),
      sizeType: LuggageSize.smallBackpack,
      volumeLiters: 20,
      createdAt: _stamp,
      updatedAt: _stamp,
    );
    for (final l in [cabin, backpack]) {
      await luggages.addLuggage(l);
    }

    final portugal = t('Portogallo', 'Portugal');
    final trip = TripModel(
      id: tripId,
      name: t('Lisbona e Sintra', 'Lisbon and Sintra'),
      departureDateTime: _day(10),
      returnDateTime: _day(15),
      destinationLocation: _place(
        t('Lisbona', 'Lisbon'),
        portugal,
        38.7223,
        -9.1393,
      ),
      items: [
        for (final (index, qty, _, _, _) in _proposal)
          TripItem(
            id: 'store-item-$index',
            name: itemName(index),
            category: _items[index].$2,
            quantity: qty,
            originHouseId: homeId,
            isChecked: _packedAlready.contains(index),
          ),
      ],
      luggages: [cabin],
      legs: [
        TripLeg(
          id: 'store-leg-sintra',
          locationDisplayName: 'Sintra, $portugal',
          from: _day(13),
          to: _day(15),
          lat: 38.7980,
          lon: -9.3900,
          country: portugal,
        ),
      ],
      aiSetup: const AiPackingSetup(houseId: homeId, luggageId: 'store-cabin'),
      aiResult: _aiResult(),
      createdAt: _stamp,
      updatedAt: _stamp,
    );
    await trips.addTrip(trip);

    await trips.addTrip(
      TripModel(
        id: weekendTripId,
        name: t('Weekend a Firenze', 'Weekend in Florence'),
        departureDateTime: _day(24),
        returnDateTime: _day(26),
        destinationLocation: _place(
          t('Firenze', 'Florence'),
          italy,
          43.7696,
          11.2558,
        ),
        luggages: [backpack],
        createdAt: _stamp,
        updatedAt: _stamp,
      ),
    );
  }

  /// Oggetti già spuntati nella checklist.
  static const _packedAlready = {0, 1, 4, 11, 12};

  /// (indice oggetto, pezzi, da indossare in partenza, codice, motivo)
  late final List<(int, int, bool, String, String)> _proposal = [
    (
      0,
      3,
      false,
      'clima',
      t(
        'Di giorno si sta sui 20 gradi: tre magliette bastano.',
        'Around 20 degrees during the day: three T-shirts are enough.',
      ),
    ),
    (
      1,
      1,
      false,
      'citta',
      t(
        'Per camminare in città, un paio basta.',
        'One pair is enough for walking around the city.',
      ),
    ),
    (
      2,
      1,
      false,
      'clima',
      t('Le sere a Sintra sono fresche.', 'Evenings in Sintra are cool.'),
    ),
    (
      3,
      1,
      true,
      'pioggia',
      t(
        'Pioggia prevista a Sintra: la indossi in partenza.',
        'Rain is expected in Sintra: wear it when you leave.',
      ),
    ),
    (4, 6, false, 'citta', t('Un paio al giorno.', 'One pair a day.')),
    (
      5,
      1,
      false,
      'clima',
      t('Fresca per le giornate di sole.', 'Light and cool for sunny days.'),
    ),
    (
      6,
      1,
      true,
      'citta',
      t('Comode per le salite di Lisbona.', 'Comfortable on Lisbon\'s hills.'),
    ),
    (
      9,
      1,
      false,
      'cena',
      t(
        'Per la cena in un ristorante elegante.',
        'For dinner at a nice restaurant.',
      ),
    ),
    (
      11,
      1,
      false,
      'igiene',
      t('Essenziale ogni giorno.', 'Everyday essential.'),
    ),
    (
      12,
      1,
      false,
      'igiene',
      t('Essenziale ogni giorno.', 'Everyday essential.'),
    ),
    (
      13,
      1,
      false,
      'sole',
      t(
        'Il sole di Lisbona è forte anche in autunno.',
        'The sun in Lisbon is strong even in autumn.',
      ),
    ),
  ];

  String _label(String code) => switch (code) {
    'clima' => t('Clima', 'Weather'),
    'citta' => t('Città', 'City'),
    'pioggia' => t('Pioggia', 'Rain'),
    'cena' => t('Cena', 'Dinner'),
    'igiene' => t('Igiene', 'Hygiene'),
    _ => t('Sole', 'Sun'),
  };

  AiPackingResult _aiResult() => AiPackingResult(
    generatedAt: DateTime(2026, 10, 20, 18, 30),
    houseId: homeId,
    proposal: [
      for (final (index, qty, departure, code, sentence) in _proposal)
        AiPackedItem(
          itemId: 'store-item-$index',
          quantity: qty,
          inDeparture: departure,
          reason: AiReason(code: code, label: _label(code), sentence: sentence),
        ),
    ],
    warnings: [
      AiWarning(
        id: 'store-warn-umbrella',
        code: 'mancanti_canonici',
        level: AiWarningLevel.useful,
        title: t(
          'Un ombrello per la pioggia di Sintra',
          'An umbrella for the rain in Sintra',
        ),
        why: t(
          'Qui piove un giorno su due: la giacca copre il busto, '
              "l'ombrello anche le gambe.",
          'It rains every other day here: the jacket covers your top, '
              'an umbrella keeps your legs dry too.',
        ),
      ),
    ],
    reasons: [
      AiReasonPoint(
        code: 'clima',
        title: t(
          'Il clima di Lisbona e Sintra',
          'Weather in Lisbon and Sintra',
        ),
        sentences: [
          t(
            'Di giorno si sta sui 20 gradi, la sera si rinfresca.',
            'Around 20 degrees during the day, cooler in the evening.',
          ),
        ],
        items: [itemName(2), itemName(3)],
      ),
      AiReasonPoint(
        code: 'citta',
        title: t('Città a piedi', 'Exploring on foot'),
        sentences: [
          t(
            'Molte ore in piedi: scarpe comode e calzini di ricambio.',
            'Lots of walking: comfortable shoes and spare socks.',
          ),
        ],
        items: [itemName(6), itemName(4)],
      ),
    ],
  );

  /// Un capo come lo scrive il server; il colore base è in italiano.
  ClothingAnalysisResult _garment(
    String name,
    String color,
    String sub, {
    String category = 'Upper Body',
    String coverage = 'Long',
    int warmth = 2,
    int waterResistance = 0,
    List<String> doubts = const [],
  }) => ClothingAnalysisResult(
    name: name,
    category: category,
    subCategory: sub,
    baseColor: color,
    pattern: 'Solid',
    coverage: coverage,
    fit: 'Regular',
    warmth: warmth,
    formality: 'Casual',
    activityTags: const ['Everyday'],
    extras: {'waterResistance': waterResistance},
    doubts: doubts,
  );

  /// Risultati della scansione di due foto.
  AiImportState scanResults({required File first, required File second}) =>
      AiImportState(
        selectedHouseId: homeId,
        photoGroups: [
          PhotoGroup(
            photo: first,
            results: [
              _garment(
                t('Camicia di jeans', 'Denim shirt'),
                'Blu',
                'Shirt',
                warmth: 2,
              ),
              _garment(
                t('Pantaloni chino beige', 'Beige chinos'),
                'Beige',
                'Trousers',
                category: 'Lower Body',
              ),
            ],
          ),
          PhotoGroup(
            photo: second,
            results: [
              _garment(
                t('Giacca a vento verde', 'Green windbreaker'),
                'Verde',
                'Jacket',
                warmth: 3,
                waterResistance: 2,
                doubts: const ['waterResistance'],
              ),
              _garment(
                t('Maglione a coste', 'Ribbed sweater'),
                'Bianco',
                'Sweater',
                warmth: 4,
              ),
            ],
          ),
        ],
      );
}
