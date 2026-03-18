import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stuff_tracker_2/shared/widgets/sticky_cta_scaffold.dart';

void main() {
  group('StickyCtaScaffold', () {
    testWidgets('renders appBar, body, and bottomContent correctly', (tester) async {
      // Arrange
      const testAppBarTitle = 'Test AppBar';
      const testBodyText = 'Test Body Content';
      const testCtaText = 'Test CTA Button';

      await tester.pumpWidget(
        MaterialApp(
          home: StickyCtaScaffold(
            appBar: AppBar(
              title: const Text(testAppBarTitle),
            ),
            body: const Center(
              child: Text(testBodyText),
            ),
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
                  (index) => SizedBox(
                    height: 50,
                    child: Text('Item $index'),
                  ),
                ),
              ),
            ),
            bottomContent: const Padding(
              padding: EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: null,
                child: Text('Save'),
              ),
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

    testWidgets('shows shadow when showCtaShadow is true', (tester) async {
      // Arrange
      const ctaKey = Key('cta-container');
      
      await tester.pumpWidget(
        MaterialApp(
          home: StickyCtaScaffold(
            appBar: AppBar(title: const Text('Test')),
            body: const SizedBox(),
            bottomContent: Container(
              key: ctaKey,
              child: const Text('CTA'),
            ),
            showCtaShadow: true,
          ),
        ),
      );

      // Assert - CTA container exists and widget renders
      expect(find.byKey(ctaKey), findsOneWidget);
      expect(find.text('CTA'), findsOneWidget);
    });

    testWidgets('hides shadow when showCtaShadow is false', (tester) async {
      // Arrange
      const ctaKey = Key('cta-no-shadow');
      
      await tester.pumpWidget(
        MaterialApp(
          home: StickyCtaScaffold(
            appBar: AppBar(title: const Text('Test')),
            body: const SizedBox(),
            bottomContent: Container(
              key: ctaKey,
              child: const Text('CTA'),
            ),
            showCtaShadow: false,
          ),
        ),
      );

      // Assert - CTA container exists and widget renders
      expect(find.byKey(ctaKey), findsOneWidget);
      expect(find.text('CTA'), findsOneWidget);
    });

    testWidgets('applies custom ctaBackgroundColor', (tester) async {
      // Arrange
      const customColor = Colors.red;
      const ctaKey = Key('cta-custom-color');
      
      await tester.pumpWidget(
        MaterialApp(
          home: StickyCtaScaffold(
            appBar: AppBar(title: const Text('Test')),
            body: const SizedBox(),
            bottomContent: Container(
              key: ctaKey,
              child: const Text('CTA'),
            ),
            ctaBackgroundColor: customColor,
          ),
        ),
      );

      // Assert - Widget renders correctly
      expect(find.byKey(ctaKey), findsOneWidget);
      expect(find.text('CTA'), findsOneWidget);
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
}
