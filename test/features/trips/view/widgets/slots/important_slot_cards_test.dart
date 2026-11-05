import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/view/widgets/slots/slot_card_parts.dart';
import 'package:pack_log/features/trips/view/widgets/slots/slot_widgets.dart';
import 'package:pack_log/shared/constants/app_constants.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_text_button.dart';

const _giacca = AiSlot(
  id: 'imp-giacca',
  type: 'imp-giacca',
  category: ItemCategory.vestiti,
  level: AiSlotLevel.important,
  name: 'Giacca invernale',
  copies: 1,
  remaining: 1,
  reason: 'Fino a -7°.',
  addLabel: 'Aggiungi la tua',
);

/// Gli importanti sono "da fare": bordo ed etichetta in `primary`.
void main() {
  Future<void> pump(WidgetTester tester, {required ThemeData theme}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: ImportantSlotCard(slot: _giacca, onAdd: () {}, onToBuy: () {}),
        ),
      ),
    );
  }

  ColorScheme colors(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(ImportantSlotCard))).colorScheme;

  /// La forma della card: `Material` direttamente sotto `ImportantSlotCard`.
  ShapeBorder? cardShape(WidgetTester tester) => tester
      .widget<Material>(
        find
            .descendant(
              of: find.byType(ImportantSlotCard),
              matching: find.byType(Material),
            )
            .first,
      )
      .shape;

  Color labelColor(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(
          of: find.byType(ImportantLabel),
          matching: find.byType(Text),
        ),
      )
      .style!
      .color!;

  void expectOrangeBorder(WidgetTester tester) {
    final shape = cardShape(tester)! as RoundedRectangleBorder;
    expect(shape.side.color, colors(tester).primary);
    expect(shape.side.width, AppConstants.selectedBorderWidth);
    expect(
      shape.borderRadius,
      BorderRadius.circular(AppConstants.cardBorderRadius),
    );
  }

  for (final (name, theme) in [
    ('scuro', AppTheme.dark),
    ('chiaro', AppTheme.light),
  ]) {
    testWidgets('motivo completo ($name): leggibile su schermo stretto', (
      tester,
    ) async {
      const reason =
          'Il più simile che hai, Pantaloni neri, è troppo caldo per questo '
          'viaggio. Scegli un capo leggero e adatto alle attività previste.';
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 320,
                  child: ImportantSlotCard(
                    slot: _giacca.copyWith(reason: reason),
                    onAdd: () {},
                    onToBuy: () {},
                    onRemove: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final paragraph = tester.renderObject<RenderParagraph>(find.text(reason));
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('slot_add_imp-giacca')), findsOneWidget);
      expect(find.byKey(const Key('slot_to_buy_imp-giacca')), findsOneWidget);
    });

    testWidgets('importante ($name): bordo ed etichetta arancioni', (
      tester,
    ) async {
      await pump(tester, theme: theme);

      expectOrangeBorder(tester);
      expect(labelColor(tester), colors(tester).primary);
    });
  }

  testWidgets('Aggiungi accentato, Da comprare neutro', (tester) async {
    await pump(tester, theme: AppTheme.dark);

    DsTextButton button(String key) =>
        tester.widget<DsTextButton>(find.byKey(Key(key)));
    expect(button('slot_add_imp-giacca').accent, isTrue);
    expect(button('slot_to_buy_imp-giacca').accent, isFalse);
  });
}
