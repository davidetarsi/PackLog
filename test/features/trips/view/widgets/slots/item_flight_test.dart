import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/view/widgets/slots/item_flight.dart';
import 'package:pack_log/shared/theme/theme.dart';

Widget _app(Widget child, {bool noAnimations = false}) => MaterialApp(
  builder: (context, home) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: noAnimations),
    child: home!,
  ),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('flyItems senza animazioni: nessun OverlayEntry dopo pump', (
    tester,
  ) async {
    final key = GlobalKey();
    late BuildContext context;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (c) {
            context = c;
            return SizedBox(key: key, width: 50, height: 20);
          },
        ),
        noAnimations: true,
      ),
    );
    final before = tester.widgetList(find.byType(Positioned)).length;

    final future = flyItems(
      context,
      flights: [
        ItemFlight(
          from: const Rect.fromLTWH(0, 0, 50, 20),
          to: key,
          child: const Text('volo'),
        ),
      ],
    );
    await tester.pump();
    await future;

    expect(find.text('volo'), findsNothing);
    expect(tester.widgetList(find.byType(Positioned)).length, before);
  });

  testWidgets('flyItems: il figlio vola e poi sparisce', (tester) async {
    final key = GlobalKey();
    late BuildContext context;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (c) {
            context = c;
            return Align(
              alignment: Alignment.bottomRight,
              child: SizedBox(key: key, width: 50, height: 20),
            );
          },
        ),
      ),
    );
    var landed = false;
    flyItems(
      context,
      flights: [
        ItemFlight(
          from: const Rect.fromLTWH(0, 0, 50, 20),
          to: key,
          child: const Text('volo'),
        ),
      ],
    ).then((_) => landed = true);
    await tester.pump();
    await tester.pump(AppMotion.slow ~/ 2);
    expect(find.text('volo'), findsOneWidget);
    expect(landed, isFalse);

    await tester.pump(AppMotion.slow);
    await tester.pump();
    expect(find.text('volo'), findsNothing);
    expect(landed, isTrue);
  });
}
