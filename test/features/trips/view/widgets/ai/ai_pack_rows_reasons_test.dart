import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/view/widgets/ai/ai_pack_rows.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/memory_asset_loader.dart';

AiSlot _slot(
  String id,
  String name, {
  AiSlotLevel level = AiSlotLevel.important,
  int remaining = 1,
  String? reason,
  bool toBuy = false,
  bool removed = false,
}) => AiSlot(
  id: id,
  type: id,
  category: ItemCategory.vestiti,
  level: level,
  name: name,
  copies: 3,
  remaining: remaining,
  reason: reason,
  addLabel: 'Aggiungi',
  toBuy: toBuy,
  removed: removed,
);

const _point = AiReasonPoint(
  code: 'tutti_i_giorni',
  title: 'Tutti i giorni',
  sentences: ['Da usare tutti i giorni'],
  items: ['Maglietta'],
);

const _rain = AiReasonPoint(
  code: 'pioggia',
  title: 'Pioggia',
  sentences: ['Può piovere'],
  items: [],
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pump(
    WidgetTester tester, {
    List<AiReasonPoint> reasons = const [],
    List<AiSlot> slots = const [],
  }) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
        path: 'assets/translations',
        assetLoader: MemoryAssetLoader(readAppTranslations()),
        fallbackLocale: const Locale('en', 'US'),
        startLocale: const Locale('it', 'IT'),
        saveLocale: false,
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.light,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: Scaffold(
              body: AiPackRows(
                warnings: const [],
                readIds: const {},
                reasons: reasons,
                slots: slots,
                onSearch: (_) {},
                onDismiss: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('pack_row_reasons')));
    await tester.pumpAndSettle();
  }

  final slots = [
    _slot('i1', 'Giacca', reason: 'Fino a -7°.', remaining: 2),
    _slot('i2', 'Ombrello'),
    _slot('u1', 'Magliette', level: AiSlotLevel.useful, remaining: 3),
    _slot('u2', 'Calzini', level: AiSlotLevel.useful, reason: 'Per i piedi'),
    _slot('x1', 'Riempito', remaining: 0),
    _slot('x2', 'Tolto', removed: true),
    _slot('x3', 'Comprare', toBuy: true),
    _slot('x4', 'Utile comprare', level: AiSlotLevel.useful, toBuy: true),
  ];

  testWidgets(
    'tre sezioni nell\'ordine della valigia: importanti, suggeriti, armadio',
    (tester) async {
      await pump(tester, reasons: [_point], slots: slots);
      await open(tester);

      final y = [
        for (final key in ['important', 'suggested', 'wardrobe'])
          tester.getTopLeft(find.byKey(Key('ai_reasons_$key'))).dy,
      ];
      expect(y[0], lessThan(y[1]));
      expect(y[1], lessThan(y[2]));
      expect(find.text('Importanti'), findsOneWidget);
      expect(find.text('Dal tuo armadio'), findsOneWidget);
      expect(find.text('Suggeriti da PackLog'), findsOneWidget);
      expect(find.text('Giacca ×2'), findsOneWidget);
      expect(find.text('Fino a -7°.'), findsOneWidget);
      expect(find.text('Da usare tutti i giorni'), findsOneWidget);
    },
  );

  testWidgets('riempiti, tolti e da comprare restano fuori', (tester) async {
    await pump(tester, reasons: [_point], slots: slots);
    await open(tester);

    for (final name in ['Riempito', 'Tolto', 'Comprare', 'Utile comprare']) {
      expect(find.text(name), findsNothing);
    }
  });

  testWidgets('motivo assente: solo il nome, senza ×1', (tester) async {
    await pump(tester, slots: [_slot('i2', 'Ombrello')]);
    await open(tester);

    expect(find.text('Ombrello'), findsOneWidget);
    expect(find.textContaining('×1'), findsNothing);
    expect(find.byKey(const Key('ai_reasons_wardrobe')), findsNothing);
    expect(find.byKey(const Key('ai_reasons_suggested')), findsNothing);
  });

  testWidgets('sezioni vuote non si mostrano', (tester) async {
    await pump(tester, reasons: [_point]);
    await open(tester);

    expect(find.byKey(const Key('ai_reasons_important')), findsNothing);
    expect(find.byKey(const Key('ai_reasons_suggested')), findsNothing);
    expect(find.byKey(const Key('ai_reasons_wardrobe')), findsOneWidget);
  });

  testWidgets('il sottotitolo riassume le tre parti con i plurali', (
    tester,
  ) async {
    await pump(tester, reasons: [_point, _rain], slots: slots);
    expect(
      find.text('2 importanti · 2 suggeriti · Tutti i giorni, Pioggia'),
      findsOneWidget,
    );
  });

  testWidgets('sottotitolo al singolare', (tester) async {
    await pump(
      tester,
      slots: [
        _slot('i2', 'Ombrello'),
        _slot('u2', 'Calzini', level: AiSlotLevel.useful),
      ],
    );
    expect(find.text('1 importante · 1 suggerito'), findsOneWidget);
  });

  testWidgets('la riga non c\'è se non c\'è niente da spiegare', (
    tester,
  ) async {
    await pump(
      tester,
      slots: [
        _slot('x1', 'Riempito', remaining: 0),
        _slot('x2', 'Tolto', removed: true),
        _slot('x3', 'Comprare', toBuy: true),
      ],
    );
    expect(find.byKey(const Key('pack_row_reasons')), findsNothing);
  });
}
