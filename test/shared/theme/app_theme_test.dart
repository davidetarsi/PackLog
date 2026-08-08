import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

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

      testWidgets('il titolo AppBar pesa quanto titleLarge', (tester) async {
        final textTheme = await resolvedTextTheme(tester, themeData);

        expect(
          themeData.appBarTheme.titleTextStyle?.fontSize,
          textTheme.titleLarge?.fontSize,
        );
        expect(
          themeData.appBarTheme.titleTextStyle?.fontWeight,
          textTheme.titleLarge?.fontWeight,
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
}
