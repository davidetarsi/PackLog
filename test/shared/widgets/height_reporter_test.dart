import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/widgets/height_reporter.dart';

void main() {
  testWidgets('riporta l\'altezza dopo il primo layout', (tester) async {
    final heights = <double>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: HeightReporter(
            onHeightChanged: heights.add,
            child: const SizedBox(width: 10, height: 40),
          ),
        ),
      ),
    );
    expect(heights, [40.0]);
  });

  testWidgets('richiama solo quando l\'altezza cambia, non a ogni frame', (
    tester,
  ) async {
    final heights = <double>[];
    late StateSetter setHeight;
    var h = 40.0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: StatefulBuilder(
            builder: (context, setState) {
              setHeight = setState;
              return HeightReporter(
                onHeightChanged: heights.add,
                child: SizedBox(width: 10, height: h),
              );
            },
          ),
        ),
      ),
    );
    expect(heights, [40.0]);

    // Frame ripetuti e rebuild con la stessa altezza: nessuna chiamata.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    setHeight(() {});
    await tester.pump();
    expect(heights, [40.0]);

    setHeight(() => h = 64);
    await tester.pump();
    expect(heights, [40.0, 64.0]);

    await tester.pump();
    expect(heights, [40.0, 64.0]);
  });

  testWidgets('non richiama dopo la rimozione dall\'albero', (tester) async {
    final heights = <double>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: HeightReporter(
            onHeightChanged: heights.add,
            child: const SizedBox(height: 20),
          ),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    expect(heights, [20.0]);
  });
}
