import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/catalog/catalog.dart';
import 'package:pack_log/core/catalog/catalog_store.dart';
import 'package:pack_log/features/items/model/clothing_labels.dart';
import 'package:pack_log/features/items/model/clothing_taxonomy.dart';

import '../../../helpers/catalogo_di_prova.dart';

// Le etichette vengono dal catalogo (31 ottobre): nessun dizionario di traduzione.
// Le etichette scritte qui sono quelle del 31 ottobre: se una voce del catalogo
// viene rinominata di proposito, si aggiorna l'etichetta attesa nello stesso
// commit dell'export (vedi anche catalogo_parita.test.ts).

void main() {
  setUp(() => caricaCatalogoDelRepo(lingua: 'it'));
  tearDown(() => CatalogStore.set(Catalog.vuoto));

  group('etichette in it', () {
    test('tipo, gruppo, calore, pioggia, stile, usi', () {
      expect(clothingTypeLabel('Casual Jacket'), 'Giubbotto');
      expect(clothingTypeLabel('Cap/Hat'), 'Cappello');
      expect(clothingGroupLabel('Upper Body'), 'Sopra');
      expect(warmthLabel(4), 'Caldo');
      expect(waterResistanceLabel(2), 'Impermeabile');
      expect(formalityLabel('Smart Casual'), 'Curato');
      expect(activityLabel('Everyday'), 'Tutti i giorni');
    });

    test('valori sconosciuti tornano come sono', () {
      expect(clothingTypeLabel('Valore strano'), 'Valore strano');
      expect(clothingGroupLabel('Valore strano'), 'Valore strano');
      expect(formalityLabel('Valore strano'), 'Valore strano');
      expect(activityLabel('Valore strano'), 'Valore strano');
      expect(warmthLabel(9), '9');
      expect(waterResistanceLabel(7), '7');
    });
  });

  group('etichette in en', () {
    test('tipo e gruppo in inglese', () {
      CatalogStore.setLanguage('en');

      expect(clothingTypeLabel('Casual Jacket'), 'Casual jacket');
      expect(clothingGroupLabel('Upper Body'), 'Tops');
      expect(warmthLabel(1), 'Very light');
    });

    test('una lingua che non è it dà l\'inglese', () {
      CatalogStore.setLanguage('fr');

      expect(
        clothingTypeLabel('Cap/Hat'),
        catalogoDelRepo().find('clothing_type', 'Cap/Hat')!.labelEn,
      );
    });
  });

  group('colorLabel', () {
    test('colore non di base: iniziale maiuscola, testo com\'è', () {
      expect(colorLabel('verde salvia'), 'Verde salvia');
      expect(colorLabel('  oro rosa  '), 'Oro rosa');
    });

    test('vuoto o N/A diventa stringa vuota', () {
      expect(colorLabel(''), '');
      expect(colorLabel('   '), '');
      expect(colorLabel('N/A'), '');
      expect(colorLabel('n/a'), '');
    });

    test('colore di base si mostra con la lingua attiva', () {
      expect(colorLabel('blu'), 'Blu');
      expect(colorLabel('Blu'), 'Blu');

      CatalogStore.setLanguage('en');
      expect(colorLabel('Blu'), 'Blue');
      expect(colorLabel('blu'), 'Blue');
    });

    test('sinonimi e sfumature dei colori salvati prima si mostrano', () {
      CatalogStore.setLanguage('en');
      expect(colorLabel('Blu navy'), 'Navy');
      expect(colorLabel('Verde oliva'), 'Green');
      expect(colorLabel('celeste'), 'Light blue');
      expect(colorLabel('Multicolore'), 'Multicolour');
    });
  });

  group('con un catalogo cambiato', () {
    Catalog con(void Function(List<Map<String, dynamic>> voci) modifica) {
      final json = catalogoDelRepo().toJson();
      final voci = (json['entries'] as List).cast<Map<String, dynamic>>();
      modifica(voci);
      return Catalog.fromJson(json);
    }

    test('una voce nuova ha la sua etichetta nella lingua attiva', () {
      CatalogStore.set(
        con(
          (voci) => voci.add({
            'domain': 'use',
            'id': 'Party',
            'sort': 90,
            'active': true,
            'label': {'it': 'Festa', 'en': 'Party'},
            'data': {'prompt': 'x', 'promptOrder': 8},
          }),
        ),
      );

      expect(activityLabel('Party'), 'Festa');
      CatalogStore.setLanguage('en');
      expect(activityLabel('Party'), 'Party');
    });

    test('una voce disattivata si mostra con la sua etichetta', () {
      CatalogStore.set(
        con((voci) {
          for (final v in voci) {
            if (v['domain'] == 'use' && v['id'] == 'Lounge') {
              v['active'] = false;
            }
          }
        }),
      );

      expect(
        activityLabel('Lounge'),
        catalogoDelRepo().find('use', 'Lounge')!.labelIt,
      );
      expect(activityTags(), isNot(contains('Lounge')));
    });
  });

  group('il file dell\'app', () {
    test(
      'le traduzioni non hanno più le chiavi dei capi coperte dal catalogo',
      () {
        for (final file in [
          'assets/translations/it-IT.json',
          'assets/translations/en-US.json',
        ]) {
          final json =
              jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>;
          final capi = json['clothing'] as Map<String, dynamic>;
          expect(capi.keys, ['details'], reason: file);
        }
      },
    );

    test('ogni valore che l\'app propone ha un\'etichetta del catalogo', () {
      final catalogo = catalogoDelRepo();
      for (final voce in catalogo.entries) {
        expect(
          voce.labelIt.trim(),
          isNotEmpty,
          reason: '${voce.domain}/${voce.id}',
        );
        expect(
          voce.labelEn.trim(),
          isNotEmpty,
          reason: '${voce.domain}/${voce.id}',
        );
      }
    });
  });
}
