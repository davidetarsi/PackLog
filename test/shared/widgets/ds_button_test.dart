import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_opacity.dart';
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
    testWidgets('il secondario è pieno del fondo su cui sta', (tester) async {
      // Pieno: sopra la fascia di vetro il contenuto sfocato non si vede
      // dentro il bottone. Il fondo è quello della pagina.
      await pumpButton(
        tester,
        variant: DsButtonVariant.secondary,
        onPressed: () {},
      );

      expect(backgroundOf(tester), AppTheme.dark.scaffoldBackgroundColor);
      expect(borderOf(tester), AppTheme.dark.colorScheme.primary);
    });

    testWidgets('dentro un dialog prende il fondo del dialog', (tester) async {
      // Un fondo diverso da quello della pagina (dialog, gruppo): il bottone
      // non deve disegnare un rettangolo di un altro colore.
      const dialogColor = Color(0xFF334455);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: Material(
                color: dialogColor,
                child: DsButton(
                  label: 'Etichetta',
                  variant: DsButtonVariant.secondary,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(backgroundOf(tester), dialogColor);
    });

    testWidgets('lo spento è pieno del fondo, senza vetro', (tester) async {
      // Sul vetro il testo spento si perdeva: lo spento resta pieno.
      await pumpButton(tester, variant: DsButtonVariant.neutral);
      expect(backgroundOf(tester), AppTheme.dark.scaffoldBackgroundColor);
      expect(
        find.descendant(
          of: find.byType(DsButton),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
    });

    testWidgets('il primario è a riempimento pieno', (tester) async {
      await pumpButton(
        tester,
        variant: DsButtonVariant.primary,
        onPressed: () {},
      );

      expect(backgroundOf(tester), AppTheme.dark.colorScheme.primary);
    });

    testWidgets('neutral: contorno e testo senza arancio', (tester) async {
      await pumpButton(
        tester,
        variant: DsButtonVariant.neutral,
        onPressed: () {},
      );
      final scheme = AppTheme.dark.colorScheme;

      final label = tester.widget<Text>(
        find.descendant(
          of: find.byType(DsButton),
          matching: find.text('Etichetta'),
        ),
      );

      // Vetro come la barra delle tab: superficie semitrasparente sopra la
      // sfocatura di ciò che sta sotto.
      expect(
        backgroundOf(tester),
        scheme.surfaceContainer.withValues(alpha: AppOpacity.navGlass),
      );
      expect(
        find.descendant(
          of: find.byType(DsButton),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
      expect(borderOf(tester), scheme.outline);
      expect(borderOf(tester), isNot(scheme.primary));
      expect(label.style?.color, scheme.onSurface);
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
