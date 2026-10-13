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

  testWidgets(
    'etichetta lunga: una riga, larghezza limitata, nessun overflow',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.centerRight,
                child: PrimaryActionButton(
                  icon: Icons.add,
                  label: 'Un\'etichetta davvero molto lunga da tradurre',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(
        find.text('Un\'etichetta davvero molto lunga da tradurre'),
      );
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(
        tester.getSize(find.byType(PrimaryActionButton)).width,
        lessThanOrEqualTo(400 * 0.45),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('semantica: l\'etichetta è letta una volta sola', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        PrimaryActionButton(
          icon: Icons.add,
          label: 'Aggiungi',
          onPressed: () {},
        ),
      ),
    );
    expect(find.bySemanticsLabel('Aggiungi'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    handle.dispose();
  });
}
