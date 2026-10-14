import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/core_analytics_service.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
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

  Future<ScreenshotApp> openHome(WidgetTester tester) async {
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
    await app.push('/houses/$kHomeId');
    return app;
  }

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
}
