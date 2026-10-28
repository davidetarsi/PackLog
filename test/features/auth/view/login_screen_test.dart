import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:pack_log/core/consent/consent_provider.dart';
import 'package:pack_log/core/consent/consent_service.dart';
import 'package:pack_log/features/auth/view/login_screen.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';
import 'package:pack_log/shared/widgets/ds_link_button.dart';

void main() {
  // The analytics service is the concrete `AppAnalyticsService`; constructing
  // it with a null Amplitude instance makes logEvent/identifyUser safe no-ops
  // (see analytics_service.dart) — no fake/mock needed.
  Widget wrap({ConsentService? consent}) => EasyLocalization(
    supportedLocales: const [Locale('en'), Locale('it')],
    path: 'assets/translations',
    fallbackLocale: const Locale('en'),
    saveLocale: false,
    child: ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(AppAnalyticsService(null)),
        if (consent != null) consentServiceProvider.overrideWithValue(consent),
      ],
      child: const MaterialApp(home: LoginScreen()),
    ),
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('niente casella: il bottone è attivo e c\'è l\'avviso', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsNothing);
    expect(tester.widget<DsButton>(find.byType(DsButton)).onPressed, isNotNull);
    expect(find.byKey(const Key('login_consent_notice')), findsOneWidget);
  });

  testWidgets('toccare "Accedi con Google" registra il consenso', (
    tester,
  ) async {
    final consent = ConsentService();
    await consent.reset();
    await consent.load();
    await tester.pumpWidget(wrap(consent: consent));
    await tester.pumpAndSettle();
    expect(consent.hasConsent, isFalse);

    await tester.tap(find.byType(DsButton));
    await tester.pump();

    // Il sign-in vero poi fallisce (niente Supabase nei test): conta che il
    // consenso sia stato registrato al tocco.
    expect(consent.hasConsent, isTrue);
    await tester.pumpAndSettle();
  });

  // Google Sign-In is the only way into the app: a second email/password
  // provider was implemented and then removed on 2026-08-01 in favour of
  // supplying the Play reviewer with a Google test account (see
  // ROADMAP_RILASCIO.md §2.3). If a second entry point ever comes back, it
  // must record consent on tap like the one above.
  testWidgets('Google is the only sign-in method offered', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byType(DsButton), findsOneWidget);
    // L'unico TextButton è il link del codice promo, che non è un accesso.
    expect(find.byType(DsLinkButton), findsOneWidget);
    expect(find.byType(TextButton), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DsLinkButton),
        matching: find.byType(TextButton),
      ),
      findsOneWidget,
    );
  });
}
