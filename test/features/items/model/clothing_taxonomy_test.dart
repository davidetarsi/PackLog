// Tassonomia dei capi dal catalogo (31 ottobre 2026): gruppi, tipi, stile, usi e
// colori vengono da CatalogStore. Il test di coerenza legge il file che è anche
// l'asset dell'app.
//
// PARITÀ CON IL 31 OTTOBRE: il gruppo "valori del catalogo del repo, come prima"
// fissa il CONTENUTO. Le costanti _oggi... sono la copia dei valori di prima del
// catalogo, e falliscono apposta quando il catalogo cambia (voce nuova,
// disattivata o rinominata). Dopo un export (esporta_catalogo.mjs) si aggiornano
// le costanti nello stesso commit, insieme ai valori scritti in
// supabase/functions/_shared/catalogo/test/catalogo_parita.test.ts. Gli altri
// test (forma, coerenza) non vanno toccati.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/catalog/catalog.dart';
import 'package:pack_log/core/catalog/catalog_choices.dart';
import 'package:pack_log/core/catalog/catalog_store.dart';
import 'package:pack_log/features/items/model/clothing_taxonomy.dart';

import '../../../helpers/catalogo_di_prova.dart';

// I valori di prima del catalogo (copiati da HEAD, prima di questo cambio).
const List<String> _oggiCategorie = [
  'Upper Body',
  'Lower Body',
  'Full Body',
  'Shoes',
  'Outerwear',
  'Accessory',
  'Essentials',
];

const Map<String, List<String>> _oggiTipi = {
  'Upper Body': [
    'T-Shirt',
    'Shirt',
    'Polo',
    'Hoodie',
    'Sweatshirt',
    'Sweater',
    'Tank Top',
    'Crop Top',
    'Thermal Top',
    'Fleece',
    kClothingOther,
  ],
  'Lower Body': [
    'Jeans',
    'Shorts',
    'Trousers',
    'Leggings',
    'Skirt',
    'Sweatpants',
    'Swimwear',
    'Thermal Bottoms',
    'Ski Pants',
    'Wetsuit',
    kClothingOther,
  ],
  'Full Body': ['Dress', kClothingOther],
  'Shoes': [
    'Sneakers',
    'Sandals',
    'Boots',
    'Flip-Flops',
    'Loafers',
    'Dress Shoes',
    'Hiking Boots',
    'Water Shoes',
    'Snow Boots',
    kClothingOther,
  ],
  'Outerwear': [
    'Coat',
    'Rain Jacket',
    'Down Jacket',
    'Windbreaker',
    'Blazer',
    'Ski Jacket',
    'Ski Suit',
    'Casual Jacket',
    'Vest',
    kClothingOther,
  ],
  'Accessory': [
    'Cap/Hat',
    'Belt',
    'Bag',
    'Scarf',
    'Sunglasses',
    'Jewelry',
    'Watch',
    'Gloves',
    'Tie',
    'Umbrella',
    kClothingOther,
  ],
  'Essentials': ['Underwear', 'Socks', 'Pajamas', kClothingOther],
};

const List<String> _oggiFormalita = [
  'Loungewear',
  'Casual',
  'Smart Casual',
  'Business',
  'Formal',
];

const List<String> _oggiUsi = [
  'Everyday',
  'Office',
  'Beach',
  'Swimming',
  'Hiking',
  'Sport',
  'Formal',
  'Lounge',
];

const List<String> _oggiColori = [
  'Bianco',
  'Nero',
  'Grigio',
  'Blu',
  'Marrone',
  'Beige',
  'Blu navy',
  'Azzurro',
  'Verde',
  'Rosso',
  'Bordeaux',
  'Rosa',
  'Giallo',
  'Arancione',
  'Viola',
  'Multicolore',
];

const Map<String, String> _oggiSinonimi = {
  'celeste': 'Azzurro',
  'blu scuro': 'Blu navy',
  'blu notte': 'Blu navy',
  'navy': 'Blu navy',
  'crema': 'Beige',
  'panna': 'Bianco',
  'avorio': 'Bianco',
  'cammello': 'Beige',
  'kaki': 'Beige',
  'cachi': 'Beige',
  'tortora': 'Beige',
  'antracite': 'Grigio',
  'fucsia': 'Rosa',
  'lilla': 'Viola',
  'porpora': 'Viola',
  'bordò': 'Bordeaux',
  'denim': 'Blu',
  'multicolor': 'Multicolore',
  'fantasia': 'Multicolore',
  'white': 'Bianco',
  'black': 'Nero',
  'grey': 'Grigio',
  'gray': 'Grigio',
  'brown': 'Marrone',
  'blue': 'Blu',
  'navy blue': 'Blu navy',
  'light blue': 'Azzurro',
  'green': 'Verde',
  'red': 'Rosso',
  'burgundy': 'Bordeaux',
  'pink': 'Rosa',
  'yellow': 'Giallo',
  'orange': 'Arancione',
  'purple': 'Viola',
  'multicolour': 'Multicolore',
  'multicolored': 'Multicolore',
  'multicoloured': 'Multicolore',
};

void main() {
  setUp(() => caricaCatalogoDelRepo());
  tearDown(() => CatalogStore.set(Catalog.vuoto));

  group('valori del catalogo del repo, come prima', () {
    test('categorie nello stesso ordine', () {
      expect(clothingCategories(), _oggiCategorie);
    });

    test('tipi per categoria, con Other in fondo', () {
      expect(clothingTypes(), _oggiTipi);
      expect(clothingTypes(activeOnly: false), _oggiTipi);
    });

    test('stile, usi e colori di base', () {
      expect(formalities(), _oggiFormalita);
      expect(activityTags(), _oggiUsi);
      expect(baseColors(), _oggiColori);
    });

    test('sinonimi dei colori', () {
      expect(colorSynonyms(), _oggiSinonimi);
    });

    test('livelli di calore e impermeabilità restano costanti', () {
      expect(kWarmthLevels, [1, 2, 3, 4, 5]);
      expect(kWaterResistanceLevels, [0, 1, 2]);
    });

    test('la copia dell\'asset è il file del repo (pubspec)', () {
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('supabase/functions/_shared/catalogo/catalogo.json'),
      );
    });
  });

  group('la categoria', () {
    test('ricava la categoria dalla sottocategoria', () {
      expect(clothingCategoryOf('Fleece'), 'Upper Body');
      expect(clothingCategoryOf('Dress'), 'Full Body');
      expect(clothingCategoryOf('Cap/Hat'), 'Accessory');
    });

    test('null per Other e per le sconosciute', () {
      expect(clothingCategoryOf('Other'), isNull);
      expect(clothingCategoryOf('Boh'), isNull);
    });
  });

  group('paletteColor', () {
    test('uguale, sinonimo o colore con una sfumatura', () {
      expect(paletteColor('  blu   NAVY '), 'Blu navy');
      expect(paletteColor('Celeste'), 'Azzurro');
      expect(paletteColor('black'), 'Nero');
      expect(paletteColor('Verde oliva'), 'Verde');
      expect(paletteColor('grigio chiaro'), 'Grigio');
      expect(paletteColor('dark blue'), 'Blu');
    });

    test('un colore qualsiasi resta fuori', () {
      expect(paletteColor('Verde salvia'), isNull);
      expect(paletteColor('Oro'), isNull);
      expect(paletteColor(''), isNull);
      expect(paletteColor('scuro'), isNull);
    });
  });

  group('con un catalogo cambiato', () {
    Catalog cambia(void Function(List<Map<String, dynamic>> voci) modifica) {
      final json = catalogoDelRepo().toJson();
      final voci = (json['entries'] as List).cast<Map<String, dynamic>>();
      modifica(voci);
      return Catalog.fromJson(json);
    }

    test(
      'una voce nuova entra nei tipi, nel gruppo giusto, prima di Other',
      () {
        CatalogStore.set(
          cambia(
            (voci) => voci.add({
              'domain': 'clothing_type',
              'id': 'Gilet imbottito',
              'sort': 5000,
              'active': true,
              'label': {'it': 'Gilet imbottito', 'en': 'Padded gilet'},
              'data': {
                'group': 'Outerwear',
                'parent': 'Down Jacket',
                'isNew': true,
                'hint': 'x',
              },
            }),
          ),
        );

        final tipi = clothingTypes();
        expect(tipi['Outerwear']!.last, kClothingOther);
        expect(tipi['Outerwear']!.contains('Gilet imbottito'), isTrue);
        expect(clothingCategoryOf('Gilet imbottito'), 'Outerwear');
      },
    );

    test(
      'una voce disattivata non si propone, ma il capo che la usa la conosce',
      () {
        CatalogStore.set(
          cambia((voci) {
            for (final v in voci) {
              if (v['domain'] == 'use' && v['id'] == 'Lounge') {
                v['active'] = false;
              }
            }
          }),
        );

        expect(activityTags(), isNot(contains('Lounge')));
        expect(activityTags(activeOnly: false), contains('Lounge'));
        expect(clothingCategoryOf('Crop Top'), 'Upper Body');
      },
    );

    test('daProporre: attive più la scelta corrente anche se disattivata', () {
      CatalogStore.set(
        cambia((voci) {
          for (final v in voci) {
            if (v['domain'] == 'formality' && v['id'] == 'Loungewear') {
              v['active'] = false;
            }
          }
        }),
      );

      expect(
        daProporre(
          formalities(activeOnly: false),
          giaUsate: const [],
          dominio: 'formality',
        ),
        isNot(contains('Loungewear')),
      );
      expect(
        daProporre(
          formalities(activeOnly: false),
          giaUsate: const ['Loungewear'],
          dominio: 'formality',
        ),
        contains('Loungewear'),
      );
    });

    test(
      'un valore sconosciuto al catalogo resta proponibile (com\'era prima)',
      () {
        expect(voceAttiva('use', 'Party'), isTrue);
      },
    );
  });

  group('ordinaUsi', () {
    test(
      'usi del catalogo nel suo ordine, poi quelli sconosciuti nell\'ordine in cui erano',
      () {
        expect(ordinaUsi(['Lounge', 'Party', 'Everyday']), [
          'Everyday',
          'Lounge',
          'Party',
        ]);
        expect(ordinaUsi(['Party', 'Hiking', 'Ballo']), [
          'Hiking',
          'Party',
          'Ballo',
        ]);
        expect(ordinaUsi(const []), isEmpty);
      },
    );
  });
}
