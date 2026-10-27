import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/constants/app_constants.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_form_sheet.dart';
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
  void Function(BuildContext context) open,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
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
