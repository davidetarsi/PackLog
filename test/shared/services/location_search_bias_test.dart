import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';
import 'package:pack_log/shared/services/location_search_service.dart';

HouseModel _house(
  String id, {
  bool primary = false,
  double? lat,
  double? lon,
}) => HouseModel(
  id: id,
  name: id,
  isPrimary: primary,
  location: lat == null && lon == null
      ? null
      : LocationSuggestionModel(
          placeId: id,
          displayName: id,
          lat: lat,
          lon: lon,
        ),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _Houses extends HouseNotifier {
  _Houses(this.houses);
  final FutureOr<List<HouseModel>> houses;

  @override
  Future<List<HouseModel>> build() async => houses;

  void replace(List<HouseModel> houses) => state = AsyncData(houses);
}

void main() {
  test('preferisce la casa principale anche se non è la prima', () {
    expect(
      locationSearchBias([
        _house('mare', lat: 43.71, lon: 13.22),
        _house('principale', primary: true, lat: 44.49, lon: 11.34),
      ]),
      'proximity:11.34,44.49',
    );
  });

  test('senza coordinate della principale usa un’altra casa localizzata', () {
    expect(
      locationSearchBias([
        _house('principale', primary: true),
        _house('incompleta', lat: 45),
        _house('mare', lat: 43.71, lon: 13.22),
      ]),
      'proximity:13.22,43.71',
    );
  });

  test('senza principale usa la prima casa con coordinate valide', () {
    expect(
      locationSearchBias([
        _house('senza luogo'),
        _house('mare', lat: 43.71, lon: 13.22),
        _house('montagna', lat: 46.5, lon: 11.35),
      ]),
      'proximity:13.22,43.71',
    );
  });

  test('senza case o località usa Roma', () {
    expect(locationSearchBias([]), 'proximity:12.4964,41.9028');
    expect(
      locationSearchBias([_house('senza luogo')]),
      'proximity:12.4964,41.9028',
    );
  });

  test('scarta coordinate incomplete, non finite o fuori intervallo', () {
    for (final (lat, lon) in <(double?, double?)>[
      (null, 13),
      (43, null),
      (double.nan, 13),
      (43, double.infinity),
      (91, 13),
      (-91, 13),
      (43, 181),
      (43, -181),
    ]) {
      expect(
        locationSearchBias([
          _house('non valida', primary: true, lat: lat, lon: lon),
          _house('valida', lat: 0, lon: 0),
        ]),
        'proximity:0.0,0.0',
      );
    }
  });

  test(
    'il servizio segue modifiche delle case e torna a Roma dopo il wipe',
    () async {
      final container = ProviderContainer(
        overrides: [
          houseNotifierProvider.overrideWith(
            () => _Houses([
              _house('principale', primary: true, lat: 44.49, lon: 11.34),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(houseNotifierProvider.future);
      expect(
        container.read(locationSearchServiceProvider).bias,
        'proximity:11.34,44.49',
      );

      (container.read(houseNotifierProvider.notifier) as _Houses).replace([
        _house('principale', primary: true, lat: 43.71, lon: 13.22),
      ]);
      expect(
        container.read(locationSearchServiceProvider).bias,
        'proximity:13.22,43.71',
      );

      (container.read(houseNotifierProvider.notifier) as _Houses).replace([]);
      expect(
        container.read(locationSearchServiceProvider).bias,
        'proximity:12.4964,41.9028',
      );
    },
  );

  test('il caricamento delle case non blocca la ricerca: usa Roma', () {
    final pending = Completer<List<HouseModel>>();
    final container = ProviderContainer(
      overrides: [
        houseNotifierProvider.overrideWith(() => _Houses(pending.future)),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(locationSearchServiceProvider).bias,
      'proximity:12.4964,41.9028',
    );
    pending.complete([]);
  });

  test('un errore delle case non blocca la ricerca: usa Roma', () async {
    final container = ProviderContainer(
      overrides: [
        houseNotifierProvider.overrideWith(
          () => _Houses(Future.error(StateError('case non disponibili'))),
        ),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(houseNotifierProvider.future),
      throwsStateError,
    );
    expect(
      container.read(locationSearchServiceProvider).bias,
      'proximity:12.4964,41.9028',
    );
  });
}
