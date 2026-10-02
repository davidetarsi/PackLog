import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';

/// [DsButton] è l'unica implementazione di forma e colore dei bottoni: se la
/// scala a tre livelli si rompe qui, si rompe ovunque nell'app.
void main() {
  Future<void> pumpButton(
    WidgetTester tester, {
    required DsButtonVariant variant,
    VoidCallback? onPressed,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: DsButton(
              label: 'Etichetta',
              variant: variant,
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }

  Color backgroundOf(WidgetTester tester) {
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(DsButton),
            matching: find.byType(Material),
          )
          .first,
    );
    return material.color!;
  }

  Color borderOf(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(DsButton),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    return (decoration.border! as Border).top.color;
  }

  group('DsButton — scala a tre livelli', () {
    testWidgets('il secondario non ha sfondo proprio', (tester) async {
      // Sfondo opaco: dentro un dialog, il cui fondo è più chiaro della
      // surface, il bottone disegnava un rettangolo scuro attorno all'etichetta.
      await pumpButton(
        tester,
        variant: DsButtonVariant.secondary,
        onPressed: () {},
      );

      expect(backgroundOf(tester), Colors.transparent);
      expect(borderOf(tester), AppTheme.dark.colorScheme.primary);
    });

    testWidgets('il primario è a riempimento pieno', (tester) async {
      await pumpButton(
        tester,
        variant: DsButtonVariant.primary,
        onPressed: () {},
      );

      expect(backgroundOf(tester), AppTheme.dark.colorScheme.primary);
    });

    testWidgets('disabilitato perde l accento anche da secondario', (
      tester,
    ) async {
      // La regola dell'app: l'accento colorato c'è solo se il bottone si può
      // toccare. Un secondario disabilitato con il bordo arancione la
      // violerebbe.
      await pumpButton(tester, variant: DsButtonVariant.secondary);

      expect(borderOf(tester), AppTheme.dark.colorScheme.outline);
      expect(borderOf(tester), isNot(AppTheme.dark.colorScheme.primary));
    });
  });
}
