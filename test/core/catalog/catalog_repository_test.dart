import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/catalog/catalog_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAssetBundle extends Mock implements AssetBundle {}

class MockCatalogSource extends Mock implements CatalogSource {}

/// Il file del repo (catalogo.json): voci con label {it, en}.
final _copiaNelRepo = jsonEncode({
  'entries': [
    {
      'domain': 'activity',
      'id': 'city',
      'sort': 10,
      'active': true,
      'label': {'it': 'Città e musei', 'en': 'Cities and museums'},
      'data': {'generator': ['visite in citta']},
    },
    {
      'domain': 'activity',
      'id': 'cycling',
      'sort': 90,
      'active': false,
      'label': {'it': 'Bicicletta', 'en': 'Cycling'},
      'data': {'generator': ['bicicletta']},
    },
  ],
});

/// Le righe della tabella catalog_entries: label_it e label_en.
final _righeTabella = [
  {
    'domain': 'activity',
    'id': 'city',
    'sort': 10,
    'active': true,
    'label_it': 'Città e musei',
    'label_en': 'Cities and museums',
    'data': {'generator': ['visite in citta']},
  },
  {
    'domain': 'activity',
    'id': 'evenings',
    'sort': 50,
    'active': true,
    'label_it': 'Cene e serate',
    'label_en': 'Dinners and evenings out',
    'data': {'generator': ['cene al ristorante', 'vita notturna']},
  },
  {
    'domain': 'activity',
    'id': 'cycling',
    'sort': 90,
    'active': false,
    'label_it': 'Bicicletta',
    'label_en': 'Cycling',
    'data': {'generator': ['bicicletta']},
  },
];

void main() {
  // rootBundle (l'asset vero) vuole il binding inizializzato.
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAssetBundle bundle;
  late MockCatalogSource source;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bundle = MockAssetBundle();
    source = MockCatalogSource();
    when(
      () => bundle.loadString(any(), cache: any(named: 'cache')),
    ).thenAnswer((_) async => _copiaNelRepo);
  });

  group('loadLocal', () {
    test('senza copia locale usa l\'asset del repo', () async {
      final repo = CatalogRepository(bundle: bundle);

      final catalogo = await repo.loadLocal();

      verify(() => bundle.loadString(kCatalogoAsset, cache: any(named: 'cache'))).called(1);
      expect(catalogo.version, 0);
      expect(catalogo.domain('activity').map((e) => e.id), ['city']);
      expect(catalogo.find('activity', 'city')!.label('it'), 'Città e musei');
    });

    test('con una copia locale usa quella, senza leggere l\'asset', () async {
      final copia = jsonEncode({
        'version': 4,
        'entries': [
          {
            'domain': 'activity',
            'id': 'evenings',
            'sort': 50,
            'active': true,
            'label': {'it': 'Cene e serate', 'en': 'Dinners and evenings out'},
            'data': {'generator': ['cene al ristorante']},
          },
        ],
      });
      SharedPreferences.setMockInitialValues({
        'catalog_json_cache': copia,
        'catalog_version_cache': 4,
      });
      final repo = CatalogRepository(bundle: bundle);

      final catalogo = await repo.loadLocal();

      expect(catalogo.version, 4);
      expect(catalogo.domain('activity').map((e) => e.id), ['evenings']);
      verifyNever(() => bundle.loadString(any(), cache: any(named: 'cache')));
    });

    test('l\'asset dichiarato nel pubspec si legge davvero (119 voci del catalogo)', () async {
      final catalogo = await CatalogRepository().loadLocal();

      expect(catalogo.entries.length, 119);
      expect(catalogo.find('activity', 'evenings')!.label('it'), 'Cene e serate');
    });

    test('una copia locale rotta cade sull\'asset', () async {
      SharedPreferences.setMockInitialValues({'catalog_json_cache': '{non json'});
      final repo = CatalogRepository(bundle: bundle);

      final catalogo = await repo.loadLocal();

      expect(catalogo.domain('activity').map((e) => e.id), ['city']);
    });
  });

  group('refresh', () {
    test('versione uguale: null e nessun download', () async {
      when(() => source.remoteVersion()).thenAnswer((_) async => 3);
      final repo = CatalogRepository(source: source, bundle: bundle);

      final nuovo = await repo.refresh(3);

      expect(nuovo, isNull);
      verifyNever(() => source.remoteEntries());
    });

    test('versione maggiore: scarica, salva e restituisce il catalogo nuovo', () async {
      when(() => source.remoteVersion()).thenAnswer((_) async => 4);
      when(() => source.remoteEntries()).thenAnswer((_) async => _righeTabella);
      final repo = CatalogRepository(source: source, bundle: bundle);

      final nuovo = await repo.refresh(3);

      expect(nuovo, isNotNull);
      expect(nuovo!.version, 4);
      expect(nuovo.domain('activity').map((e) => e.id), ['city', 'evenings']);
      expect(nuovo.find('activity', 'evenings')!.label('en'), 'Dinners and evenings out');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('catalog_version_cache'), 4);
      expect(prefs.getString('catalog_json_cache'), isNotNull);
      // La copia salvata si rilegge uguale.
      final riletto = await CatalogRepository(bundle: bundle).loadLocal();
      expect(riletto.version, 4);
      expect(riletto.entries.length, 3);
    });

    test('errore di rete: null, senza eccezioni', () async {
      when(() => source.remoteVersion()).thenThrow(Exception('rete assente'));
      final repo = CatalogRepository(source: source, bundle: bundle);

      expect(await repo.refresh(3), isNull);
    });

    test('senza fonte remota: null', () async {
      final repo = CatalogRepository(bundle: bundle);

      expect(await repo.refresh(0), isNull);
    });
  });

  group('refreshIfDue (una volta al giorno)', () {
    test('il primo controllo del giorno interroga il server, il secondo no', () async {
      when(() => source.remoteVersion()).thenAnswer((_) async => 1);
      var ora = DateTime(2026, 10, 31, 9);
      final repo = CatalogRepository(source: source, bundle: bundle, now: () => ora);

      await repo.refreshIfDue(localVersion: 1);
      ora = DateTime(2026, 10, 31, 18);
      await repo.refreshIfDue(localVersion: 1);

      verify(() => source.remoteVersion()).called(1);
    });

    test('il giorno dopo si controlla di nuovo', () async {
      when(() => source.remoteVersion()).thenAnswer((_) async => 1);
      var ora = DateTime(2026, 10, 31, 23);
      final repo = CatalogRepository(source: source, bundle: bundle, now: () => ora);

      await repo.refreshIfDue(localVersion: 1);
      ora = DateTime(2026, 11, 1, 8);
      await repo.refreshIfDue(localVersion: 1);

      verify(() => source.remoteVersion()).called(2);
    });

    test('un errore conta come controllo del giorno: niente nuovo tentativo a ogni avvio', () async {
      when(() => source.remoteVersion()).thenThrow(Exception('rete assente'));
      final repo = CatalogRepository(source: source, bundle: bundle, now: () => DateTime(2026, 10, 31, 9));

      await repo.refreshIfDue(localVersion: 1);
      await repo.refreshIfDue(localVersion: 1);

      verify(() => source.remoteVersion()).called(1);
    });
  });
}
