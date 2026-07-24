import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/profile/widgets/sync_status_tile.dart';
import 'package:pack_log/shared/helpers/exception_message.dart';

void main() {
  Widget wrap(Widget child, {required List<Override> overrides}) {
    return EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('it')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      saveLocale: false,
      child: ProviderScope(
        overrides: overrides,
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('shows "synced" state when no pending changes', (tester) async {
    await tester.pumpWidget(
      wrap(
        const SyncStatusTile(),
        overrides: [totalUnsyncedCountProvider.overrideWith((ref) async => 0)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    // No retry button when synced.
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('shows pending count and retry button when there are changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const SyncStatusTile(),
        overrides: [totalUnsyncedCountProvider.overrideWith((ref) async => 3)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    expect(
      find.byType(TextButton),
      findsOneWidget,
      reason: 'retry button must be visible when there are pending changes',
    );
  });

  testWidgets('error state usa exceptionMessage, non e.toString()', (
    tester,
  ) async {
    final err = Exception('raw-technical-detail');
    await tester.pumpWidget(
      wrap(
        const SyncStatusTile(),
        overrides: [
          totalUnsyncedCountProvider.overrideWith((ref) => Future.error(err)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    // exceptionMessage(err) è calcolabile qui: dopo pumpWidget la
    // Localization di easy_localization è inizializzata.
    expect(find.text(exceptionMessage(err)), findsOneWidget);
  });

  testWidgets('tapping the tile opens SyncDetailsDialog when there are pending changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const SyncStatusTile(),
        overrides: [
          totalUnsyncedCountProvider.overrideWith((ref) async => 2),
          syncUnsyncedBreakdownProvider.overrideWith((ref) async => const []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Tapped via the leading icon rather than the ListTile's bounding-box
    // center: with an unresolved (raw-key) translation the trailing retry
    // TextButton renders wide enough to visually cover the ListTile's
    // geometric center in this test harness, which would make a
    // center-point tap land on the retry button's onPressed instead of the
    // tile's own onTap.
    await tester.tap(find.byIcon(Icons.cloud_upload_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('tile is not tappable when fully synced (no dialog opens)', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const SyncStatusTile(),
        overrides: [totalUnsyncedCountProvider.overrideWith((ref) async => 0)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });
}
