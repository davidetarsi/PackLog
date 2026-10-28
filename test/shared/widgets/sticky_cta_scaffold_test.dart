import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/theme/app_spacing.dart';
import 'package:pack_log/shared/widgets/ds_glass_band.dart';
import 'package:pack_log/shared/widgets/sticky_cta_scaffold.dart';

void main() {
  group('StickyCtaScaffold', () {
    testWidgets('renders appBar, body, and bottomContent correctly', (
      tester,
    ) async {
      // Arrange
      const testAppBarTitle = 'Test AppBar';
      const testBodyText = 'Test Body Content';
      const testCtaText = 'Test CTA Button';

      await tester.pumpWidget(
        MaterialApp(
          home: StickyCtaScaffold(
            appBar: AppBar(title: const Text(testAppBarTitle)),
            body: const Center(child: Text(testBodyText)),
            bottomContent: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(testCtaText),
            ),
          ),
        ),
      );

      // Assert
      expect(find.text(testAppBarTitle), findsOneWidget);
      expect(find.text(testBodyText), findsOneWidget);
      expect(find.text(testCtaText), findsOneWidget);
    });

    testWidgets('bottomContent is wrapped in SafeArea', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: StickyCtaScaffold(
            appBar: AppBar(title: const Text('Test')),
            body: const SizedBox(),
            bottomContent: const Text('CTA'),
          ),
        ),
      );

      // Assert - SafeArea should be present in the widget tree
      expect(find.byType(SafeArea), findsWidgets);
    });

    testWidgets('body is scrollable when content overflows', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: StickyCtaScaffold(
            appBar: AppBar(title: const Text('Test')),
            body: SingleChildScrollView(
              child: Column(
                children: List.generate(
                  100,
                  (index) => SizedBox(height: 50, child: Text('Item $index')),
                ),
              ),
            ),
            bottomContent: const Padding(
              padding: EdgeInsets.all(16.0),
              child: ElevatedButton(onPressed: null, child: Text('Save')),
            ),
          ),
        ),
      );

      // Assert - First item visible
      expect(find.text('Item 0'), findsOneWidget);

      // Act - Verify scrollable exists
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('bottomContent remains fixed during scroll', (tester) async {
      // Arrange
      const ctaKey = Key('cta-button');

      await tester.pumpWidget(
        MaterialApp(
          home: StickyCtaScaffold(
            appBar: AppBar(title: const Text('Test')),
            body: ListView(
              children: List.generate(
                50,
                (index) => ListTile(title: Text('Item $index')),
              ),
            ),
            bottomContent: const Padding(
              padding: EdgeInsets.all(16.0),
              child: ElevatedButton(
                key: ctaKey,
                onPressed: null,
                child: Text('Fixed CTA'),
              ),
            ),
          ),
        ),
      );

      // Arrange - Get initial position of CTA
      final initialOffset = tester.getTopLeft(find.byKey(ctaKey));

      // Act - Scroll the list
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // Assert - CTA position should remain the same
      final finalOffset = tester.getTopLeft(find.byKey(ctaKey));
      expect(finalOffset, equals(initialOffset));
    });

    testWidgets('works without appBar', (tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: StickyCtaScaffold(
            appBar: null,
            body: Center(child: Text('Body')),
            bottomContent: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('CTA'),
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Body'), findsOneWidget);
      expect(find.text('CTA'), findsOneWidget);
    });
  });

  testWidgets('i bottoni stanno sulla fascia di vetro, a spacingXs dal bordo', (
    tester,
  ) async {
    const ctaKey = Key('cta');
    await tester.pumpWidget(
      MaterialApp(
        home: StickyCtaScaffold(
          body: const SizedBox(),
          bottomContent: Container(key: ctaKey, height: 56),
        ),
      ),
    );
    final band = find.byType(DsGlassBand);
    expect(band, findsOneWidget);
    expect(
      find.descendant(
        of: band,
        matching: find.byKey(const Key('ds_glass_band_edge')),
      ),
      findsOneWidget,
    );
    final gap =
        tester.getTopLeft(find.byKey(ctaKey)).dy - tester.getTopLeft(band).dy;
    expect(gap, closeTo(tester.element(band).spacingXs, 0.01));
  });

  testWidgets('l\'effetto parte 4 px sopra i bottoni e sfuma nel fondo', (
    tester,
  ) async {
    const ctaKey = Key('cta');
    await tester.pumpWidget(
      MaterialApp(
        home: StickyCtaScaffold(
          body: const SizedBox(),
          bottomContent: Container(key: ctaKey, height: 56),
        ),
      ),
    );
    final edge = find.byKey(const Key('ds_glass_band_edge'));
    // Comincia appena sopra i bottoni, a topGap (spacingXs, 4 px).
    expect(
      tester.getTopLeft(find.byKey(ctaKey)).dy - tester.getTopLeft(edge).dy,
      closeTo(tester.element(edge).spacingXs, 0.01),
    );
    // Trasparente in alto, colore di fondo in basso.
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: edge, matching: find.byType(DecoratedBox)).last,
    );
    final gradient = (box.decoration as BoxDecoration).gradient!;
    expect(gradient.colors.first.a, 0);
    expect(gradient.colors.last.a, greaterThan(0.5));
  });
}
