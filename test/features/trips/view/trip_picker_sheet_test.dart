import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/shared/widgets/ds_form_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../screenshots/support/harness.dart';
import '../../../screenshots/support/seed.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    useSystemSqlite();
  });

  Future<ScreenshotApp> openPicker(WidgetTester tester) async {
    final app = await ScreenshotApp.start(tester, theme: ShotTheme.light);
    await app.push('/houses/$kHomeId');
    await app.longPress(find.text('Maglione di lana'));
    await app.tap(find.byKey(const Key('selection_trip')));
    return app;
  }

  testWidgets('elenca solo i viaggi non conclusi, nel foglio del DS', (
    tester,
  ) async {
    final app = await openPicker(tester);

    expect(find.byType(DsFormSheet), findsOneWidget);
    expect(
      find.byKey(const Key('trip_picker_$kUpcomingTripId')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('trip_picker_$kActiveTripId')), findsOneWidget);
    expect(find.byKey(const Key('trip_picker_$kPastTripId')), findsNothing);
    await app.finish();
  });

  testWidgets('toccare un viaggio ci aggiunge gli oggetti scelti', (
    tester,
  ) async {
    final app = await openPicker(tester);

    await app.tap(find.byKey(const Key('trip_picker_$kUpcomingTripId')));

    expect(find.byType(DsFormSheet), findsNothing);
    final trips = await tester.runAsync(
      () => app.container.read(tripNotifierProvider.future),
    );
    expect(
      trips!
          .firstWhere((t) => t.id == kUpcomingTripId)
          .items
          .any((item) => item.name == 'Maglione di lana'),
      isTrue,
    );
    await app.finish();
  });
}
