import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stuff_tracker_2/shared/widgets/circular_action_button.dart';

void main() {
  group('CircularActionButton', () {
    testWidgets('renders icon correctly', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CircularActionButton(
              icon: Icons.delete,
              onPressed: () {},
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      // Arrange
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CircularActionButton(
              icon: Icons.add,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.byType(CircularActionButton));
      await tester.pumpAndSettle();

      // Assert
      expect(tapped, true);
    });

    testWidgets('is disabled when onPressed is null', (tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CircularActionButton(
              icon: Icons.edit,
              onPressed: null,
            ),
          ),
        ),
      );

      // Assert - button should exist but not be tappable
      expect(find.byType(CircularActionButton), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('applies custom color to icon', (tester) async {
      // Arrange
      const customColor = Colors.red;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CircularActionButton(
              icon: Icons.delete,
              onPressed: () {},
              color: customColor,
            ),
          ),
        ),
      );

      // Assert
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.delete));
      expect(iconWidget.color, equals(customColor));
    });

    testWidgets('applies custom backgroundColor', (tester) async {
      // Arrange
      const customBg = Colors.blue;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CircularActionButton(
              icon: Icons.star,
              onPressed: () {},
              backgroundColor: customBg,
            ),
          ),
        ),
      );

      // Assert
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(CircularActionButton),
          matching: find.byType(Material),
        ).first,
      );
      expect(material.color, equals(customBg));
    });

    testWidgets('hides border when showBorder is false', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CircularActionButton(
              icon: Icons.check,
              onPressed: () {},
              showBorder: false,
            ),
          ),
        ),
      );

      // Assert - Container should exist but with no border
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(CircularActionButton),
          matching: find.byType(Container),
        ),
      );
      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNull);
    });

    testWidgets('applies custom size', (tester) async {
      // Arrange
      const customSize = 72.0;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CircularActionButton(
              icon: Icons.favorite,
              onPressed: () {},
              size: customSize,
            ),
          ),
        ),
      );

      // Assert
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(CircularActionButton),
          matching: find.byType(Container),
        ),
      );
      expect(container.constraints, equals(const BoxConstraints.tightFor(width: customSize, height: customSize)));
    });

    testWidgets('shows reduced elevation when disabled', (tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CircularActionButton(
              icon: Icons.close,
              onPressed: null,
              elevation: 2,
            ),
          ),
        ),
      );

      // Assert - Material should have 0 elevation when disabled
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(CircularActionButton),
          matching: find.byType(Material),
        ).first,
      );
      expect(material.elevation, equals(0));
    });
  });
}
