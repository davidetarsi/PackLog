import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:pack_log/features/auth/view/login_screen.dart';

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

    // The Google sign-in button is the primary FilledButton. It is built via
    // `FilledButton.icon(...)`, which under the hood constructs the private
    // subclass `_FilledButtonWithIcon` (see
    // flutter/lib/src/material/filled_button.dart). `find.byType` matches on
    // exact `runtimeType`, so it would never find this widget; a predicate
    // using `is` matches the subclass while still requiring a FilledButton.
    final buttonFinder = find.byWidgetPredicate(
      (widget) => widget is FilledButton,
      description: 'Google sign-in FilledButton',
    );
    expect(buttonFinder, findsOneWidget);

    FilledButton button = tester.widget(buttonFinder);
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
}
