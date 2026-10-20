import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/trips/model/trip_draft.dart';
import 'package:pack_log/features/trips/view/widgets/place_search.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';
import 'package:pack_log/shared/model/location_type.dart';
import 'package:pack_log/shared/services/location_search_service.dart';

class _MockLocationSearchService extends Mock
    implements LocationSearchService {}

/// Notifier delle case con una lista fissa: niente repository né sync.
class _FakeHouseNotifier extends HouseNotifier {
  _FakeHouseNotifier(this._houses);

  final List<HouseModel> _houses;

  @override
  Future<List<HouseModel>> build() async => _houses;
}

final _houses = [
  HouseModel(
    id: 'h1',
    name: 'Casa Milano',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  HouseModel(
    id: 'h2',
    name: 'Casa al mare',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  HouseModel(
    id: 'h3',
    name: 'Baita dei nonni',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
];

final _places = [
  LocationSuggestionModel(
    placeId: 'p1',
    displayName: 'Marsiglia, Francia',
    name: 'Marsiglia',
    city: 'Marsiglia',
    country: 'Francia',
    locationType: LocationType.city,
  ),
];

Finder _houseRow(String id) => find.byKey(Key('place_search_house_$id'));
Finder _placeRow(int index) => find.byKey(Key('place_search_location_$index'));

void main() {
  late _MockLocationSearchService service;

  setUp(() {
    service = _MockLocationSearchService();
    when(
      () => service.search(any(), lang: any(named: 'lang')),
    ).thenAnswer((_) async => _places);
  });

  Future<void> pumpSearch(
    WidgetTester tester, {
    required ValueChanged<DraftPlace> onSelected,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          houseNotifierProvider.overrideWith(() => _FakeHouseNotifier(_houses)),
          locationSearchServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: PlaceSearch(onSelected: onSelected),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('al tocco compaiono tutte le case, senza cercare luoghi', (
    tester,
  ) async {
    await pumpSearch(tester, onSelected: (_) {});

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(_houseRow('h1'), findsOneWidget);
    expect(_houseRow('h2'), findsOneWidget);
    expect(_houseRow('h3'), findsOneWidget);
    verifyNever(() => service.search(any(), lang: any(named: 'lang')));
  });

  testWidgets(
    'scrivendo filtra le case per nome e dopo 300 ms mostra i luoghi',
    (tester) async {
      await pumpSearch(tester, onSelected: (_) {});

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'MAR');
      await tester.pump();

      expect(_houseRow('h2'), findsOneWidget);
      expect(_houseRow('h1'), findsNothing);
      expect(_houseRow('h3'), findsNothing);
      expect(_placeRow(0), findsNothing);
      verifyNever(() => service.search(any(), lang: any(named: 'lang')));

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(_placeRow(0), findsOneWidget);
      verify(() => service.search('MAR', lang: 'en')).called(1);
    },
  );

  testWidgets('tocco su una casa chiama onSelected con DraftPlace.house', (
    tester,
  ) async {
    DraftPlace? captured;
    await pumpSearch(tester, onSelected: (place) => captured = place);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(_houseRow('h2'));
    await tester.pump();

    expect(captured, isNotNull);
    expect(captured!.houseId, 'h2');
    expect(captured!.name, 'Casa al mare');
    expect(captured!.location, isNull);
    // A scelta fatta la lista si chiude.
    expect(_houseRow('h1'), findsNothing);
  });

  testWidgets('tocco su un luogo chiama onSelected con DraftPlace.location', (
    tester,
  ) async {
    DraftPlace? captured;
    await pumpSearch(tester, onSelected: (place) => captured = place);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'mar');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    await tester.tap(_placeRow(0));
    await tester.pump();

    expect(captured, isNotNull);
    expect(captured!.houseId, isNull);
    expect(captured!.location, _places.first);
    expect(_placeRow(0), findsNothing);
  });
}
