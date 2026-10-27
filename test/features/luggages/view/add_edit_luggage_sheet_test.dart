import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/luggages/model/luggage_model.dart';
import 'package:pack_log/features/luggages/providers/luggage_provider.dart';
import 'package:pack_log/features/luggages/view/add_edit_luggage_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../screenshots/support/harness.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    useSystemSqlite();
  });

  testWidgets('invio dalla tastiera salva il bagaglio', (tester) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.dark);
    // Il foglio restituisce il modello salvato: si legge a fine test, senza
    // attendere il future, così un salvataggio mancato fallisce invece di
    // bloccare la suite.
    LuggageModel? result;
    unawaited(
      showAddEditLuggageSheet(
        tester.element(find.byType(Scaffold).last),
      ).then((model) => result = model),
    );
    await app.settle();

    await app.enterText(
      find.byKey(const Key('luggage_sheet_name')),
      'Zaino Blu',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await app.settle();

    expect(result?.name, 'Zaino Blu');
    final luggages = await tester.runAsync(
      () => app.container.read(luggageNotifierProvider.future),
    );
    expect(luggages!.map((l) => l.name), contains('Zaino Blu'));
    await app.finish();
  });
}
