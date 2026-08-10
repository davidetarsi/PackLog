import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:pack_log/features/auth/view/login_screen.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';

void main() {
  // The analytics service is the concrete `AppAnalyticsService`; constructing
  // it with a null Amplitude instance makes logEvent/identifyUser safe no-ops
  // (see analytics_service.dart) — no fake/mock needed.
  Widget wrap() => EasyLocalization(
    supportedLocales: const [Locale('en'), Locale('it')],
    path: 'assets/translations',
    fallbackLocale: const Locale('en'),
    saveLocale: false,
    child: ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(AppAnalyticsService(null)),
      ],
      child: const MaterialApp(home: LoginScreen()),
    ),
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('senza consenso il tocco dice cosa manca', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Il bottone resta toccabile anche senza consenso: spento non diceva
    // *perché*, e la casella sotto passava inosservata.
    final buttonFinder = find.byType(DsButton);
    final button = tester.widget<DsButton>(buttonFinder);
    expect(button.onPressed, isNotNull);

    await tester.tap(buttonFinder);
    await tester.pump();

    expect(find.text('login.consent_required'.tr()), findsOneWidget);
  });

  testWidgets('con il consenso spuntato il tocco non blocca più', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DsButton));
    await tester.pump();

    // Il sign-in vero fallisce (niente Supabase nei test) e mostra un'altra
    // snackbar: quello che conta è che non sia più quella del consenso.
    expect(find.text('login.consent_required'.tr()), findsNothing);
  });

  // Google Sign-In is the only way into the app: a second email/password
  // provider was implemented and then removed on 2026-08-01 in favour of
  // supplying the Play reviewer with a Google test account (see
  // ROADMAP_RILASCIO.md §2.3). If a second entry point ever comes back, it
  // must be consent-gated like the one above.
  testWidgets('Google is the only sign-in method offered', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byType(DsButton), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });
}
