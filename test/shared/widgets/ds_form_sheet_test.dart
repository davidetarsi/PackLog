import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/constants/app_constants.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import 'package:pack_log/shared/widgets/ds_form_sheet.dart';
import 'package:pack_log/shared/widgets/ds_glass_band.dart';
import 'package:pack_log/shared/widgets/ds_sheet_header.dart';

const _actionKey = Key('sheet_action');

/// Imposta uno schermo logico di [size] con [bottomInset] di tastiera.
void _setScreen(
  WidgetTester tester, {
  Size size = const Size(400, 800),
  double bottomInset = 0,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.viewInsets = FakeViewPadding(bottom: bottomInset);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
}

/// Monta una pagina con un bottone che apre il foglio tramite [open].
Future<void> _pumpHost(
  WidgetTester tester,
  void Function(BuildContext context) open, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => open(context),
            child: const Text('apri'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('apri'));
  // Non pumpAndSettle: lo spinner della CTA in stato busy non si ferma mai.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Widget _form({
  bool isBusy = false,
  bool expand = false,
  IconData? actionIcon,
  Widget child = const SizedBox(height: 100),
}) => DsFormSheet(
  title: 'Titolo',
  actionLabel: 'Salva',
  actionKey: _actionKey,
  onSubmit: () {},
  isBusy: isBusy,
  expand: expand,
  actionIcon: actionIcon,
  child: child,
);

/// Cornice del foglio: il primo Container discendente di [DsFormSheet].
Finder get _frame => find
    .descendant(of: find.byType(DsFormSheet), matching: find.byType(Container))
    .first;

void main() {
  testWidgets('showDsSheet apre il foglio sul Navigator radice', (
    tester,
  ) async {
    _setScreen(tester);
    late BuildContext innerContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) {
              innerContext = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      ),
    );

    showDsSheet<void>(
      innerContext,
      builder: (_) => const DsFormSheet(title: 'Titolo', child: SizedBox()),
    );
    await tester.pumpAndSettle();

    expect(Navigator.of(innerContext).canPop(), isFalse);
    expect(Navigator.of(innerContext, rootNavigator: true).canPop(), isTrue);
  });

  testWidgets('il modulo non si chiude trascinando, la lista sì', (
    tester,
  ) async {
    _setScreen(tester);

    await _pumpHost(
      tester,
      (context) => showDsFormSheet<void>(context, builder: (_) => _form()),
    );
    await tester.drag(find.byType(DsSheetHeader), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byType(DsFormSheet), findsOneWidget);
    await tester.tap(find.byKey(const Key('sheet_close')));
    await tester.pumpAndSettle();

    await _pumpHost(
      tester,
      (context) => showDsSheet<void>(context, builder: (_) => _form()),
    );
    await tester.drag(find.byType(DsSheetHeader), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byType(DsFormSheet), findsNothing);
  });

  testWidgets('altezza al massimo il 90% sopra la tastiera', (tester) async {
    _setScreen(tester, bottomInset: 300);

    await _pumpHost(
      tester,
      (context) => showDsFormSheet<void>(
        context,
        builder: (_) => _form(child: const SizedBox(height: 2000)),
      ),
    );

    expect(
      tester.getSize(_frame).height,
      lessThanOrEqualTo(AppConstants.sheetMaxHeightFactor * (800 - 300)),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(_actionKey).hitTestable(), findsOneWidget);
  });

  testWidgets('titolo lungo e azioni vanno a capo, la X resta a destra', (
    tester,
  ) async {
    _setScreen(tester, size: const Size(320, 640));
    const action = Key('sheet_action_test');
    const done = Key('sheet_done_test');
    await _pumpHost(
      tester,
      (context) => showDsFormSheet<void>(
        context,
        builder: (_) => DsFormSheet(
          title: 'Scarpe da trekking impermeabili per il viaggio',
          actions: [
            TextButton(
              key: action,
              onPressed: () {},
              child: const Text('Da comprare'),
            ),
          ],
          footer: const SizedBox(
            key: done,
            height: 48,
            child: Center(child: Text('Chiudi')),
          ),
          child: const TextField(),
        ),
      ),
      textScale: 1.6,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('sheet_close')).hitTestable(), findsOneWidget);
    expect(find.byKey(action).hitTestable(), findsOneWidget);
    expect(find.byKey(done).hitTestable(), findsOneWidget);
    expect(
      tester.getTopRight(find.byKey(const Key('sheet_close'))).dx,
      lessThanOrEqualTo(320),
    );
  });

  testWidgets('il draft di corpo e piè sopravvive al cambio con tastiera', (
    tester,
  ) async {
    _setScreen(tester, size: const Size(320, 640));
    late StateSetter setHostState;
    var textScale = 1.0;
    final bodyController = TextEditingController();
    final footerController = TextEditingController();
    addTearDown(bodyController.dispose);
    addTearDown(footerController.dispose);
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setHostState = setState;
          return MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDsFormSheet<void>(
                    context,
                    builder: (_) => DsFormSheet(
                      title: 'Scarpe da trekking impermeabili per il viaggio',
                      actions: [
                        TextButton(
                          onPressed: () {},
                          child: const Text('Da comprare'),
                        ),
                      ],
                      footer: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'La quantità che aggiungi viene scalata da quella richiesta. '
                              'Puoi segnare da comprare ciò che manca.',
                            ),
                            TextField(
                              key: const Key('footer_draft'),
                              controller: footerController,
                            ),
                          ],
                        ),
                      ),
                      child: TextField(
                        key: const Key('body_draft'),
                        controller: bodyController,
                      ),
                    ),
                  ),
                  child: const Text('apri'),
                ),
              ),
            ),
          );
        },
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('body_draft')), 'testo corpo');
    await tester.enterText(find.byKey(const Key('footer_draft')), 'testo piè');

    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    setHostState(() => textScale = 1.6);
    await tester.pumpAndSettle();

    expect(bodyController.text, 'testo corpo');
    expect(footerController.text, 'testo piè');
    expect(tester.testTextInput.hasAnyClients, isTrue);
    expect(find.byKey(const Key('sheet_close')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expand: il contenuto riempie il foglio senza scroll esterno', (
    tester,
  ) async {
    _setScreen(tester);

    await _pumpHost(
      tester,
      (context) => showDsFormSheet<void>(
        context,
        builder: (_) => _form(expand: true, child: const SizedBox()),
      ),
    );

    expect(tester.getSize(_frame).height, closeTo(0.9 * 800, 1));
    expect(
      find.descendant(
        of: find.byType(DsFormSheet),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
  });

  testWidgets('la CTA sta sulla fascia di vetro, a spacingXs dal bordo', (
    tester,
  ) async {
    _setScreen(tester);
    await _pumpHost(
      tester,
      (context) => showDsFormSheet<void>(context, builder: (_) => _form()),
    );

    final band = find.descendant(
      of: find.byType(DsFormSheet),
      matching: find.byType(DsGlassBand),
    );
    expect(band, findsOneWidget);
    expect(
      find.descendant(of: band, matching: find.byKey(_actionKey)),
      findsOneWidget,
    );
    final gap =
        tester.getTopLeft(find.byKey(_actionKey)).dy -
        tester.getTopLeft(band).dy;
    expect(gap, closeTo(tester.element(band).spacingXs, 0.01));
  });

  testWidgets('contenuto lungo: scorre sotto la CTA e in fondo sale sopra', (
    tester,
  ) async {
    _setScreen(tester);
    const last = Key('ultimo');
    await _pumpHost(
      tester,
      (context) => showDsFormSheet<void>(
        context,
        builder: (_) => _form(
          child: const Column(
            children: [
              SizedBox(height: 1500),
              SizedBox(key: last, height: 40),
            ],
          ),
        ),
      ),
    );

    // Prima di scorrere il contenuto passa sotto la CTA.
    final band = find.descendant(
      of: find.byType(DsFormSheet),
      matching: find.byType(DsGlassBand),
    );
    final scroll = find.descendant(
      of: find.byType(DsFormSheet),
      matching: find.byType(SingleChildScrollView),
    );
    expect(
      tester.getBottomLeft(scroll).dy,
      greaterThan(tester.getTopLeft(band).dy),
    );

    // In fondo l'ultimo elemento sta tutto sopra la fascia.
    await tester.drag(scroll, const Offset(0, -3000));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.getBottomLeft(find.byKey(last)).dy,
      lessThanOrEqualTo(tester.getTopLeft(band).dy + 0.5),
    );
  });

  testWidgets('actionIcon arriva al bottone', (tester) async {
    _setScreen(tester);

    await _pumpHost(
      tester,
      (context) => showDsFormSheet<void>(
        context,
        builder: (_) => _form(actionIcon: Icons.check_rounded),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(_actionKey),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('isBusy: la x e il tocco fuori non chiudono', (tester) async {
    _setScreen(tester);

    await _pumpHost(
      tester,
      (context) =>
          showDsFormSheet<void>(context, builder: (_) => _form(isBusy: true)),
    );

    // La testata assorbe il tocco: il tocco non arriva alla x, è atteso.
    await tester.tap(find.byKey(const Key('sheet_close')), warnIfMissed: false);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DsFormSheet), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DsFormSheet), findsOneWidget);
  });
}
