import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/core/analytics/analytics_service.dart';
import 'package:pack_log/features/onboarding/view/onboarding_screen.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';

void main() {
  // AppAnalyticsService con Amplitude null: logEvent è un no-op sicuro
  // (stesso approccio di login_screen_test.dart).
  Widget wrap() => ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(AppAnalyticsService(null)),
    ],
    child: const MaterialApp(home: OnboardingScreen()),
  );

  const skip = Key('onboarding_skip');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Salta completa l\'onboarding dalla prima slide', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(skip).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(skip));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_completed'), isTrue);
  });

  testWidgets('sull\'ultima slide Salta non c\'è', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Due "Avanti" portano alla terza e ultima slide.
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byType(DsButton));
      await tester.pumpAndSettle();
    }

    expect(find.byKey(skip).hitTestable(), findsNothing);
  });
}
