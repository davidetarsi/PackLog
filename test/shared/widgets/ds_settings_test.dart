import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_settings.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child, {ThemeData? theme}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: theme ?? AppTheme.light,
          home: Scaffold(body: child),
        ),
      );

  testWidgets('riga con valore toccabile: valore e chevron', (tester) async {
    var taps = 0;
    await pump(
      tester,
      DsSettingsRow(label: 'Categoria', value: 'Vestiti', onTap: () => taps++),
    );
    expect(find.text('Categoria'), findsOneWidget);
    expect(find.text('Vestiti'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('Vestiti'));
    expect(taps, 1);
  });

  testWidgets('valore senza onTap: niente chevron', (tester) async {
    await pump(
      tester,
      const DsSettingsRow(label: 'Categoria', value: 'Vestiti'),
    );
    expect(find.text('Vestiti'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('trailing prevale su value', (tester) async {
    await pump(
      tester,
      const DsSettingsRow(
        label: 'Quantità',
        value: 'ignorato',
        trailing: Text('7'),
      ),
    );
    expect(find.text('7'), findsOneWidget);
    expect(find.text('ignorato'), findsNothing);
  });

  testWidgets('valore lunghissimo: tronca senza eccezioni e lascia leggibile '
      'l\'etichetta', (tester) async {
    await pump(
      tester,
      DsSettingsRow(label: 'Spazio', value: 'A' * 200, onTap: () {}),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Spazio'), findsOneWidget);
    expect(tester.getSize(find.text('Spazio')).width, greaterThan(0));
  });

  testWidgets('riga con controllo: niente chevron', (tester) async {
    await pump(
      tester,
      const DsSettingsRow(label: 'Quantità', trailing: Text('7')),
    );
    expect(find.text('7'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('destructive colora etichetta e icona di errore', (tester) async {
    await pump(
      tester,
      DsSettingsRow(
        label: 'Elimina',
        leading: const Icon(Icons.delete_outline),
        destructive: true,
        onTap: () {},
      ),
    );
    final cs = AppTheme.light.colorScheme;
    expect(tester.widget<Text>(find.text('Elimina')).style?.color, cs.error);
    expect(
      IconTheme.of(tester.element(find.byIcon(Icons.delete_outline))).color,
      cs.error,
    );
  });

  testWidgets('enabled false: niente tocco e colore spento', (tester) async {
    var taps = 0;
    await pump(
      tester,
      DsSettingsRow(
        label: 'Spento',
        leading: const Icon(Icons.lock_outline),
        enabled: false,
        onTap: () => taps++,
      ),
    );
    await tester.tap(find.text('Spento'));
    expect(taps, 0);

    final off = AppTheme.light.colorScheme.onSurface.withValues(alpha: 0.38);
    expect(tester.widget<Text>(find.text('Spento')).style?.color, off);
    expect(
      IconTheme.of(tester.element(find.byIcon(Icons.lock_outline))).color,
      off,
    );
  });

  testWidgets('il gruppo mette una linea tra le righe, non prima né dopo', (
    tester,
  ) async {
    await pump(
      tester,
      const DsSettingsGroup(
        children: [
          DsSettingsRow(label: 'A', value: '1'),
          DsSettingsRow(label: 'B', value: '2'),
          DsSettingsRow(label: 'C', value: '3'),
        ],
      ),
    );
    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('sfondo bianco in chiaro, grigio in scuro', (tester) async {
    Color groupColor() => tester
        .widget<Material>(
          find
              .descendant(
                of: find.byType(DsSettingsGroup),
                matching: find.byType(Material),
              )
              .first,
        )
        .color!;

    await pump(tester, const DsSettingsGroup(children: [SizedBox()]));
    expect(groupColor(), AppTheme.light.colorScheme.surfaceContainerLowest);

    await pump(
      tester,
      const DsSettingsGroup(children: [SizedBox()]),
      theme: AppTheme.dark,
    );
    // Material anima il cambio di colore quando cambia il tema.
    await tester.pumpAndSettle();
    expect(groupColor(), AppTheme.dark.colorScheme.surfaceContainer);
  });
}
