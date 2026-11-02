import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/suitcase_progress.dart';
import 'package:pack_log/features/trips/view/widgets/slots/suitcase_progress_header.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

/// La testata usa la regola dei colori: gli importanti da fare sono
/// `primary` (arancione), i proposti `tertiary`, le tue cose neutre.
void main() {
  Future<void> pump(WidgetTester tester, SuitcaseProgress progress) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: SuitcaseProgressHeader(progress: progress)),
      ),
    );
  }

  ColorScheme colors(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(SuitcaseProgressHeader))).colorScheme;

  const sorting = SuitcaseProgress(
    mine: 9,
    proposed: 3,
    importantOpen: 2,
    checked: 0,
  );

  testWidgets('segmento importanti arancione nella barra', (tester) async {
    await pump(tester, sorting);

    final segments = tester.widgetList<ColoredBox>(
      find.descendant(
        of: find.byKey(const Key('trip_detail_ready_progress')),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(segments.map((s) => s.color), contains(colors(tester).primary));
  });

  testWidgets('pallino importanti pieno arancione, senza bordo', (
    tester,
  ) async {
    await pump(tester, sorting);

    final entry = find.ancestor(
      of: find.text('trips.detail.legend_important'),
      matching: find.byType(Row),
    );
    final dot = tester.widget<Container>(
      find.descendant(of: entry.first, matching: find.byType(Container)).first,
    );
    final decoration = dot.decoration! as BoxDecoration;
    expect(decoration.color, colors(tester).primary);
    expect(decoration.border, isNull);
  });

  testWidgets('senza importanti aperti niente barra delle origini', (
    tester,
  ) async {
    await pump(
      tester,
      const SuitcaseProgress(
        mine: 9,
        proposed: 3,
        importantOpen: 0,
        checked: 0,
      ),
    );

    expect(find.byKey(const Key('trip_detail_ready_progress')), findsNothing);
    expect(find.byKey(const Key('trip_detail_progress')), findsOneWidget);
  });
}
