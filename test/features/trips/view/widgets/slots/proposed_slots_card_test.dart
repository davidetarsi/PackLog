import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/view/widgets/slots/slot_widgets.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

const _magliette = AiSlot(
  id: 'u-magliette',
  type: 'u-magliette',
  category: ItemCategory.vestiti,
  level: AiSlotLevel.useful,
  name: 'Magliette',
  copies: 5,
  remaining: 5,
  addLabel: 'Aggiungi la tua',
);

void main() {
  Future<void> pump(WidgetTester tester, {required bool noAnimations}) {
    return tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: noAnimations),
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ProposedSlotsCard(
              slots: const [_magliette],
              sorting: true,
              onOpen: (_) {},
              onToggle: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  Duration? resize(WidgetTester tester) =>
      tester.widget<Dismissible>(find.byType(Dismissible)).resizeDuration;

  testWidgets('scorrere una riga richiude lo spazio con un movimento', (
    tester,
  ) async {
    await pump(tester, noAnimations: false);
    expect(resize(tester), isNotNull);
  });

  testWidgets('con le animazioni disattivate lo spazio si chiude subito', (
    tester,
  ) async {
    await pump(tester, noAnimations: true);
    expect(resize(tester), isNull);
  });
}
