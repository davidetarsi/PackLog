import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/clothing_taxonomy.dart';

// Le liste Dart devono coincidere con quelle del server: qui si legge il
// sorgente TypeScript come testo e si confronta.
const _tassonomiaTs = 'supabase/functions/_shared/valigia/tassonomia.ts';
const _schedaTs = 'supabase/functions/_shared/capi/scheda.ts';

String _leggi(String percorso) => File(percorso).readAsStringSync();

/// Le voci di un array TS: `export const NOME = ["a", "b"];`
List<String> _arrayTs(String sorgente, String nome) {
  final m = RegExp(
    'export const $nome = \\[(.*?)\\];',
    dotAll: true,
  ).firstMatch(sorgente);
  expect(m, isNotNull, reason: 'array $nome non trovato');
  return RegExp(
    r'"([^"]+)"',
  ).allMatches(m!.group(1)!).map((x) => x.group(1)!).toList();
}

/// Le chiavi di un record TS `const NOME: ... = { "k": ..., };` nell'ordine del file.
List<String> _chiaviRecordTs(String sorgente, String nome) {
  final inizio = sorgente.indexOf(RegExp('export const $nome\\b'));
  expect(inizio, isNonNegative, reason: 'record $nome non trovato');
  final fine = sorgente.indexOf('\n};', inizio);
  final corpo = sorgente.substring(inizio, fine);
  return RegExp(
    r'^\s*"([^"]+)":',
    multiLine: true,
  ).allMatches(corpo).map((x) => x.group(1)!).toList();
}

/// Il genitore/categoria di una voce NUOVE: `"Nome": ["Categoria", ...]`.
String _categoriaNuova(String sorgente, String sottocategoria) {
  final m = RegExp(
    '"${RegExp.escape(sottocategoria)}": \\["([^"]+)"',
  ).firstMatch(sorgente);
  expect(m, isNotNull, reason: 'voce NUOVE $sottocategoria non trovata');
  return m!.group(1)!;
}

void main() {
  late String tassonomia;
  late String scheda;

  setUpAll(() {
    tassonomia = _leggi(_tassonomiaTs);
    scheda = _leggi(_schedaTs);
  });

  group('coerenza col server (tassonomia.ts)', () {
    test('le categorie sono quelle di CATEGORIE, nello stesso ordine', () {
      expect(kClothingCategories, _arrayTs(tassonomia, 'CATEGORIE'));
    });

    test(
      'ogni categoria ha le sottocategorie di VECCHIE poi NUOVE poi Other',
      () {
        final vecchie = RegExp(
          r'export const VECCHIE[^=]*= \{(.*?)\n\};',
          dotAll: true,
        ).firstMatch(tassonomia)!.group(1)!;
        final nuove = _chiaviRecordTs(tassonomia, 'NUOVE');

        for (final categoria in kClothingCategories) {
          final attese = <String>[];
          final vecchieMatch = RegExp(
            '"${RegExp.escape(categoria)}": \\[([^\\]]*)\\]',
          ).firstMatch(vecchie);
          if (vecchieMatch != null) {
            attese.addAll(
              RegExp(
                r'"([^"]+)"',
              ).allMatches(vecchieMatch.group(1)!).map((x) => x.group(1)!),
            );
          }
          attese.addAll(
            nuove.where((s) => _categoriaNuova(tassonomia, s) == categoria),
          );
          attese.add(kClothingOther);

          expect(
            kClothingTypes[categoria],
            attese,
            reason: 'categoria $categoria',
          );
        }
      },
    );

    test('Full Body ed Essentials hanno solo sottocategorie nuove', () {
      expect(kClothingTypes['Full Body'], ['Dress', kClothingOther]);
      expect(kClothingTypes['Essentials'], [
        'Underwear',
        'Socks',
        'Pajamas',
        kClothingOther,
      ]);
    });

    test('kClothingTypes non ha categorie in più o in meno', () {
      expect(kClothingTypes.keys.toList(), kClothingCategories);
    });
  });

  group('coerenza col server (scheda.ts)', () {
    test('formalità coincide con FORMALITA', () {
      expect(kFormalities, _arrayTs(scheda, 'FORMALITA'));
    });

    test('tag di attività coincidono con TAG', () {
      expect(kActivityTags, _arrayTs(scheda, 'TAG'));
    });
  });

  group('clothingCategoryOf', () {
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

  group('clothingKey', () {
    test('minuscolo e non alfanumerici diventano _', () {
      expect(clothingKey('Cap/Hat'), 'cap_hat');
      expect(clothingKey('Smart Casual'), 'smart_casual');
      expect(clothingKey('Flip-Flops'), 'flip_flops');
    });
  });

  group('valori fissi', () {
    test('livelli di calore e impermeabilità', () {
      expect(kWarmthLevels, [1, 2, 3, 4, 5]);
      expect(kWaterResistanceLevels, [0, 1, 2]);
    });

    test('colori di base nell\'ordine concordato', () {
      expect(kBaseColors, [
        'Bianco',
        'Nero',
        'Grigio',
        'Blu',
        'Marrone',
        'Beige',
      ]);
    });
  });
}
