import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/clothing_colors.dart';
import 'package:pack_log/features/items/model/clothing_taxonomy.dart';

String _capo(String baseColor) => jsonEncode({
  'name': 'Capo',
  'category': 'Upper Body',
  'subCategory': 'T-Shirt',
  'baseColor': baseColor,
  'warmth': 2,
  'formality': 'Casual',
  'activityTags': <String>[],
});

void main() {
  group('usedColorsFrom', () {
    test('unisce doppioni ignorando maiuscole e spazi', () {
      final colors = usedColorsFrom([
        _capo('blu'),
        _capo('Blu '),
        _capo('Blu'),
      ]);
      expect(colors, ['Blu']);
    });

    test('esclude vuoti, N/A e oggetti che non sono capi', () {
      final colors = usedColorsFrom([
        _capo('Rosa chiaro'),
        _capo('N/A'),
        _capo('n/a'),
        _capo(''),
        _capo('   '),
        null,
        '',
        'non json',
        jsonEncode({'category': 'Not Clothing', 'baseColor': 'Verde'}),
      ]);
      expect(colors, ['Rosa chiaro']);
    });

    test('ordina per frequenza, poi alfabetico senza maiuscole', () {
      final colors = usedColorsFrom([
        _capo('Verde'),
        _capo('Rosa'),
        _capo('rosa'),
        _capo('Arancio'),
        _capo('arancio'),
        _capo('Zafferano'),
      ]);
      // Rosa (2) e Arancio (2) prima di Verde e Zafferano (1, alfabetico).
      expect(colors, ['Arancio', 'Rosa', 'Verde', 'Zafferano']);
    });

    test('a parità di grafia vince la prima incontrata', () {
      final colors = usedColorsFrom([_capo('Blu notte'), _capo('blu notte')]);
      expect(colors, ['Blu notte']);
    });
  });

  group('colorChoices', () {
    test('senza colori dell\'utente restituisce i colori di base', () {
      expect(colorChoices(const []), kBaseColors);
    });

    test('non ripete i colori di base, senza maiuscole né sfumature', () {
      final choices = colorChoices(const [
        'blu',
        'Verde salvia',
        'Rosa chiaro',
        'BEIGE ',
      ]);
      expect(choices, [...kBaseColors, 'Verde salvia']);
    });
  });
}
