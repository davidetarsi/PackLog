import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/profile/widgets/sync_status_tile.dart';

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
    expect(find.bySubtype<TextButton>(), findsNothing);
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
      find.bySubtype<TextButton>(),
      findsOneWidget,
      reason: 'retry button must be visible when there are pending changes',
    );
  });

  testWidgets('errore di lettura offre Riprova senza dettagli tecnici', (
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
    expect(find.textContaining('raw-technical-detail'), findsNothing);
    expect(find.text('common.retry'.tr()), findsOneWidget);
  });

  testWidgets(
    'tapping the tile opens SyncDetailsDialog when there are pending changes',
    (tester) async {
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

      // Si tocca l'etichetta, non il centro della riga: a destra c'è il
      // bottone "Riprova", che ha un suo onPressed.
      await tester.tap(find.text('profile.sync_status_title'.tr()));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );

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
