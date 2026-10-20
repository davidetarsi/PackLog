import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/view/widgets/postcard/postcard_pile.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/memory_asset_loader.dart';

late AssetLoader _assetLoader;

final _pileFinder = find.byKey(const Key('postcard_pile'));
final _topFinder = find.byKey(const Key('postcard_pile_top'));
final _dotsFinder = find.byKey(const Key('postcard_pile_dots'));

/// Elemento con stato: la State ricorda l'indice per cui è stata creata.
class _Probe extends StatefulWidget {
  final int index;

  const _Probe(this.index);

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  late final int createdFor = widget.index;

  @override
  Widget build(BuildContext context) => Text('probe $createdFor');
}

Future<void> _pump(
  WidgetTester tester, {
  required int itemCount,
  IndexedWidgetBuilder? itemBuilder,
}) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
      path: 'assets/translations',
      assetLoader: _assetLoader,
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
            body: Center(
              child: SizedBox(
                width: 390,
                height: 640,
                child: PostcardPile(
                  itemCount: itemCount,
                  itemBuilder: itemBuilder ?? (_, i) => Text('card $i'),
                  semanticLabel: (i) => 'Viaggio ${i + 1}',
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Matrice del Transform della cartolina in cima: storage[12] è la traslazione
/// orizzontale, storage[1] il seno della rotazione (zero a riposo).
Matrix4 _topMatrix(WidgetTester tester) =>
    tester.widget<Transform>(_topFinder).transform;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    _assetLoader = MemoryAssetLoader(readAppTranslations());
  });

  testWidgets('mostra il primo elemento e il contatore', (tester) async {
    await _pump(tester, itemCount: 3);

    expect(find.text('card 0'), findsOneWidget);
    expect(find.text('1 di 3'), findsOneWidget);
    expect(_dotsFinder, findsOneWidget);
  });

  testWidgets('swipe verso sinistra avanza al successivo', (tester) async {
    await _pump(tester, itemCount: 3);

    await tester.drag(_pileFinder, const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(find.text('card 1'), findsOneWidget);
    expect(find.text('card 0'), findsNothing);
    expect(find.text('2 di 3'), findsOneWidget);
  });

  testWidgets('swipe verso destra torna al precedente', (tester) async {
    await _pump(tester, itemCount: 3);

    await tester.drag(_pileFinder, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.drag(_pileFinder, const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(find.text('card 0'), findsOneWidget);
    expect(find.text('card 1'), findsNothing);
  });

  testWidgets('sull ultimo elemento lo swipe a sinistra non avanza', (
    tester,
  ) async {
    await _pump(tester, itemCount: 2);

    await tester.drag(_pileFinder, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.drag(_pileFinder, const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(find.text('card 1'), findsOneWidget);
    expect(find.text('card 0'), findsNothing);
  });

  testWidgets('sul primo elemento lo swipe a destra non torna indietro', (
    tester,
  ) async {
    await _pump(tester, itemCount: 2);

    await tester.drag(_pileFinder, const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(find.text('card 0'), findsOneWidget);
  });

  testWidgets('uno spostamento sotto soglia torna al centro', (tester) async {
    await _pump(tester, itemCount: 3);

    await tester.timedDrag(
      _pileFinder,
      const Offset(-40, 0),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();

    expect(find.text('card 0'), findsOneWidget);
    expect(find.text('card 1'), findsNothing);
    expect(find.text('1 di 3'), findsOneWidget);
  });

  testWidgets('con un solo elemento non mostra i puntini', (tester) async {
    await _pump(tester, itemCount: 1);

    expect(find.text('card 0'), findsOneWidget);
    expect(_dotsFinder, findsNothing);
  });

  testWidgets(
    'se la lista si accorcia sotto l indice corrente torna al primo',
    (tester) async {
      await _pump(tester, itemCount: 3);
      await tester.drag(_pileFinder, const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.drag(_pileFinder, const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('card 2'), findsOneWidget);

      await _pump(tester, itemCount: 1);

      expect(find.text('card 0'), findsOneWidget);
      expect(find.text('card 2'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('un gesto interrotto riporta la cartolina al centro', (
    tester,
  ) async {
    await _pump(tester, itemCount: 3);

    final gesture = await tester.startGesture(tester.getCenter(_pileFinder));
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    expect(_topMatrix(tester).storage[12], lessThan(0));

    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(_topMatrix(tester).storage[12], 0);
    expect(_topMatrix(tester).storage[1], 0);
    expect(find.text('card 0'), findsOneWidget);
    expect(find.text('1 di 3'), findsOneWidget);
  });

  testWidgets('lo stato di un elemento non passa al successivo', (
    tester,
  ) async {
    await _pump(tester, itemCount: 3, itemBuilder: (_, i) => _Probe(i));

    await tester.drag(_pileFinder, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.drag(_pileFinder, const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(find.text('probe 0'), findsOneWidget);
    expect(find.text('probe 1'), findsNothing);
  });

  testWidgets('a riposo la cartolina in cima ha rotazione zero', (
    tester,
  ) async {
    await _pump(tester, itemCount: 3);

    final transform = tester.widget<Transform>(_topFinder);
    // Elemento [1][0] della matrice: seno dell'angolo, zero a riposo.
    expect(transform.transform.storage[1], 0);
  });
}
