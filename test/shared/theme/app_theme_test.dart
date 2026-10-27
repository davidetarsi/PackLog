import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/constants/app_constants.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/theme/error_empty_theme_extension.dart';

/// Il textTheme di [AppTheme] è la fonte di verità tipografica dell'app: lo
/// usano ~66 call site che nessun altro test copre. Questi test bloccano le
/// tre cose che possono romperlo senza che nulla fallisca a runtime:
/// la scala, il floor di leggibilità e il merge sulla baseline Material 2021.
void main() {
  // Scala confermata: slot → (fontSize atteso, weight atteso).
  final expectedScale = <String, (double, FontWeight)>{
    'headlineLarge': (AppSpacing.fontHeading, FontWeight.w600), // 28
    'headlineSmall': (AppSpacing.fontTitle, FontWeight.w600), // 24
    'titleLarge': (AppSpacing.fontLg, FontWeight.w600), // 20
    'titleMedium': (AppSpacing.fontSm, FontWeight.w600), // 16
    'titleSmall': (AppSpacing.fontXs, FontWeight.w600), // 14
    'bodyLarge': (AppSpacing.fontSm, FontWeight.w400), // 16
    'bodyMedium': (AppSpacing.fontXs, FontWeight.w400), // 14
    'bodySmall': (AppSpacing.fontXxs, FontWeight.w400), // 12
    'labelLarge': (AppSpacing.fontXs, FontWeight.w500), // 14
    'labelMedium': (AppSpacing.fontXxs, FontWeight.w500), // 12
    'labelSmall': (AppSpacing.fontXxs, FontWeight.w600), // 12
  };

  TextStyle? slot(TextTheme t, String name) => switch (name) {
    'headlineLarge' => t.headlineLarge,
    'headlineSmall' => t.headlineSmall,
    'titleLarge' => t.titleLarge,
    'titleMedium' => t.titleMedium,
    'titleSmall' => t.titleSmall,
    'bodyLarge' => t.bodyLarge,
    'bodyMedium' => t.bodyMedium,
    'bodySmall' => t.bodySmall,
    'labelLarge' => t.labelLarge,
    'labelMedium' => t.labelMedium,
    'labelSmall' => t.labelSmall,
    _ => throw ArgumentError('slot sconosciuto: $name'),
  };

  /// Risolve il textTheme come lo vede un widget, cioè dopo il merge che
  /// ThemeData applica sulla baseline Material 2021.
  Future<TextTheme> resolvedTextTheme(WidgetTester tester, ThemeData theme) {
    late TextTheme resolved;
    return tester
        .pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                resolved = Theme.of(context).textTheme;
                return const SizedBox.shrink();
              },
            ),
          ),
        )
        .then((_) => resolved);
  }

  for (final (themeName, themeData) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    group('AppTheme.$themeName textTheme', () {
      testWidgets('ogni slot ha la size e il weight della scala confermata', (
        tester,
      ) async {
        final textTheme = await resolvedTextTheme(tester, themeData);

        for (final entry in expectedScale.entries) {
          final style = slot(textTheme, entry.key);
          final (expectedSize, expectedWeight) = entry.value;

          expect(
            style?.fontSize,
            expectedSize,
            reason: '${entry.key} deve essere ${expectedSize}px',
          );
          expect(
            style?.fontWeight,
            expectedWeight,
            reason: '${entry.key} deve essere $expectedWeight',
          );
        }
      });

      testWidgets('nessuno slot scende sotto il floor di 12px', (tester) async {
        final textTheme = await resolvedTextTheme(tester, themeData);

        for (final name in expectedScale.keys) {
          expect(
            slot(textTheme, name)!.fontSize,
            greaterThanOrEqualTo(AppSpacing.fontXxs),
            reason:
                '$name sotto il floor dichiarato da AppSpacing. '
                'M3 mette labelSmall a 11: va sovrascritto, non ereditato.',
          );
        }
      });

      testWidgets('il merge preserva le metriche M3 non dichiarate', (
        tester,
      ) async {
        final textTheme = await resolvedTextTheme(tester, themeData);

        // Dichiariamo solo fontSize e fontWeight: se qualcuno passasse a
        // costruire il TextTheme da zero, height e letterSpacing tornerebbero
        // null e la spaziatura verticale cambierebbe ovunque in silenzio.
        for (final name in expectedScale.keys) {
          final style = slot(textTheme, name)!;
          expect(style.height, isNotNull, reason: '$name ha perso height');
          expect(
            style.letterSpacing,
            isNotNull,
            reason: '$name ha perso letterSpacing',
          );
        }
      });

      testWidgets('i colori restano risolti per la brightness del tema', (
        tester,
      ) async {
        final textTheme = await resolvedTextTheme(tester, themeData);
        final isDark = themeData.brightness == Brightness.dark;

        for (final name in expectedScale.keys) {
          final color = slot(textTheme, name)!.color;
          expect(color, isNotNull, reason: '$name senza colore');
          // In dark il testo di default è chiaro, in light è scuro.
          expect(
            color!.computeLuminance() > 0.5,
            isDark,
            reason:
                '$name ha un colore incoerente con la brightness $themeName',
          );
        }
      });

      testWidgets('il titolo AppBar ha la size di titleLarge', (tester) async {
        final textTheme = await resolvedTextTheme(tester, themeData);

        expect(
          themeData.appBarTheme.titleTextStyle?.fontSize,
          textTheme.titleLarge?.fontSize,
        );
      });

      testWidgets('la barra in alto pesa come i titoli', (tester) async {
        expect(
          themeData.appBarTheme.titleTextStyle!.fontWeight,
          FontWeight.w700,
        );
      });
    });
  }

  group('fontScaleFactor', () {
    // La scala per larghezza è disattivata: i token valgono il numero che
    // dichiarano, altrimenti divergono dal textTheme (non scalabile perché
    // ThemeData si costruisce senza BuildContext).
    for (final width in [320.0, 360.0, 411.0, 768.0]) {
      testWidgets('resta 1.0 a ${width.toInt()}dp', (tester) async {
        late double factor;
        late double resolvedBodySize;

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: Size(width, 800)),
            child: MaterialApp(
              theme: AppTheme.light,
              home: Builder(
                builder: (context) {
                  factor = context.fontScaleFactor;
                  resolvedBodySize = context.fontSizeXs;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );

        expect(factor, 1.0);
        // Il token e lo slot equivalente devono coincidere su ogni device.
        expect(resolvedBodySize, AppSpacing.fontXs);
      });
    }
  });

  // Valori che il tema legge dai token: oggi coincidono con i numeri che
  // sostituiscono, quindi passano già. Servono a bloccare una regressione
  // silenziosa se un token cambia o un numero torna a mano.
  group('il tema usa i token', () {
    for (final (themeName, themeData) in [
      ('light', AppTheme.light),
      ('dark', AppTheme.dark),
    ]) {
      test('$themeName: il raggio del bottom sheet è modalBorderRadius', () {
        final shape =
            themeData.bottomSheetTheme.shape! as RoundedRectangleBorder;
        expect(
          shape.borderRadius,
          BorderRadius.vertical(
            top: Radius.circular(AppConstants.modalBorderRadius),
          ),
        );
      });

      test('$themeName: contentPadding dei campi è md × smPlus', () {
        expect(
          themeData.inputDecorationTheme.contentPadding,
          EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.smPlus,
          ),
        );
      });

      test('$themeName: l\'icona dello stato vuoto è iconDisplay', () {
        final ext = themeData.extension<ErrorEmptyThemeExtension>()!;
        expect(ext.emptyStateIconSize, AppSpacing.iconDisplay);
      });
    }
  });

  group('colori d\'errore', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final (hi, lo) = la > lb ? (la, lb) : (lb, la);
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final (name, theme) in [
      ('light', AppTheme.light),
      ('dark', AppTheme.dark),
    ]) {
      test('$name: errorContainer è un avviso, non il rosso pieno', () {
        final cs = theme.colorScheme;
        expect(cs.errorContainer, isNot(cs.error));
        expect(cs.onErrorContainer, isNot(cs.onError));
      });

      test('$name: testo su errorContainer sopra AA (4.5:1)', () {
        final cs = theme.colorScheme;
        expect(
          contrast(cs.onErrorContainer, cs.errorContainer),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });

  group('tema chiaro neutro', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final (hi, lo) = la > lb ? (la, lb) : (lb, la);
      return (hi + 0.05) / (lo + 0.05);
    }

    final cs = AppTheme.light.colorScheme;

    test('testo sui bottoni pieni sopra AA (4.5:1)', () {
      expect(contrast(cs.onPrimary, cs.primary), greaterThanOrEqualTo(4.5));
    });

    test('testo sui contenitori arancio sopra AA (4.5:1)', () {
      expect(
        contrast(cs.onPrimaryContainer, cs.primaryContainer),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('superfici e testi senza tinta: canali quasi uguali', () {
      for (final color in [
        cs.surface,
        cs.surfaceContainerLow,
        cs.surfaceContainer,
        cs.surfaceContainerHigh,
        cs.surfaceContainerHighest,
        cs.onPrimary,
        cs.onSurface,
        cs.onSurfaceVariant,
      ]) {
        final channels = [color.r, color.g, color.b];
        final spread =
            channels.reduce((a, b) => a > b ? a : b) -
            channels.reduce((a, b) => a < b ? a : b);
        expect(spread, lessThan(0.05), reason: '$color tira verso un colore');
      }
    });
  });
}
