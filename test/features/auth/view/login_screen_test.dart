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

  testWidgets('Google sign-in button is disabled until consent is given', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Il bottone di accesso è un DsButton, il componente pill condiviso
    // dell'app: `onPressed == null` è ciò che lo spegne, ed è anche ciò che
    // ne toglie l'accento arancione (vedi la scala a tre livelli).
    final buttonFinder = find.byType(DsButton);
    expect(buttonFinder, findsOneWidget);

    DsButton button = tester.widget(buttonFinder);
    expect(
      button.onPressed,
      isNull,
      reason: 'button must be disabled before consent',
    );

    // Tick the consent checkbox.
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    button = tester.widget(buttonFinder);
    expect(
      button.onPressed,
      isNotNull,
      reason: 'button must be enabled after consent',
    );
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
