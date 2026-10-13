import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/items/model/item_model.dart';
import 'package:pack_log/features/items/widgets/category_pill.dart';
import 'package:pack_log/features/items/widgets/rapid_fire_input.dart';
import 'package:pack_log/shared/theme/app_theme.dart';

void main() {
  testWidgets(
    'input espanso: la riga delle categorie non sfora su spazio stretto',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  // 412 - 2×120 = 172 dp utili. Nell'app reale l'overflow
                  // compariva a 412 dp con i font veri (15 px, vedi manifest degli
                  // screenshot); col font di test serve meno spazio per vederlo.
                  // Sul codice prima del fix questa larghezza sforava di 116 px.
                  padding: EdgeInsets.symmetric(horizontal: 120),
                  child: RapidFireInput(houseId: 'h1'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(
        find.byType(CategoryPill),
        findsNWidgets(ItemCategory.values.length),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('autofocus: si apre già espanso con la tastiera', (tester) async {
    var expanded = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RapidFireInput(
                houseId: 'h1',
                autofocus: true,
                onExpandedChanged: (v) => expanded = v,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode?.hasFocus, isTrue);
    expect(expanded, isTrue);
    expect(
      find.byType(CategoryPill),
      findsNWidgets(ItemCategory.values.length),
    );
  });
}
