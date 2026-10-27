import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/model/trip_model.dart';
import 'package:pack_log/features/trips/view/widgets/pack/pack_summary_line.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/memory_asset_loader.dart';

const _it = Locale('it', 'IT');
const _en = Locale('en', 'US');

TripModel _viaggio({DateTime? departure, DateTime? returnAt}) {
  return TripModel(
    id: 'v1',
    name: 'Viaggio',
    departureDateTime: departure,
    returnDateTime: returnAt,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    isSaved: false,
    items: const [],
    legs: const [],
  );
}

/// Monta EasyLocalization in italiano, così `.plural()` e `.tr()` restituiscono
/// il testo vero e non la chiave.
Future<void> _pumpLocalization(WidgetTester tester) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [_it, _en],
      path: 'assets/translations',
      assetLoader: MemoryAssetLoader(readAppTranslations()),
      fallbackLocale: _en,
      startLocale: _it,
      saveLocale: false,
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: const SizedBox(),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('tripStampLabel: niente per un viaggio finito', (tester) async {
    await _pumpLocalization(tester);
    final ieri = DateTime.now().subtract(const Duration(days: 1));
    final viaggio = _viaggio(
      departure: ieri.subtract(const Duration(days: 4)),
      returnAt: ieri,
    );

    expect(tripStampLabel(viaggio), isNull);
  });

  testWidgets('tripStampLabel: giorni per un viaggio futuro', (tester) async {
    await _pumpLocalization(tester);
    final viaggio = _viaggio(
      departure: DateTime.now().add(const Duration(days: 9)),
      returnAt: DateTime.now().add(const Duration(days: 12)),
    );

    final label = tripStampLabel(viaggio);

    expect(label, isNotNull);
    expect(label, contains('9'));
    expect(label, isNot(contains('--')));
  });
}
