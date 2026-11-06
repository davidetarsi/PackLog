import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/view/widgets/slots/slot_widgets.dart';
import 'package:pack_log/shared/constants/app_constants.dart';
import 'package:pack_log/shared/theme/app_opacity.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/packlog_gradient.dart';

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

  testWidgets('bordo a gradiente sottile e tenue', (tester) async {
    await pump(tester, noAnimations: false);

    final border = tester.widget<PackLogGradientBorder>(
      find.byType(PackLogGradientBorder),
    );
    expect(border.width, AppConstants.hairlineBorderWidth);
    expect(border.restingOpacity, AppOpacity.subtleGradientBorder);
  });

  testWidgets('spiega il rapporto tra suggerimenti e inventario', (
    tester,
  ) async {
    await pump(tester, noAnimations: false);

    expect(find.text('trips.slots.proposed_inventory'), findsOneWidget);
    expect(find.text('trips.slots.proposed_header'), findsOneWidget);
    expect(find.text('Magliette'), findsOneWidget);
  });

  testWidgets('la spiegazione resta leggibile su uno schermo stretto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, noAnimations: false);

    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('trips.slots.proposed_inventory'),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('modifica e rimozione restano azioni distinte e riconoscibili', (
    tester,
  ) async {
    await pump(tester, noAnimations: false);
    final row = find.byKey(const Key('slot_row_u-magliette'));
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.chevron_right)),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('slot_not_useful_u-magliette')),
      findsOneWidget,
    );
    expect(find.text('trips.slots.proposed_edit_hint'), findsOneWidget);
  });

  testWidgets('la X è prima del nome, senza stella, e non apre la riga', (
    tester,
  ) async {
    var openCalls = 0;
    var removeCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ProposedSlotsCard(
            slots: const [_magliette],
            sorting: true,
            onOpen: (_) => openCalls++,
            onToggle: (_) {},
            onRemove: (_) => removeCalls++,
          ),
        ),
      ),
    );

    final row = find.byKey(const Key('slot_row_u-magliette'));
    expect(
      tester
          .getTopLeft(find.byKey(const Key('slot_not_useful_u-magliette')))
          .dx,
      lessThan(tester.getTopLeft(find.text('Magliette')).dx),
    );
    expect(
      find.descendant(of: row, matching: find.byType(PackLogSparkle)),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('slot_not_useful_u-magliette')));
    await tester.pump();
    expect(removeCalls, 1);
    expect(openCalls, 0);
  });
}
