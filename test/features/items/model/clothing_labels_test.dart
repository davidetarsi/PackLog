import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pack_log/features/items/model/clothing_labels.dart';
import 'package:pack_log/features/items/model/clothing_taxonomy.dart';

import '../../../helpers/memory_asset_loader.dart';

const _it = Locale('it', 'IT');
const _en = Locale('en', 'US');

/// Tutte le chiavi foglia di un dizionario, con il percorso puntato
/// (es. `clothing.type.cap_hat`).
Set<String> _chiavi(Map<String, dynamic> dizionario, [String prefisso = '']) {
  final out = <String>{};
  dizionario.forEach((chiave, valore) {
    final percorso = prefisso.isEmpty ? chiave : '$prefisso.$chiave';
    if (valore is Map<String, dynamic> && !valore.containsKey('one')) {
      out.addAll(_chiavi(valore, percorso));
    } else {
      out.add(percorso);
    }
  });
  return out;
}

Map<String, dynamic> _leggiDizionario(String nomeFile) =>
    jsonDecode(File('assets/translations/$nomeFile').readAsStringSync())
        as Map<String, dynamic>;

final _dizionari = {
  'it-IT': _chiavi(_leggiDizionario('it-IT.json')),
  'en-US': _chiavi(_leggiDizionario('en-US.json')),
};

/// Monta EasyLocalization con un contesto da cui cambiare la lingua: il
/// controller è condiviso fra i test, quindi la lingua si imposta ogni volta.
Future<void> _pumpLocale(WidgetTester tester, Locale locale) async {
  late BuildContext contesto;
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [_it, _en],
      path: 'assets/translations',
      assetLoader: MemoryAssetLoader(readAppTranslations()),
      fallbackLocale: _en,
      startLocale: _it,
      saveLocale: false,
      child: Builder(
        builder: (context) {
          contesto = context;
          return MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: const SizedBox(),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(() => contesto.setLocale(locale));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('dizionari', () {
    final chiaviRichieste = <String>[
      for (final tipi in kClothingTypes.values)
        for (final tipo in tipi) 'clothing.type.${clothingKey(tipo)}',
      for (final gruppo in kClothingCategories)
        'clothing.group.${clothingKey(gruppo)}',
      for (final livello in kWarmthLevels) 'clothing.warmth.$livello',
      for (final livello in kWaterResistanceLevels) 'clothing.water.$livello',
      for (final stile in kFormalities)
        'clothing.formality.${clothingKey(stile)}',
      for (final uso in kActivityTags) 'clothing.activity.${clothingKey(uso)}',
      for (final colore in kBaseColors) 'clothing.color.${clothingKey(colore)}',
      for (final chiave in const [
        'title',
        'type',
        'color',
        'warmth',
        'water',
        'formality',
        'uses',
        'uses_hint',
        'to_check',
        'other_color',
        'color_hint',
        'choose_type',
      ])
        'clothing.details.$chiave',
      'ai_import.to_check',
    ];

    for (final entry in _dizionari.entries) {
      test('${entry.key} contiene tutte le chiavi dei capi', () {
        final mancanti = chiaviRichieste
            .where((k) => !entry.value.contains(k))
            .toList();
        expect(mancanti, isEmpty);
      });
    }

    test('"Altro" è una sola chiave per tutti i gruppi', () {
      expect(kClothingOther, 'Other');
      expect(_dizionari['it-IT'], contains('clothing.type.other'));
      expect(_dizionari['en-US'], contains('clothing.type.other'));
    });
  });

  group('colorLabel', () {
    testWidgets('colore non di base: iniziale maiuscola, testo com\'è', (
      tester,
    ) async {
      await _pumpLocale(tester, _it);

      expect(colorLabel('verde salvia'), 'Verde salvia');
      expect(colorLabel('  oro rosa  '), 'Oro rosa');
    });

    testWidgets('vuoto o N/A diventa stringa vuota', (tester) async {
      await _pumpLocale(tester, _it);

      expect(colorLabel(''), '');
      expect(colorLabel('   '), '');
      expect(colorLabel('N/A'), '');
      expect(colorLabel('n/a'), '');
    });

    testWidgets('colore di base si traduce con la lingua attiva', (
      tester,
    ) async {
      await _pumpLocale(tester, _it);
      expect(colorLabel('blu'), 'Blu');
      expect(colorLabel('Blu'), 'Blu');

      await _pumpLocale(tester, _en);
      expect(colorLabel('Blu'), 'Blue');
      expect(colorLabel('blu'), 'Blue');
    });

    testWidgets('sinonimi e sfumature dei colori salvati prima si traducono', (
      tester,
    ) async {
      await _pumpLocale(tester, _en);
      expect(colorLabel('Blu navy'), 'Navy');
      expect(colorLabel('Verde oliva'), 'Green');
      expect(colorLabel('celeste'), 'Light blue');
      expect(colorLabel('Multicolore'), 'Multicolour');
    });
  });

  group('etichette in it-IT', () {
    testWidgets('tipo, gruppo, calore, pioggia, stile, usi', (tester) async {
      await _pumpLocale(tester, _it);

      expect(clothingTypeLabel('Casual Jacket'), 'Giubbotto');
      expect(clothingTypeLabel('Cap/Hat'), 'Cappello');
      expect(clothingGroupLabel('Upper Body'), 'Sopra');
      expect(warmthLabel(4), 'Caldo');
      expect(waterResistanceLabel(2), 'Impermeabile');
      expect(formalityLabel('Smart Casual'), 'Curato');
      expect(activityLabel('Everyday'), 'Tutti i giorni');
    });

    testWidgets('valori sconosciuti tornano come sono', (tester) async {
      await _pumpLocale(tester, _it);

      expect(clothingTypeLabel('Valore strano'), 'Valore strano');
      expect(clothingGroupLabel('Valore strano'), 'Valore strano');
      expect(formalityLabel('Valore strano'), 'Valore strano');
      expect(activityLabel('Valore strano'), 'Valore strano');
    });
  });

  group('etichette in en-US', () {
    testWidgets('tipo e gruppo in inglese', (tester) async {
      await _pumpLocale(tester, _en);

      expect(clothingTypeLabel('Casual Jacket'), 'Casual jacket');
      expect(clothingGroupLabel('Upper Body'), 'Tops');
      expect(warmthLabel(1), 'Very light');
    });
  });
}
