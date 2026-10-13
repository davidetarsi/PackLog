import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/widgets/primary_action_button.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('etichetta visibile all\'avvio, poi si richiude', (tester) async {
    await tester.pumpWidget(
      wrap(
        PrimaryActionButton(
          icon: Icons.add,
          label: 'Aggiungi',
          onPressed: () {},
        ),
      ),
    );
    expect(find.text('Aggiungi'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Aggiungi'), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('cambiare etichetta la rimostra', (tester) async {
    await tester.pumpWidget(
      wrap(PrimaryActionButton(icon: Icons.add, label: 'A', onPressed: () {})),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing);

    await tester.pumpWidget(
      wrap(PrimaryActionButton(icon: Icons.add, label: 'B', onPressed: () {})),
    );
    await tester.pump();
    expect(find.text('B'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('spento: colore tonale ma risponde al tocco', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        PrimaryActionButton(
          icon: Icons.add,
          label: 'X',
          enabled: false,
          onPressed: () => taps++,
        ),
      ),
    );
    final scheme = Theme.of(
      tester.element(find.byType(PrimaryActionButton)),
    ).colorScheme;
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(PrimaryActionButton),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, scheme.surfaceContainerHighest);

    await tester.tap(find.byType(PrimaryActionButton));
    expect(taps, 1);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
