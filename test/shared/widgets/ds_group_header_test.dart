import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_group_header.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );

  testWidgets('scrive nome, conteggio e dettaglio separati da un punto', (
    tester,
  ) async {
    await pump(
      tester,
      const DsGroupHeader(
        label: 'Temporanei',
        count: 4,
        detail: 'da Casa Milano',
      ),
    );
    expect(find.text('Temporanei · 4 · da Casa Milano'), findsOneWidget);
  });

  testWidgets('senza stato di apertura non mostra la freccetta', (
    tester,
  ) async {
    await pump(tester, const DsGroupHeader(label: 'Vestiti', count: 7));
    expect(find.byIcon(Icons.expand_less), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets('la freccetta segue lo stato e il tocco arriva', (tester) async {
    var taps = 0;
    await pump(
      tester,
      DsGroupHeader(
        label: 'Vestiti',
        count: 7,
        expanded: false,
        onTap: () => taps++,
      ),
    );
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    await tester.tap(find.text('Vestiti · 7'));
    expect(taps, 1);
  });

  testWidgets('il testo è grigio, non arancio', (tester) async {
    await pump(tester, const DsGroupHeader(label: 'Vestiti', count: 7));
    final text = tester.widget<Text>(find.text('Vestiti · 7'));
    expect(text.style?.color, AppTheme.light.colorScheme.onSurfaceVariant);
  });

  testWidgets('la variante in evidenza gerarchizza nome e conteggio', (
    tester,
  ) async {
    await pump(
      tester,
      const DsGroupHeader(label: 'Vestiti', count: 7, prominent: true),
    );

    final header = tester.widget<Text>(
      find.byKey(const Key('group_header_text')),
    );
    final spans = header.textSpan! as TextSpan;
    expect(spans.toPlainText(), 'Vestiti · 7');
    expect(spans.children![0].style?.fontSize, 16);
    expect(spans.children![1].style?.fontSize, 14);
    expect(
      spans.children![0].style?.color,
      AppTheme.light.colorScheme.onSurface,
    );
    expect(
      spans.children![1].style?.color,
      AppTheme.light.colorScheme.onSurfaceVariant,
    );
  });
}
