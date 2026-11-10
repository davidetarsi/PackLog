import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/kits/repositories/kit_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/catalogo_di_prova.dart';
import '../../../screenshots/support/harness.dart';
import '../../../screenshots/support/seed.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    useSystemSqlite();
  });

  setUp(caricaCatalogoDelRepo);

  Future<ScreenshotApp> openHouse(WidgetTester tester) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    await app.go('/');
    await app.push('/houses/$kHomeId');
    return app;
  }

  Future<void> createKit(
    ScreenshotApp app,
    String name, {
    List<String> activities = const [],
    List<String> items = const [],
  }) async {
    final repo = app.container.read(kitRepositoryProvider);
    await app.tester.runAsync(() async {
      final kit = await repo.createKit(
        houseId: kHomeId,
        name: name,
        activities: activities,
      );
      await repo.addItems(kit.id, {for (final id in items) id: 1});
    });
    await app.settle();
  }

  String location(ScreenshotApp app) =>
      app.router.routerDelegate.currentConfiguration.last.matchedLocation;

  testWidgets('mostra nome e usi senza quantità o chevron', (tester) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    await createKit(
      app,
      'Sci',
      activities: ['ski'],
      items: ['item-0', 'item-1'],
    );
    await app.go('/');
    await app.push('/houses/$kHomeId');

    expect(find.text('Sci'), findsOneWidget);
    expect(find.text('Sci · 2'), findsNothing);
    expect(find.text('Sci e neve'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
    await app.finish();
  });

  testWidgets('"Kit" apre /houses/<id>/kits/new', (tester) async {
    final app = await openHouse(tester);
    await app.tap(find.byKey(const Key('kit_strip_add')));

    expect(location(app), '/houses/$kHomeId/kits/new');
    await app.finish();
  });

  testWidgets('toccare una card apre il kit', (tester) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    await createKit(app, 'Sci', items: ['item-0']);
    await app.go('/');
    await app.push('/houses/$kHomeId');

    final card = find.text('Sci');
    await app.tap(card);

    expect(location(app), startsWith('/houses/$kHomeId/kits/'));
    expect(location(app), isNot(endsWith('/new')));
    await app.finish();
  });

  testWidgets('casa senza kit: solo il tasto Kit', (tester) async {
    final app = await openHouse(tester);

    expect(find.byKey(const Key('kit_strip_add')), findsOneWidget);
    expect(find.textContaining(' · 0'), findsNothing);
    expect(find.byIcon(Icons.inventory_2_outlined), findsNothing);
    await app.finish();
  });

  testWidgets('kit scorre via mentre la categoria resta sticky', (
    tester,
  ) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    await createKit(app, 'Sci', items: ['item-0']);
    await app.go('/');
    await app.push('/houses/$kHomeId');

    expect(find.text('Sci'), findsOneWidget);
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -450),
    );
    await app.settle();

    expect(find.text('Sci'), findsNothing);
    final groupHeaders = find.byKey(const Key('group_header_text'));
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      groupHeaders.evaluate().any((element) {
        final rect = tester.getRect(find.byWidget(element.widget));
        return rect.overlaps(Rect.fromLTWH(0, 0, 1000, screenHeight));
      }),
      isTrue,
    );
    await app.finish();
  });

  testWidgets('card compatta non va in overflow a testo grande e 320 px', (
    tester,
  ) async {
    final app = await ScreenshotApp.start(
      tester,
      theme: ShotTheme.light,
      setup: const AppSetup(initialViewport: Size(320, 640), textScale: 1.6),
    );
    await createKit(
      app,
      'Kit per una spedizione lunga in montagna',
      activities: ['ski'],
    );
    await app.go('/');
    await app.push('/houses/$kHomeId');

    expect(find.textContaining('Kit per una spedizione'), findsOneWidget);
    expect(app.issues, isEmpty);
    await app.finish();
  });

  testWidgets('strip nascosto durante ricerca e selezione', (tester) async {
    final app = await openHouse(tester);

    await app.tap(find.byKey(const Key('house_search')));
    expect(find.byKey(const Key('kit_strip_add')), findsNothing);
    await app.tap(find.byKey(const Key('house_search_close')));
    await app.longPress(find.text('Calzini'));
    expect(find.byKey(const Key('kit_strip_add')), findsNothing);

    await app.finish();
  });

  testWidgets('casa senza oggetti conserva accesso alla creazione kit', (
    tester,
  ) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    await app.go('/');
    await app.push('/houses/$kEmptyHouseId');

    expect(find.byKey(const Key('kit_strip_add')), findsOneWidget);
    await app.tap(find.byKey(const Key('kit_strip_add')));
    expect(location(app), '/houses/$kEmptyHouseId/kits/new');
    await app.finish();
  });
}
