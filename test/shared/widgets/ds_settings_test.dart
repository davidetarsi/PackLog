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

  testWidgets('riga con controllo: niente chevron', (tester) async {
    await pump(
      tester,
      const DsSettingsRow(label: 'Quantità', trailing: Text('7')),
    );
    expect(find.text('7'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
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
