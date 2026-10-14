import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_floating_bar.dart';
import 'package:pack_log/shared/widgets/universal_item_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../screenshots/support/harness.dart';
import '../../../screenshots/support/seed.dart';

class _MockCoreAnalytics extends Mock implements CoreAnalyticsService {}

/// La casa con l'app vera (router, DB in memoria, dati di prova degli
/// screenshot): Casa Milano ha 7 vestiti, tra cui Calzini e Jeans blu.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    useSystemSqlite();
  });

  late _MockCoreAnalytics analytics;

  setUp(() => analytics = _MockCoreAnalytics());

  Future<ScreenshotApp> openHouse(WidgetTester tester, String id) async {
    final app = await ScreenshotApp.start(
      tester,
      theme: ShotTheme.light,
      setup: AppSetup(
        extraOverrides: [
          coreAnalyticsServiceProvider.overrideWithValue(analytics),
        ],
      ),
    );
    await app.go('/');
    await app.push('/houses/$id');
    return app;
  }

  Future<ScreenshotApp> openHome(WidgetTester tester) =>
      openHouse(tester, kHomeId);

  /// Il campo rapid-fire è l'ultimo TextField della schermata (la ricerca è
  /// chiusa).
  Finder rapidFire() => find.byType(TextField).last;

  testWidgets('niente filtri per categoria, gruppi con nome e conteggio', (
    tester,
  ) async {
    final app = await openHome(tester);
    expect(find.text('Tutto'), findsNothing);
    expect(find.text('In casa'), findsNothing);
    expect(find.text('Vestiti · 7'), findsOneWidget);
    await app.finish();
  });

  testWidgets('il tocco sull etichetta chiude e riapre il gruppo', (
    tester,
  ) async {
    final app = await openHome(tester);
    expect(find.text('Calzini'), findsOneWidget);
    await app.tap(find.text('Vestiti · 7'));
    expect(find.text('Calzini'), findsNothing);
    await app.tap(find.text('Vestiti · 7'));
    expect(find.text('Calzini'), findsOneWidget);
    await app.finish();
  });

  testWidgets('la ricerca filtra la lista e registra l apertura', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.tap(find.byKey(const Key('house_search')));
    verify(() => analytics.trackSearchOpened(context: 'house')).called(1);

    await app.enterText(find.byKey(const Key('house_search_field')), 'CALZ');
    expect(find.text('Calzini'), findsOneWidget);
    expect(find.text('Jeans blu'), findsNothing);
    expect(find.text('Vestiti · 1'), findsOneWidget);

    await app.tap(find.text('Calzini'));
    verify(
      () => analytics.trackSearchResultTapped(context: 'house', position: 1),
    ).called(1);
    await app.finish();
  });

  testWidgets('la freccia chiude la ricerca e torna tutta la lista', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.tap(find.byKey(const Key('house_search')));
    await app.enterText(find.byKey(const Key('house_search_field')), 'calz');
    await app.tap(find.byKey(const Key('house_search_close')));
    expect(find.byKey(const Key('house_search_field')), findsNothing);
    expect(find.text('Jeans blu'), findsOneWidget);
    await app.finish();
  });

  testWidgets('senza risultati mostra il vuoto e registra la lunghezza', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.tap(find.byKey(const Key('house_search')));
    await app.enterText(find.byKey(const Key('house_search_field')), 'zzzz');
    expect(find.text('Nessun oggetto trovato'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await app.settle();
    verify(
      () => analytics.trackSearchNoResults(context: 'house', queryLength: 4),
    ).called(1);
    await app.finish();
  });

  testWidgets('invio e chiusura della stessa ricerca contano una volta', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.tap(find.byKey(const Key('house_search')));
    await app.enterText(find.byKey(const Key('house_search_field')), 'zzzz');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await app.settle();
    await app.tap(find.byKey(const Key('house_search_close')));
    verify(
      () => analytics.trackSearchNoResults(context: 'house', queryLength: 4),
    ).called(1);
    await app.finish();
  });

  testWidgets('il tasto indietro chiude la ricerca e resta sulla casa', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.tap(find.byKey(const Key('house_search')));
    await app.enterText(find.byKey(const Key('house_search_field')), 'calz');
    await tester.binding.handlePopRoute();
    await app.settle();
    expect(find.byKey(const Key('house_search_field')), findsNothing);
    expect(find.text('Jeans blu'), findsOneWidget);
    expect(find.text('Casa Milano'), findsOneWidget);
    await app.finish();
  });

  testWidgets('con uno spazio scelto la ricerca conta solo quello spazio', (
    tester,
  ) async {
    final app = await openHome(tester);
    // Calzini sta in "Cassettiera": nello spazio "Armadio camera" non c'è.
    // Il test usa un font di sistema più largo: la pillola è fuori schermo a
    // destra, quindi la portiamo in vista prima del tocco.
    final armadioPill = find.textContaining('Armadio camera');
    await tester.ensureVisible(armadioPill);
    await app.tap(armadioPill);
    await app.tap(find.byKey(const Key('house_search')));
    await app.enterText(find.byKey(const Key('house_search_field')), 'calz');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await app.settle();
    expect(find.text('Nessun oggetto trovato'), findsOneWidget);
    verify(
      () => analytics.trackSearchNoResults(context: 'house', queryLength: 4),
    ).called(1);
    await app.finish();
  });

  testWidgets('seleziona tutti prende solo gli oggetti visibili', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.tap(find.byKey(const Key('house_search')));
    // "in" trova tre oggetti (Calzini, Camicia, Spazzolino). Con un solo
    // risultato, dopo il long press la selezione sarebbe già completa e il
    // bottone non mostrerebbe più "seleziona tutti".
    await app.enterText(find.byKey(const Key('house_search_field')), 'in');
    expect(find.text('Spazzolino'), findsOneWidget);
    await app.longPress(find.text('Calzini'));
    await app.tap(find.text('Seleziona tutti'));
    expect(find.text('3 selezionati'), findsOneWidget);
    await app.finish();
  });

  testWidgets('un oggetto scelto: 1 selezionato, azioni neutre e accese', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.longPress(find.text('Calzini'));
    expect(find.text('1 selezionato'), findsOneWidget);
    final selectedTile = tester.widget<UniversalItemTile>(
      find.ancestor(
        of: find.text('Calzini'),
        matching: find.byType(UniversalItemTile),
      ),
    );
    expect(
      selectedTile.backgroundColor,
      AppTheme.light.colorScheme.onSurface.withValues(alpha: 0.06),
    );
    final move = tester.widget<DsBarItem>(
      find.byKey(const Key('selection_move')),
    );
    expect(move.onTap, isNotNull);
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('selection_delete')),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.color, AppTheme.light.colorScheme.onSurface);
    await app.finish();
  });

  testWidgets('senza oggetti selezionati le tre azioni sono spente', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.longPress(find.text('Calzini'));
    await app.tap(find.byType(Checkbox).first);
    for (final key in const [
      Key('selection_move'),
      Key('selection_trip'),
      Key('selection_delete'),
    ]) {
      expect(tester.widget<DsBarItem>(find.byKey(key)).onTap, isNull);
    }
    await app.finish();
  });

  testWidgets('la ricerca prende il focus alla prima apertura', (tester) async {
    final app = await openHome(tester);
    await app.tap(find.byKey(const Key('house_search')));
    final field = find.descendant(
      of: find.byKey(const Key('house_search_field')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
    await app.finish();
  });

  testWidgets('dopo la selezione la ricerca non riprende la tastiera', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.tap(find.byKey(const Key('house_search')));
    await app.enterText(find.byKey(const Key('house_search_field')), 'calz');
    FocusManager.instance.primaryFocus?.unfocus();
    await app.settle();
    await app.longPress(find.text('Calzini'));
    await app.tap(find.byIcon(Icons.close));
    final textField = tester.widget<TextField>(
      find.byKey(const Key('house_search_field')),
    );
    final field = find.descendant(
      of: find.byKey(const Key('house_search_field')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(field).focusNode.hasFocus, isFalse);
    expect(textField.controller?.text, 'calz');
    expect(find.text('Calzini'), findsOneWidget);
    expect(find.text('Jeans blu'), findsNothing);
    await app.finish();
  });

  testWidgets('in basso solo campo e AI; l AI è l unico arancio', (
    tester,
  ) async {
    final app = await openHome(tester);
    // "⋯" è salito nell'intestazione: un solo bottone in tutta la schermata.
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.more_horiz),
      ),
      findsOneWidget,
    );
    final ai = tester.widget<Icon>(find.byIcon(Icons.auto_awesome));
    expect(ai.color, AppTheme.light.colorScheme.primary);
    await app.finish();
  });

  testWidgets('toccando il campo la lista sparisce, e con lei 🔍 e ⋯', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.tap(rapidFire());
    expect(find.text('Vestiti · 7'), findsNothing);
    expect(find.byKey(const Key('house_search')), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    await app.finish();
  });

  testWidgets('scrivendo compare Già in casa', (tester) async {
    final app = await openHome(tester);
    await app.tap(rapidFire());
    await app.enterText(rapidFire(), 'calz');
    expect(find.text('Già in casa · 1'), findsOneWidget);
    expect(find.text('Calzini'), findsOneWidget);
    await app.finish();
  });

  testWidgets('un oggetto salvato va in Aggiunti ora, non in Già in casa', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.tap(rapidFire());
    await app.enterText(rapidFire(), 'Felpa verde');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await app.settle();
    await app.enterText(rapidFire(), 'fel');
    expect(find.text('Aggiunti ora · 1'), findsOneWidget);
    expect(find.text('Felpa verde'), findsOneWidget);
    expect(find.textContaining('Già in casa'), findsNothing);
    await app.finish();
  });

  testWidgets('toccare un Già in casa apre l oggetto e registra l evento', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.tap(rapidFire());
    await app.enterText(rapidFire(), 'calz');
    await app.tap(find.text('Calzini'));
    verify(() => analytics.trackAddExistingMatchTapped(position: 1)).called(1);
    // La scheda dell'oggetto si apre sopra la pagina.
    expect(find.byKey(const Key('item_sheet_name')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await app.settle();
    expect(find.byKey(const Key('item_sheet_name')), findsNothing);
    // Chiusa la scheda, la pagina è ancora lì e il campo riprende il focus.
    expect(find.text('Già in casa · 1'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).focusNode?.hasFocus,
      isTrue,
    );
    await app.finish();
  });

  testWidgets('tenere premuto un Già in casa non avvia la selezione', (
    tester,
  ) async {
    final app = await openHome(tester);
    await app.tap(rapidFire());
    await app.enterText(rapidFire(), 'calz');
    await app.longPress(find.text('Calzini'));
    expect(find.byKey(const Key('selection_move')), findsNothing);
    expect(find.byKey(const ValueKey('selection-bar')), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Già in casa · 1'), findsOneWidget);
    await app.finish();
  });

  testWidgets(
    'toccare fuori dalla pagina la chiude; il campo ricorda il testo',
    (tester) async {
      final app = await openHome(tester);
      await app.tap(rapidFire());
      await app.enterText(rapidFire(), 'calz');
      expect(find.text('Già in casa · 1'), findsOneWidget);
      // Sotto il contenuto della pagina non c'è nulla: sta fuori dal gruppo
      // del campo.
      final page = tester.getRect(find.byKey(const Key('house_add_page')));
      await tester.tapAt(Offset(page.center.dx, page.bottom + 150));
      await app.settle();
      expect(find.text('Vestiti · 7'), findsOneWidget);
      await app.tap(rapidFire());
      expect(find.text('Già in casa · 1'), findsOneWidget);
      await app.finish();
    },
  );

  testWidgets(
    'la freccia indietro della barra chiude la pagina e resta sulla casa',
    (tester) async {
      final app = await openHome(tester);
      await app.tap(rapidFire());
      await app.enterText(rapidFire(), 'calz');
      await app.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.arrow_back),
        ),
      );
      expect(find.text('Già in casa · 1'), findsNothing);
      expect(find.text('Vestiti · 7'), findsOneWidget);
      expect(find.text('Casa Milano'), findsOneWidget);
      await app.finish();
    },
  );

  testWidgets('con la ricerca aperta, il campo la chiude', (tester) async {
    final app = await openHome(tester);
    await app.tap(find.byKey(const Key('house_search')));
    await app.tap(rapidFire());
    expect(find.byKey(const Key('house_search_field')), findsNothing);
    await app.enterText(rapidFire(), 'calz');
    expect(find.text('Già in casa · 1'), findsOneWidget);
    await app.finish();
  });

  testWidgets('indietro chiude la pagina e torna la lista', (tester) async {
    final app = await openHome(tester);
    await app.tap(rapidFire());
    await tester.binding.handlePopRoute();
    await app.settle();
    expect(find.text('Vestiti · 7'), findsOneWidget);
    await app.finish();
  });

  testWidgets('casa vuota: scansione AI e scrivili a mano', (tester) async {
    final app = await openHouse(tester, kEmptyHouseId);
    expect(find.text('Scansiona con AI'), findsOneWidget);
    await app.tap(find.byKey(const Key('items_empty_manual')));
    final field = tester.widget<TextField>(rapidFire());
    expect(field.focusNode?.hasFocus, isTrue);
    await app.finish();
  });
}
