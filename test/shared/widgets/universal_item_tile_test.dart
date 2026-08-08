import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/shared/widgets/universal_item_tile.dart';

void main() {
  group('UniversalItemTile', () {
    testWidgets('renders title correctly', (tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: UniversalItemTile(title: Text('Test Item'))),
        ),
      );

      // Assert
      expect(find.text('Test Item'), findsOneWidget);
    });

    testWidgets('renders leading, title, and trailing in ListTile mode', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalItemTile(
              leading: const Icon(Icons.star, key: Key('leading-icon')),
              title: const Text('Item Name'),
              trailing: const Text('x3', key: Key('trailing-text')),
              useListTile: true,
            ),
          ),
        ),
      );

      // Assert
      expect(find.byKey(const Key('leading-icon')), findsOneWidget);
      expect(find.text('Item Name'), findsOneWidget);
      expect(find.byKey(const Key('trailing-text')), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UniversalItemTile(
              title: Text('Item Name'),
              subtitle: Text('Item Description'),
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('Item Name'), findsOneWidget);
      expect(find.text('Item Description'), findsOneWidget);
    });

    testWidgets('calls onTap when tile is tapped', (tester) async {
      // Arrange
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalItemTile(
              title: const Text('Tappable Item'),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Assert
      expect(tapped, true);
    });

    testWidgets('calls onLongPress when tile is long-pressed', (tester) async {
      // Arrange
      var longPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalItemTile(
              title: const Text('Long-pressable Item'),
              onLongPress: () => longPressed = true,
            ),
          ),
        ),
      );

      // Act
      await tester.longPress(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Assert
      expect(longPressed, true);
    });

    testWidgets('applies custom backgroundColor in flat row mode', (
      tester,
    ) async {
      // Arrange
      const customColor = Colors.red;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UniversalItemTile(
              title: Text('Colored Item'),
              backgroundColor: customColor,
            ),
          ),
        ),
      );

      // Assert: in modalità dense il colore vive sul Material, non su una Card
      expect(find.byType(Card), findsNothing);
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(UniversalItemTile),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, equals(customColor));
    });

    testWidgets('applies custom backgroundColor in card mode', (tester) async {
      // Arrange
      const customColor = Colors.red;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UniversalItemTile(
              title: Text('Colored Item'),
              backgroundColor: customColor,
              dense: false,
            ),
          ),
        ),
      );

      // Assert
      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color, equals(customColor));
    });

    testWidgets('dense row has no Card but a bottom divider', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: UniversalItemTile(title: Text('Flat Item'))),
        ),
      );

      expect(find.byType(Card), findsNothing);

      final decorated = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(UniversalItemTile),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final border = (decorated.decoration as BoxDecoration).border as Border;
      expect(border.bottom.style, BorderStyle.solid);
      expect(border.top, BorderSide.none);
    });

    testWidgets('borderColor forces the boxed layout even when dense', (
      tester,
    ) async {
      // Il bordo è semantico (selezione, riquadro bulk): dense non deve
      // mangiarselo.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UniversalItemTile(
              title: Text('Bordered Item'),
              borderColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('shows border when borderColor is provided', (tester) async {
      // Arrange
      const borderColor = Colors.blue;
      const borderWidth = 2.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UniversalItemTile(
              title: Text('Bordered Item'),
              borderColor: borderColor,
              borderWidth: borderWidth,
            ),
          ),
        ),
      );

      // Assert
      final card = tester.widget<Card>(find.byType(Card));
      expect(card.shape, isA<RoundedRectangleBorder>());
      final shape = card.shape as RoundedRectangleBorder;
      expect(shape.side.color, equals(borderColor));
      expect(shape.side.width, equals(borderWidth));
    });

    testWidgets('uses custom Row layout when useListTile is false', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalItemTile(
              leading: const Icon(Icons.star, key: Key('row-leading')),
              title: const Text('Row Mode'),
              trailing: const Icon(Icons.close, key: Key('row-trailing')),
              useListTile: false,
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(ListTile), findsNothing);
      expect(find.byKey(const Key('row-leading')), findsOneWidget);
      expect(find.text('Row Mode'), findsOneWidget);
      expect(find.byKey(const Key('row-trailing')), findsOneWidget);
    });

    testWidgets('renders subtitle in custom Row layout', (tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UniversalItemTile(
              title: Text('Title'),
              subtitle: Text('Subtitle in Row'),
              useListTile: false,
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Subtitle in Row'), findsOneWidget);
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('shows in-transit overlay when showInTransitOverlay is true', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UniversalItemTile(
              title: Text('Transit Item'),
              showInTransitOverlay: true,
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(Stack), findsWidgets);
      expect(find.byIcon(Icons.local_shipping), findsOneWidget);
    });

    testWidgets('does not show overlay when showInTransitOverlay is false', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UniversalItemTile(
              title: Text('Normal Item'),
              showInTransitOverlay: false,
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.local_shipping), findsNothing);
    });

    testWidgets('applies custom contentPadding', (tester) async {
      // Arrange
      const customPadding = EdgeInsets.all(24);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UniversalItemTile(
              title: Text('Padded Item'),
              contentPadding: customPadding,
              useListTile: true,
            ),
          ),
        ),
      );

      // Assert
      final listTile = tester.widget<ListTile>(find.byType(ListTile));
      expect(listTile.contentPadding, equals(customPadding));
    });

    testWidgets('applies custom margin in card mode', (tester) async {
      // Arrange
      const customMargin = EdgeInsets.all(16);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UniversalItemTile(
              title: Text('Margined Item'),
              margin: customMargin,
              dense: false,
            ),
          ),
        ),
      );

      // Assert
      final card = tester.widget<Card>(find.byType(Card));
      expect(card.margin, equals(customMargin));
    });

    testWidgets('applies custom margin in flat row mode', (tester) async {
      // Arrange
      const customMargin = EdgeInsets.all(16);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UniversalItemTile(
              title: Text('Margined Item'),
              margin: customMargin,
            ),
          ),
        ),
      );

      // Assert: senza Card il margine diventa il padding esterno della riga
      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(UniversalItemTile),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(padding.padding, equals(customMargin));
    });

    testWidgets('handles TextField as title in Row mode', (tester) async {
      // Arrange
      final controller = TextEditingController(text: 'Editable');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalItemTile(
              title: TextField(
                controller: controller,
                key: const Key('text-field'),
              ),
              useListTile: false,
            ),
          ),
        ),
      );

      // Assert
      expect(find.byKey(const Key('text-field')), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Cleanup
      controller.dispose();
    });
  });
}
