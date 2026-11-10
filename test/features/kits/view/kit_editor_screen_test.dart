import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:pack_log/features/items/repositories/item_repository.dart';
import 'package:pack_log/features/items/widgets/rapid_fire_input.dart';
import 'package:pack_log/features/kits/model/kit_model.dart';
import 'package:pack_log/features/kits/repositories/kit_repository.dart';
import 'package:pack_log/shared/widgets/ds_choice_pill.dart';
import 'package:pack_log/shared/widgets/ds_field.dart';
import 'package:pack_log/shared/widgets/ds_form_sheet.dart';
import 'package:pack_log/shared/widgets/ds_inline_error.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/catalogo_di_prova.dart';
import '../../../screenshots/support/harness.dart';
import '../../../screenshots/support/seed.dart';
import '../../../screenshots/support/fonts.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await loadRealFonts();
    useSystemSqlite();
  });

  setUp(caricaCatalogoDelRepo);

  Future<ScreenshotApp> openNewKit(
    WidgetTester tester, {
    AppSetup setup = const AppSetup(),
  }) async {
    final app = await ScreenshotApp.start(
      tester,
      theme: ShotTheme.light,
      setup: setup,
    );
    await app.go('/');
    await app.push('/houses/$kHomeId/kits/new');
    return app;
  }

  Finder nameField() => find.byKey(const Key('kit_name_field'));
  Finder rapidFire() => find.byType(TextField).last;
  Finder pill(String label) => find.widgetWithText(DsChoicePill, label);
  bool isSelected(WidgetTester tester, String label) =>
      tester.widget<DsChoicePill>(pill(label)).selected;

  Future<List<KitModel>> kitsOf(ScreenshotApp app) async =>
      (await app.tester.runAsync(
        () =>
            app.container.read(kitRepositoryProvider).watchKits(kHomeId).first,
      ))!;

  Future<void> submitRapidFire(ScreenshotApp app, String text) async {
    await app.enterText(rapidFire(), text);
    await app.tester.testTextInput.receiveAction(TextInputAction.done);
    await app.settle();
  }

  /// Tocca un widget che può stare sotto il bordo dello schermo.
  Future<void> tapScrolled(ScreenshotApp app, Finder finder) async {
    await app.tester.ensureVisible(finder.first);
    await app.tap(finder);
  }

  Future<void> save(ScreenshotApp app) => app.tap(find.text('Salva'));

  testWidgets('il terzo oggetto del kit scorre sopra il Rapid Fire', (
    tester,
  ) async {
    final app = await ScreenshotApp.start(
      tester,
      theme: ShotTheme.light,
      setup: const AppSetup(viewport: Size(390, 844)),
    );
    try {
      final repo = app.container.read(kitRepositoryProvider);
      final kit = (await tester.runAsync(() async {
        final kit = await repo.createKit(houseId: kHomeId, name: 'Kit aereo');
        await repo.addItems(kit.id, {'item-0': 1, 'item-1': 1, 'item-4': 1});
        return kit;
      }))!;
      await app.go('/');
      await app.push('/houses/$kHomeId/kits/${kit.id}/edit');
      await app.tap(find.byKey(const Key('kit_uses_more')));
      final third = find.byKey(const Key('kit_item_row_item-4'));
      await tester.ensureVisible(third);
      await app.settle();
      final row = tester.getRect(third);
      final rapid = tester.getRect(find.byType(RapidFireInput));
      expect(row.bottom, lessThanOrEqualTo(rapid.top));
      expect(
        find.byKey(const Key('kit_item_remove_item-4')).hitTestable(),
        findsOneWidget,
      );
      expect(app.issues, isEmpty);
    } finally {
      await app.finish();
    }
  });

  testWidgets(
    'nel viewport stretto con testo grande i controlli restano raggiungibili',
    (tester) async {
      final app = await ScreenshotApp.start(
        tester,
        theme: ShotTheme.light,
        setup: const AppSetup(
          viewport: Size(320, 640),
          textScale: 1.6,
          viewInsetBottom: 280,
        ),
      );
      try {
        final repo = app.container.read(kitRepositoryProvider);
        final kit = (await tester.runAsync(() async {
          final kit = await repo.createKit(
            houseId: kHomeId,
            name: 'Kit stretto',
          );
          await repo.addItems(kit.id, {'item-0': 1, 'item-1': 1, 'item-4': 1});
          return kit;
        }))!;
        await app.go('/');
        await app.push('/houses/$kHomeId/kits/${kit.id}/edit');

        final third = find.byKey(const Key('kit_item_row_item-4'));
        await tester.ensureVisible(third);
        await app.settle();
        expect(
          find.byKey(const Key('kit_item_remove_item-4')).hitTestable(),
          findsOneWidget,
        );
        final increment = find.descendant(
          of: third,
          matching: find.byIcon(Icons.add_circle_outline),
        );
        await tester.ensureVisible(increment);
        await app.settle();
        expect(increment.hitTestable(), findsOneWidget);
        await tester.ensureVisible(find.byType(RapidFireInput));
        await app.settle();
        expect(find.byType(RapidFireInput).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(app.issues, isEmpty);
      } finally {
        await app.finish();
      }
    },
  );

  testWidgets('il form nuovo è un foglio DS e chiuderlo non crea il kit', (
    tester,
  ) async {
    final app = await openNewKit(tester);
    expect(find.byType(DsFormSheet), findsOneWidget);
    expect(find.byKey(const Key('kit_save')).hitTestable(), findsOneWidget);
    expect(find.byKey(const Key('sheet_close')).hitTestable(), findsOneWidget);

    await app.tap(find.byKey(const Key('sheet_close')));
    await app.settle();
    expect(await kitsOf(app), isEmpty);
    await app.finish();
  });

  for (final (label, viewport, scale, inset) in const [
    ('normale', Size(412, 915), 1.0, 0.0),
    ('stretto con tastiera', Size(320, 640), 1.6, 280.0),
  ]) {
    testWidgets(
      'save busy blocca chiusura e retry conserva la bozza ($label)',
      (tester) async {
        final repo = _MockKitRepository();
        final pendingSave = Completer<void>();
        final savedAt = DateTime(2026, 11, 9);
        var attempts = 0;
        when(
          () => repo.watchKits(any()),
        ).thenAnswer((_) => Stream.value(const []));
        when(
          () => repo.createKit(
            houseId: any(named: 'houseId'),
            name: any(named: 'name'),
            activities: any(named: 'activities'),
            transports: any(named: 'transports'),
          ),
        ).thenAnswer((invocation) async {
          if (attempts++ == 0) {
            await pendingSave.future;
            throw StateError('save failed');
          }
          final name = invocation.namedArguments[#name] as String;
          return KitModel(
            id: 'kit-retried',
            houseId: kHomeId,
            name: name,
            createdAt: savedAt,
            updatedAt: savedAt,
          );
        });
        final app = await ScreenshotApp.start(
          tester,
          theme: ShotTheme.light,
          setup: AppSetup(
            viewport: viewport,
            textScale: scale,
            viewInsetBottom: inset,
            extraOverrides: [kitRepositoryProvider.overrideWithValue(repo)],
          ),
        );
        await app.go('/');
        final result = app.router.push<bool>('/houses/$kHomeId/kits/new');
        await app.settle();
        await app.enterText(nameField(), 'Kit aereo');
        expect(isSelected(tester, 'Aereo'), isTrue);

        await save(app);
        await tester.pump();
        expect(tester.widget<DsTextField>(nameField()).enabled, isFalse);
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: nameField(),
                  matching: find.byType(EditableText),
                ),
              )
              .readOnly,
          isTrue,
        );
        expect(Focus.of(tester.element(nameField())).canRequestFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(
          tester.widget<RapidFireInput>(find.byType(RapidFireInput)).enabled,
          isFalse,
        );
        await tester.tap(
          find.byKey(const Key('sheet_close')),
          warnIfMissed: false,
        );
        await tester.binding.handlePopRoute();
        await app.settle();
        expect(find.byType(DsFormSheet), findsOneWidget);

        pendingSave.complete();
        await app.settle();
        expect(find.byType(DsInlineError), findsOneWidget);
        final errorRect = tester.getRect(find.byType(DsInlineError));
        final sheetRect = tester.getRect(find.byType(DsFormSheet));
        expect(errorRect.top, greaterThanOrEqualTo(sheetRect.top));
        expect(errorRect.bottom, lessThanOrEqualTo(sheetRect.bottom));
        expect(
          tester.widget<DsTextField>(nameField()).controller?.text,
          'Kit aereo',
        );
        expect(isSelected(tester, 'Aereo'), isTrue);
        expect(find.byKey(const Key('kit_save')).hitTestable(), findsOneWidget);

        await save(app);
        expect(await result, isTrue);
        expect(find.byType(DsFormSheet), findsNothing);
        verify(
          () => repo.createKit(
            houseId: kHomeId,
            name: 'Kit aereo',
            activities: const [],
            transports: ['plane'],
          ),
        ).called(2);
        expect(app.issues, isEmpty);
        await app.finish();
      },
    );
  }

  testWidgets('limite kit mostra erro nel foglio senza link Riprova', (
    tester,
  ) async {
    final repo = _MockKitRepository();
    when(() => repo.watchKits(any())).thenAnswer((_) => Stream.value(const []));
    when(
      () => repo.createKit(
        houseId: any(named: 'houseId'),
        name: any(named: 'name'),
        activities: any(named: 'activities'),
        transports: any(named: 'transports'),
      ),
    ).thenThrow(const KitLimitException(kMaxKitsPerHouse));
    final app = await ScreenshotApp.start(
      tester,
      theme: ShotTheme.light,
      setup: AppSetup(
        extraOverrides: [kitRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await app.go('/');
    await app.push('/houses/$kHomeId/kits/new');
    await app.enterText(nameField(), 'Kit aereo');
    await save(app);

    expect(find.byType(DsInlineError), findsOneWidget);
    expect(find.text('Riprova'), findsNothing);
    final errorRect = tester.getRect(find.byType(DsInlineError));
    final sheetRect = tester.getRect(find.byType(DsFormSheet));
    expect(errorRect.top, greaterThanOrEqualTo(sheetRect.top));
    expect(errorRect.bottom, lessThanOrEqualTo(sheetRect.bottom));
    await app.finish();
  });

  testWidgets('scrivere "Sci" preseleziona ski e mostra la frase', (
    tester,
  ) async {
    final app = await openNewKit(tester);
    await app.enterText(nameField(), 'Sci');

    expect(isSelected(tester, 'Sci e neve'), isTrue);
    expect(
      find.text(
        '«Sci e neve» è suggerito dal nome. Tocca le pillole per modificarle.',
      ),
      findsOneWidget,
    );
    expect(find.text('Lo aggiungo solo ai viaggi con…'), findsOneWidget);
    expect(find.text('(facoltativo)'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('(facoltativo)')).dy,
      greaterThan(
        tester.getBottomLeft(find.text('Lo aggiungo solo ai viaggi con…')).dy,
      ),
    );
    await app.finish();
  });

  testWidgets('titolo usi resta intero e facoltativo va sotto anche a 320 px', (
    tester,
  ) async {
    final app = await ScreenshotApp.start(
      tester,
      theme: ShotTheme.light,
      setup: const AppSetup(viewport: Size(320, 640)),
    );
    await app.go('/');
    await app.push('/houses/$kHomeId/kits/new');
    final title = find.text('Lo aggiungo solo ai viaggi con…');
    final optional = find.text('(facoltativo)');
    expect(title, findsOneWidget);
    expect(optional, findsOneWidget);
    expect(tester.getSize(title).height, lessThan(32));
    expect(
      tester.getTopLeft(optional).dy,
      greaterThan(tester.getBottomLeft(title).dy),
    );
    expect(tester.takeException(), isNull);
    await app.finish();
  });

  testWidgets(
    'toccare la pillola preselezionata la toglie e la frase sparisce',
    (tester) async {
      final app = await openNewKit(tester);
      await app.enterText(nameField(), 'Sci');
      await app.tap(pill('Sci e neve'));

      expect(isSelected(tester, 'Sci e neve'), isFalse);
      expect(find.textContaining('è suggerito dal nome'), findsNothing);

      // Riscrivere il nome non la rimette: l'utente l'ha tolta.
      await app.enterText(nameField(), 'Sci di fondo');
      expect(isSelected(tester, 'Sci e neve'), isFalse);
      await app.finish();
    },
  );

  testWidgets('un mezzo si riconosce dal nome: "Aereo" preseleziona il mezzo', (
    tester,
  ) async {
    final app = await openNewKit(tester);
    await app.enterText(nameField(), 'Kit aereo');

    expect(isSelected(tester, 'Aereo'), isTrue);
    await save(app);

    final kit = (await kitsOf(app)).single;
    expect(kit.name, 'Kit aereo');
    expect(kit.transports, ['plane']);
    await app.finish();
  });

  testWidgets(
    'invio nel Rapid Fire crea l\'oggetto nella casa e lo mette nel kit con le copie',
    (tester) async {
      final app = await openNewKit(tester);
      await app.enterText(nameField(), 'Montagna');
      await submitRapidFire(app, '2 Zaino da trekking');

      expect(find.text('Nel kit · 1'), findsOneWidget);
      expect(find.text('Zaino da trekking'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      await save(app);
      final kit = (await kitsOf(app)).single;
      expect(kit.items.single.copies, 2);
      final houseItems = (await app.tester.runAsync(
        () => app.container
            .read(itemRepositoryProvider)
            .getItemsByHouseId(kHomeId),
      ))!;
      final created = houseItems.singleWhere(
        (i) => i.name == 'Zaino da trekking',
      );
      expect(kit.items.single.itemId, created.id);
      await app.finish();
    },
  );

  testWidgets('toccare un oggetto in Già in casa lo aggiunge senza crearlo', (
    tester,
  ) async {
    final app = await openNewKit(tester);
    final before = (await app.tester.runAsync(
      () =>
          app.container.read(itemRepositoryProvider).getItemsByHouseId(kHomeId),
    ))!;
    await app.enterText(nameField(), 'Mare');
    await app.enterText(rapidFire(), 'Calz');

    expect(find.textContaining('Già in casa'), findsOneWidget);
    await tapScrolled(app, find.byKey(const Key('kit_match_item-4')));

    expect(find.text('Nel kit · 1'), findsOneWidget);
    await save(app);
    final kit = (await kitsOf(app)).single;
    expect(kit.items.map((i) => i.itemId), ['item-4']);
    final after = (await app.tester.runAsync(
      () =>
          app.container.read(itemRepositoryProvider).getItemsByHouseId(kHomeId),
    ))!;
    expect(after.length, before.length);
    await app.finish();
  });

  testWidgets('X toglie l\'oggetto dal kit, non dalla casa', (tester) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    final repo = app.container.read(kitRepositoryProvider);
    final kit = (await app.tester.runAsync(() async {
      final k = await repo.createKit(houseId: kHomeId, name: 'Sci');
      await repo.addItems(k.id, {'item-0': 1, 'item-1': 2});
      return k;
    }))!;
    await app.go('/');
    await app.push('/houses/$kHomeId/kits/${kit.id}/edit');
    expect(find.text('Nel kit · 2'), findsOneWidget);

    await tapScrolled(app, find.byKey(const Key('kit_item_remove_item-0')));
    expect(find.text('Nel kit · 1'), findsOneWidget);
    await save(app);

    final saved = (await kitsOf(app)).single;
    expect(saved.items.map((i) => i.itemId), ['item-1']);
    final houseItems = (await app.tester.runAsync(
      () =>
          app.container.read(itemRepositoryProvider).getItemsByHouseId(kHomeId),
    ))!;
    expect(houseItems.any((i) => i.id == 'item-0'), isTrue);
    await app.finish();
  });

  testWidgets('lo stepper cambia le copie e il salvataggio le tiene', (
    tester,
  ) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    final repo = app.container.read(kitRepositoryProvider);
    final kit = (await app.tester.runAsync(() async {
      final k = await repo.createKit(houseId: kHomeId, name: 'Sci');
      await repo.addItems(k.id, {'item-0': 2});
      return k;
    }))!;
    await app.go('/');
    await app.push('/houses/$kHomeId/kits/${kit.id}/edit');

    Finder inRow(IconData icon) => find.descendant(
      of: find.byKey(const Key('kit_item_row_item-0')),
      matching: find.byIcon(icon),
    );
    await tapScrolled(app, inRow(Icons.add_circle_outline));
    await tapScrolled(app, inRow(Icons.add_circle_outline));
    await tapScrolled(app, inRow(Icons.remove_circle_outline));
    await save(app);

    expect((await kitsOf(app)).single.items.single.copies, 3);
    await app.finish();
  });

  testWidgets('modificare il nome e le pillole salva sul kit esistente', (
    tester,
  ) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    final repo = app.container.read(kitRepositoryProvider);
    final kit = (await app.tester.runAsync(
      () => repo.createKit(houseId: kHomeId, name: 'Sci'),
    ))!;
    await app.go('/');
    await app.push('/houses/$kHomeId/kits/${kit.id}/edit');

    // In modifica il nome non cambia le pillole da solo.
    await app.enterText(nameField(), 'Sci e snowboard');
    await app.tap(find.byKey(const Key('kit_uses_more')));
    expect(isSelected(tester, 'Sci e neve'), isFalse);
    await tapScrolled(app, pill('Sci e neve'));
    await save(app);

    final saved = (await kitsOf(app)).single;
    expect(saved.id, kit.id);
    expect(saved.name, 'Sci e snowboard');
    expect(saved.activities, ['ski']);
    await app.finish();
  });

  group('analytics', () {
    late _MockAnalytics analytics;

    setUp(() {
      analytics = _MockAnalytics();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
    });

    AppSetup withAnalytics() => AppSetup(
      extraOverrides: [analyticsServiceProvider.overrideWithValue(analytics)],
    );

    testWidgets('kit_created al salvataggio del kit nuovo', (tester) async {
      final app = await openNewKit(tester, setup: withAnalytics());
      await app.enterText(nameField(), 'Sci');
      await submitRapidFire(app, 'Casco');
      await save(app);

      verify(
        () => analytics.logEvent(
          'kit_created',
          properties: {'items': 1, 'uses': 1},
        ),
      ).called(1);
      await app.finish();
    });

    testWidgets('modificare un kit non è kit_created', (tester) async {
      final app = await ScreenshotApp.start(
        tester,
        theme: ShotTheme.light,
        setup: withAnalytics(),
      );
      final kit = (await app.tester.runAsync(
        () => app.container
            .read(kitRepositoryProvider)
            .createKit(houseId: kHomeId, name: 'Sci'),
      ))!;
      await app.go('/');
      await app.push('/houses/$kHomeId/kits/${kit.id}/edit');
      await app.enterText(nameField(), 'Sci e snowboard');
      await save(app);

      verifyNever(
        () => analytics.logEvent(
          'kit_created',
          properties: any(named: 'properties'),
        ),
      );
      await app.finish();
    });
  });
}

class _MockAnalytics extends Mock implements AppAnalyticsService {}

class _MockKitRepository extends Mock implements KitRepository {}
