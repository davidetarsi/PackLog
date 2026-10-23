import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/houses/view/add_edit_house_screen.dart';
import 'package:pack_log/shared/model/location_suggestion_model.dart';
import 'package:pack_log/shared/model/location_type.dart';
import 'package:pack_log/shared/services/location_search_service.dart';
import 'package:pack_log/shared/widgets/location_result_row.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../screenshots/support/harness.dart';

class _Search extends LocationSearchService {
  bool fails = true;
  @override
  Future<List<LocationSuggestionModel>> search(
    String query, {
    required String lang,
  }) async {
    if (fails) throw const GeocodeSearchException();
    return [
      LocationSuggestionModel(
        placeId: 'rome',
        displayName: 'Roma, Italia',
        name: 'Roma',
        locationType: LocationType.city,
      ),
    ];
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    useSystemSqlite();
  });
  for (final isTrip in [true, false]) {
    testWidgets(
      'ricerca ${isTrip ? "viaggio" : "casa"}: distingue errore da zero risultati e riprova',
      (tester) async {
        final service = _Search();
        final app = await ScreenshotApp.start(
          tester,
          theme: ShotTheme.light,
          setup: AppSetup(
            extraOverrides: [
              locationSearchServiceProvider.overrideWithValue(service),
            ],
          ),
        );
        if (isTrip) {
          await app.push('/new-trip');
        } else {
          showAddEditHouseSheet(tester.element(find.byType(Scaffold).last));
          await app.settle();
        }
        final field = find.descendant(
          of: find.byKey(
            Key(isTrip ? 'new_trip_place_search' : 'house_sheet_location'),
          ),
          matching: find.byType(TextField),
        );
        await app.enterText(field, 'Roma');
        await tester.pump(const Duration(milliseconds: 350));
        await app.settle();
        expect(find.text('location_search.failed'.tr()), findsOneWidget);
        expect(find.text('location_search.no_results'.tr()), findsNothing);
        service.fails = false;
        await app.tap(find.text('Riprova'));
        expect(find.byType(LocationResultRow), findsOneWidget);
        expect(find.text('location_search.failed'.tr()), findsNothing);
        await app.finish();
      },
    );
  }
}
