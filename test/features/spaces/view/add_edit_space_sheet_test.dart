import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/spaces/model/space_model.dart';
import 'package:pack_log/features/spaces/providers/space_provider.dart';
import 'package:pack_log/features/spaces/view/add_edit_space_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../screenshots/support/harness.dart';
import '../../../screenshots/support/seed.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    useSystemSqlite();
  });

  testWidgets('invio dalla tastiera salva lo spazio', (tester) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.dark);
    // Il foglio restituisce il modello salvato: si legge a fine test, senza
    // attendere il future, così un salvataggio mancato fallisce invece di
    // bloccare la suite.
    SpaceModel? result;
    unawaited(
      showAddEditSpaceSheet(
        tester.element(find.byType(Scaffold).last),
        houseId: kEmptyHouseId,
      ).then((model) => result = model),
    );
    await app.settle();

    await app.enterText(
      find.byKey(const Key('space_sheet_name')),
      'Ripostiglio',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await app.settle();

    expect(result?.name, 'Ripostiglio');
    final spaces = await tester.runAsync(
      () => app.container.read(spaceNotifierProvider(kEmptyHouseId).future),
    );
    expect(spaces!.map((s) => s.name), contains('Ripostiglio'));
    await app.finish();
  });
}
