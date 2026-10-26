import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/constants/app_constants.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_choice_pill.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child, {ThemeData? theme}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: theme ?? AppTheme.light,
          home: Scaffold(body: Center(child: child)),
        ),
      );

  Finder face() => find.byKey(const Key('ds_choice_pill_face'));

  BoxDecoration decorationOf(WidgetTester tester) =>
      tester.widget<Container>(face()).decoration! as BoxDecoration;

  Color borderOf(WidgetTester tester) =>
      (decorationOf(tester).border! as Border).top.color;

  Color textColorOf(WidgetTester tester) =>
      tester.widget<Text>(find.text('Blu')).style!.color!;

  testWidgets('la faccia è alta pillTabCompact e non contiene icone', (
    tester,
  ) async {
    await pump(
      tester,
      DsChoicePill(label: 'Blu', selected: false, onTap: () {}),
    );
    expect(tester.getSize(face()).height, AppConstants.pillTabCompact);
    expect(
      find.descendant(
        of: find.byType(DsChoicePill),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
  });

  testWidgets('l’area di tocco è almeno kMinInteractiveDimension', (
    tester,
  ) async {
    await pump(
      tester,
      DsChoicePill(label: 'Blu', selected: false, onTap: () {}),
    );
    final tapArea = tester.getSize(
      find.descendant(
        of: find.byType(DsChoicePill),
        matching: find.byType(InkWell),
      ),
    );
    expect(tapArea.height, greaterThanOrEqualTo(kMinInteractiveDimension));
  });

  testWidgets('tema chiaro: scelta con bordo, testo e sfondo onSurface', (
    tester,
  ) async {
    final cs = AppTheme.light.colorScheme;
    await pump(
      tester,
      DsChoicePill(label: 'Blu', selected: true, onTap: () {}),
    );
    expect(borderOf(tester), cs.onSurface);
    expect(textColorOf(tester), cs.onSurface);
    expect(decorationOf(tester).color, cs.surfaceContainerHigh);
  });

  testWidgets(
    'tema chiaro: non scelta con bordo outlineVariant, testo onSurfaceVariant, senza sfondo',
    (tester) async {
      final cs = AppTheme.light.colorScheme;
      await pump(
        tester,
        DsChoicePill(label: 'Blu', selected: false, onTap: () {}),
      );
      expect(borderOf(tester), cs.outlineVariant);
      expect(textColorOf(tester), cs.onSurfaceVariant);
      expect(decorationOf(tester).color, isNull);
    },
  );

  testWidgets(
    'tema scuro: la scelta non ha sfondo, solo bordo e testo onSurface',
    (tester) async {
      final cs = AppTheme.dark.colorScheme;
      await pump(
        tester,
        DsChoicePill(label: 'Blu', selected: true, onTap: () {}),
        theme: AppTheme.dark,
      );
      expect(borderOf(tester), cs.onSurface);
      expect(textColorOf(tester), cs.onSurface);
      expect(decorationOf(tester).color, isNull);
    },
  );

  testWidgets(
    'tema scuro: non scelta con bordo outlineVariant e testo onSurfaceVariant',
    (tester) async {
      final cs = AppTheme.dark.colorScheme;
      await pump(
        tester,
        DsChoicePill(label: 'Blu', selected: false, onTap: () {}),
        theme: AppTheme.dark,
      );
      expect(borderOf(tester), cs.outlineVariant);
      expect(textColorOf(tester), cs.onSurfaceVariant);
      expect(decorationOf(tester).color, isNull);
    },
  );

  testWidgets('la semantica espone button e selected', (tester) async {
    await pump(
      tester,
      DsChoicePill(label: 'Blu', selected: true, onTap: () {}),
    );
    final semantics = tester.widget<Semantics>(
      find.descendant(
        of: find.byType(DsChoicePill),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.button == true,
        ),
      ),
    );
    expect(semantics.properties.selected, isTrue);
  });

  testWidgets('il tocco chiama onTap', (tester) async {
    var taps = 0;
    await pump(
      tester,
      DsChoicePill(label: 'Blu', selected: false, onTap: () => taps++),
    );
    await tester.tap(find.text('Blu'));
    expect(taps, 1);
  });

  testWidgets('l’etichetta è su una riga sola con ellissi', (tester) async {
    await pump(
      tester,
      const SizedBox(
        width: 80,
        child: DsChoicePill(
          label: 'Etichetta molto lunga che non entra',
          selected: false,
          onTap: null,
        ),
      ),
    );
    final text = tester.widget<Text>(
      find.text('Etichetta molto lunga che non entra'),
    );
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
