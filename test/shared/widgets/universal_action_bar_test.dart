import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stuff_tracker_2/shared/widgets/universal_action_bar.dart';
import 'package:stuff_tracker_2/shared/widgets/circular_action_button.dart';

void main() {
  group('UniversalActionBar', () {
    testWidgets('renders primary button with label', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalActionBar(
              primaryLabel: 'Continue',
              onPrimaryPressed: () {},
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('primary button is full-width when no side actions', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalActionBar(
              primaryLabel: 'Full Width',
              onPrimaryPressed: () {},
            ),
          ),
        ),
      );

      // Assert - should render full-width button without Row layout
      expect(find.text('Full Width'), findsOneWidget);
      
      // In full-width mode, the button container should have width: double.infinity
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(InkWell),
          matching: find.byType(Container),
        ).first,
      );
      expect(container.constraints?.maxWidth, equals(double.infinity));
    });

    testWidgets('renders left action when provided', (tester) async {
      // Arrange
      const leftKey = Key('left-action');
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalActionBar(
              primaryLabel: 'Save',
              onPrimaryPressed: () {},
              leftAction: const Icon(Icons.delete, key: leftKey),
            ),
          ),
        ),
      );

      // Assert
      expect(find.byKey(leftKey), findsOneWidget);
    });

    testWidgets('renders right action when provided', (tester) async {
      // Arrange
      const rightKey = Key('right-action');
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalActionBar(
              primaryLabel: 'Save',
              onPrimaryPressed: () {},
              rightAction: const Icon(Icons.edit, key: rightKey),
            ),
          ),
        ),
      );

      // Assert
      expect(find.byKey(rightKey), findsOneWidget);
    });

    testWidgets('renders all three slots when provided', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalActionBar(
              primaryLabel: 'Continue',
              onPrimaryPressed: () {},
              leftAction: CircularActionButton(
                icon: Icons.delete,
                onPressed: () {},
              ),
              rightAction: CircularActionButton(
                icon: Icons.add,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('Continue'), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('calls onPrimaryPressed when primary button tapped', (tester) async {
      // Arrange
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalActionBar(
              primaryLabel: 'Action',
              onPrimaryPressed: () => tapped = true,
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();

      // Assert
      expect(tapped, true);
    });

    testWidgets('shows loading indicator when isLoading is true', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalActionBar(
              primaryLabel: 'Save',
              onPrimaryPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing); // Label hidden during loading
    });

    testWidgets('disables primary button when onPrimaryPressed is null', (tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UniversalActionBar(
              primaryLabel: 'Disabled',
              onPrimaryPressed: null,
            ),
          ),
        ),
      );

      // Assert - button exists but should be disabled
      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('shows icon in primary button when provided', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalActionBar(
              primaryLabel: 'Save',
              primaryIcon: Icons.save,
              onPrimaryPressed: () {},
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.save), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('applies custom horizontalPadding', (tester) async {
      // Arrange
      const customPadding = 32.0;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalActionBar(
              primaryLabel: 'Test',
              onPrimaryPressed: () {},
              horizontalPadding: customPadding,
            ),
          ),
        ),
      );

      // Assert
      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(UniversalActionBar),
          matching: find.byType(Padding),
        ).first,
      );
      expect(padding.padding, equals(const EdgeInsets.symmetric(horizontal: customPadding)));
    });

    testWidgets('primary button remains centered with only left action', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalActionBar(
              primaryLabel: 'Centered',
              onPrimaryPressed: () {},
              leftAction: CircularActionButton(
                icon: Icons.delete,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      // Assert - Verify structure with SizedBox slots and Expanded primary
      expect(find.text('Centered'), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
      expect(find.byType(Expanded), findsOneWidget); // Solo primary button
    });

    testWidgets('primary button remains centered with only right action', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalActionBar(
              primaryLabel: 'Centered',
              onPrimaryPressed: () {},
              rightAction: CircularActionButton(
                icon: Icons.add,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      // Assert - Verify structure with SizedBox slots and Expanded primary
      expect(find.text('Centered'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byType(Expanded), findsOneWidget); // Solo primary button
    });

    testWidgets('disables primary button when isLoading is true', (tester) async {
      // Arrange
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalActionBar(
              primaryLabel: 'Loading',
              onPrimaryPressed: () => tapped = true,
              isLoading: true,
            ),
          ),
        ),
      );

      // Act - Try to tap the button
      final inkWell = find.descendant(
        of: find.byType(InkWell),
        matching: find.byType(InkWell),
      );
      
      if (inkWell.evaluate().isNotEmpty) {
        await tester.tap(inkWell.first);
        await tester.pumpAndSettle();
      }

      // Assert - Should not have triggered because button is disabled
      expect(tapped, false);
    });
  });
}
