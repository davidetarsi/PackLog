import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/ai_input/model/clothing_analysis_result.dart';
import 'package:pack_log/features/ai_input/view/widgets/ai_result_card.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/memory_asset_loader.dart';

const _it = Locale('it', 'IT');
const _en = Locale('en', 'US');

ClothingAnalysisResult _result({
  String subCategory = 'Shirt',
  String baseColor = 'Bianco',
  List<String> doubts = const [],
}) => ClothingAnalysisResult(
  name: 'Camicia di lino',
  category: 'Upper Body',
  subCategory: subCategory,
  baseColor: baseColor,
  pattern: 'Tinta unita',
  coverage: 'Busto',
  fit: 'Regular',
  warmth: 2,
  formality: 'Casual',
  activityTags: const ['città'],
  doubts: doubts,
);

/// Monta la riga dentro un'app con le traduzioni vere, in italiano.
Future<void> _pumpCard(
  WidgetTester tester, {
  required ClothingAnalysisResult item,
  bool included = true,
  VoidCallback? onOpenDetails,
  VoidCallback? onAlreadyHere,
  Locale locale = _it,
}) async {
  late BuildContext contesto;
  final controller = TextEditingController(text: item.name);
  addTearDown(controller.dispose);
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
            theme: AppTheme.light,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: Scaffold(
              body: AiResultCard(
                item: item,
                controller: controller,
                included: included,
                onIncludedChanged: (_) {},
                onOpenDetails: onOpenDetails,
                onAlreadyHere: onAlreadyHere,
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (locale != _it) {
    await tester.runAsync(() => contesto.setLocale(locale));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('aiDetailsLine()', () {
    testWidgets('mostra tipo e colore tradotti separati da un punto', (
      tester,
    ) async {
      await _pumpCard(tester, item: _result());
      expect(find.text('Camicia · Bianco'), findsOneWidget);
    });

    testWidgets('il colore di base segue la lingua dell’app', (tester) async {
      await _pumpCard(tester, item: _result(), locale: _en);
      expect(find.text('Shirt · White'), findsOneWidget);
    });

    testWidgets('salta tipo e colore vuoti o N/A senza inventare nulla', (
      tester,
    ) async {
      expect(
        aiDetailsLine(_result(subCategory: 'N/A', baseColor: '')),
        isEmpty,
      );
      expect(
        aiDetailsLine(_result(subCategory: ' ', baseColor: 'n/a')),
        isEmpty,
      );
      expect(aiDetailsLine(_result(baseColor: 'N/A')), isNot(contains('·')));
    });
  });

  group('AiResultCard', () {
    testWidgets('conta i dubbi con la pillola tratteggiata "da controllare"', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        item: _result(doubts: const ['warmth', 'formality']),
      );
      expect(find.text('2 da controllare'), findsOneWidget);
      expect(find.byKey(const Key('ai_result_to_check')), findsOneWidget);
    });

    testWidgets('nelle varie conta solo i dubbi dei campi che si vedono', (
      tester,
    ) async {
      // Uno zaino: calore e stile non si mostrano, l'impermeabilità sì.
      await _pumpCard(
        tester,
        item: _result(
          subCategory: 'Bag',
          doubts: const ['warmth', 'formality', 'waterResistance'],
        ).copyWith(category: 'Accessory', appCategory: 'varie'),
      );
      expect(find.text('1 da controllare'), findsOneWidget);
    });

    testWidgets('nome in evidenza, tipo e colore e dubbi mai sotto 14', (
      tester,
    ) async {
      await _pumpCard(tester, item: _result(doubts: const ['warmth']));
      double sizeOf(String text) =>
          tester.widget<Text>(find.text(text)).style!.fontSize!;
      expect(
        tester
            .widget<RichText>(
              find.textContaining('Camicia di lino', findRichText: true),
            )
            .text
            .style!
            .fontSize!,
        greaterThan(16),
      );
      expect(sizeOf('1 da controllare'), greaterThanOrEqualTo(14));
      final details = find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains(' · '),
      );
      expect(
        tester.widget<Text>(details).style!.fontSize!,
        greaterThanOrEqualTo(14),
      );
    });

    testWidgets('la freccia segue il nome, non sta in fondo alla riga', (
      tester,
    ) async {
      await _pumpCard(tester, item: _result(), onAlreadyHere: () {});
      final chevron = tester.getRect(
        find.byKey(const Key('ai_result_chevron')),
      );
      final button = tester.getRect(find.byKey(const Key('ai_already_here')));
      // Subito dopo "Camicia di lino", ben lontana da "C'è già?".
      expect(chevron.right, lessThan(button.left - 48));
    });

    testWidgets('niente matita: il nome si cambia nella scheda', (
      tester,
    ) async {
      await _pumpCard(tester, item: _result());
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('senza dubbi non mostra la riga di controllo', (tester) async {
      await _pumpCard(tester, item: _result());
      expect(find.text('da controllare'), findsNothing);
      expect(find.byIcon(Icons.help_outline), findsNothing);
    });

    testWidgets('"C\'è già?" sta a destra quando la casa è disponibile', (
      tester,
    ) async {
      await _pumpCard(tester, item: _result(), onAlreadyHere: () {});
      final card = tester.getRect(find.byType(AiResultCard));
      final button = tester.getRect(find.byKey(const Key('ai_already_here')));
      expect(find.text("C'è già?"), findsOneWidget);
      expect(button.center.dx, greaterThan(card.center.dx));
    });

    testWidgets('"C\'è già?" non compare senza callback', (tester) async {
      await _pumpCard(tester, item: _result());
      expect(find.byKey(const Key('ai_already_here')), findsNothing);
    });

    testWidgets('il tocco sui dettagli apre la scheda', (tester) async {
      var opened = 0;
      await _pumpCard(tester, item: _result(), onOpenDetails: () => opened++);
      await tester.tap(find.byKey(const Key('ai_result_details')));
      await tester.pump();
      expect(opened, 1);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });
}
