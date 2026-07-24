import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/core/sync/sync_service.dart';
import 'package:pack_log/features/profile/widgets/sync_details_dialog.dart';

void main() {
  Widget wrap({required List<Override> overrides}) {
    return EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('it')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      saveLocale: false,
      child: ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SyncDetailsDialog.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('shows one row per entity type with count and friendly reason', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        overrides: [
          syncUnsyncedBreakdownProvider.overrideWith(
            (ref) async => const [
              SyncEntityStatus(
                entityLabelKey: 'houses.title',
                count: 2,
                reasonKey: 'profile.sync_reason_network',
              ),
              SyncEntityStatus(
                entityLabelKey: 'profile.sync_entity_items',
                count: 5,
                reasonKey: 'profile.sync_reason_unknown',
              ),
            ],
          ),
        ],
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('2'), findsWidgets);
    expect(find.textContaining('5'), findsWidgets);
  });

  testWidgets('closes when the close button is tapped', (tester) async {
    await tester.pumpWidget(
      wrap(
        overrides: [
          syncUnsyncedBreakdownProvider.overrideWith((ref) async => const []),
        ],
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('common.close'.tr()));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });
}
