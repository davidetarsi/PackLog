import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/catalog/catalog.dart';
import 'package:pack_log/core/catalog/catalog_store.dart';

Catalog _catalogo({int version = 1}) => Catalog.fromJson({
  'entries': [
    {
      'domain': 'activity',
      'id': 'cycling',
      'sort': 90,
      'active': false,
      'label': {'it': 'Bicicletta', 'en': 'Cycling'},
      'data': {
        'generator': ['bicicletta'],
      },
    },
    {
      'domain': 'activity',
      'id': 'city',
      'sort': 10,
      'active': true,
      'label': {'it': 'Città e musei', 'en': 'Cities and museums'},
      'data': {
        'generator': ['visite in citta'],
      },
    },
    {
      'domain': 'activity',
      'id': 'evenings',
      'sort': 50,
      'active': true,
      'label': {'it': 'Cene e serate', 'en': 'Dinners and evenings out'},
      'data': {
        'generator': ['cene al ristorante', 'vita notturna'],
      },
    },
    {
      'domain': 'stay',
      'id': 'hotel',
      'sort': 10,
      'active': true,
      'label': {'it': 'Hotel', 'en': 'Hotel'},
      'data': {'generator': 'hotel'},
    },
  ],
}, version: version);

void main() {
  group('Catalog', () {
    test(
      'domain esclude le voci disattivate, con activeOnly false le include',
      () {
        final c = _catalogo();

        expect(c.domain('activity').map((e) => e.id), ['city', 'evenings']);
        expect(c.domain('activity', activeOnly: false).map((e) => e.id), [
          'city',
          'evenings',
          'cycling',
        ]);
      },
    );

    test('find trova anche una voce disattivata', () {
      final c = _catalogo();

      expect(c.find('activity', 'cycling')?.active, isFalse);
      expect(c.find('activity', 'non-esiste'), isNull);
      expect(c.find('stay', 'city'), isNull);
    });

    test('label: italiano per it, inglese per tutto il resto', () {
      final entry = _catalogo().find('activity', 'city')!;

      expect(entry.label('it'), 'Città e musei');
      expect(entry.label('en'), 'Cities and museums');
      expect(entry.label('fr'), 'Cities and museums');
    });

    test('le voci tornano in ordine di sort', () {
      final c = _catalogo();

      expect(c.entries.map((e) => e.sort), [10, 10, 50, 90]);
      expect(c.domain('activity', activeOnly: false).map((e) => e.sort), [
        10,
        50,
        90,
      ]);
    });

    test('data resta accessibile come mappa', () {
      final entry = _catalogo().find('activity', 'evenings')!;

      expect(entry.data['generator'], ['cene al ristorante', 'vita notturna']);
    });
  });

  group('CatalogStore', () {
    tearDown(() {
      CatalogStore.set(Catalog.vuoto);
      CatalogStore.languageCode = 'it';
    });

    test('set sostituisce il catalogo e alza la revisione', () {
      final prima = CatalogStore.revision.value;
      final nuovo = _catalogo(version: 7);

      CatalogStore.set(nuovo);

      expect(CatalogStore.current, same(nuovo));
      expect(CatalogStore.revision.value, prima + 1);
    });

    test('languageCode parte da it', () {
      expect(CatalogStore.languageCode, 'it');
    });

    test(
      'setLanguage cambia la lingua e alza la revisione, una volta sola',
      () {
        final prima = CatalogStore.revision.value;

        CatalogStore.setLanguage('en');
        CatalogStore.setLanguage('en');

        expect(CatalogStore.languageCode, 'en');
        expect(CatalogStore.revision.value, prima + 1);
      },
    );
  });
}
