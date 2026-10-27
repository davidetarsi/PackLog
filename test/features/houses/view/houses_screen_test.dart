import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/auth/auth_provider.dart';
import 'package:pack_log/core/auth/auth_state.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/houses/model/house_model.dart';
import 'package:pack_log/features/houses/providers/house_provider.dart';
import 'package:pack_log/features/houses/providers/house_stats_provider.dart';
import 'package:pack_log/features/houses/view/houses_screen.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/memory_asset_loader.dart';

/// Senza Supabase inizializzato l'avatar della tab header non si costruisce.
class _SignedOutAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.unauthenticated();
}

class _FakeHouseNotifier extends HouseNotifier {
  _FakeHouseNotifier(this.houses);
  final List<HouseModel> houses;

  @override
  Future<List<HouseModel>> build() async => houses;
}

const _houseId = 'casa-test';

HouseModel _house({required String name, bool primary = false}) => HouseModel(
  id: _houseId,
  name: name,
  description: 'Via Roma 1',
  isPrimary: primary,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  /// Monta [HousesScreen] con una sola casa e statistiche finte (7 oggetti).
  Future<void> pumpHouses(
    WidgetTester tester, {
    required HouseModel house,
    double textScale = 1.0,
  }) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US'), Locale('it', 'IT')],
        path: 'assets/translations',
        assetLoader: MemoryAssetLoader(readAppTranslations()),
        fallbackLocale: const Locale('en', 'US'),
        startLocale: const Locale('it', 'IT'),
        saveLocale: false,
        child: ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(_SignedOutAuth.new),
            totalUnsyncedCountProvider.overrideWith((ref) async => 0),
            houseNotifierProvider.overrideWith(
              () => _FakeHouseNotifier([house]),
            ),
            houseStatsProvider(_houseId).overrideWith(
              (ref) async => const HouseStats(
                totalItems: 7,
                hasItemsInTrip: false,
                hasTemporaryItems: false,
              ),
            ),
          ],
          child: Builder(
            builder: (context) => MaterialApp(
              theme: AppTheme.light,
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: const HousesScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('card della casa: nome 18, luogo 16, conteggio 14', (
    tester,
  ) async {
    await pumpHouses(tester, house: _house(name: 'Casa al mare'));

    double fontSizeOf(String text) =>
        tester.widget<Text>(find.text(text)).style!.fontSize!;

    expect(fontSizeOf('Casa al mare'), 18);
    expect(fontSizeOf('Via Roma 1'), 16);
    expect(fontSizeOf('houses.total_items'.tr(args: ['7'])), 14);
  });

  testWidgets('nome lungo con testo a 2.0: niente overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpHouses(
      tester,
      house: _house(name: 'Casa '.padRight(80, 'x'), primary: true),
      textScale: 2.0,
    );

    expect(tester.takeException(), isNull);
  });
}
