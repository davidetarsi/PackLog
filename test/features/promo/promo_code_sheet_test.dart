import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pack_log/features/promo/providers/promo_code_provider.dart';
import 'package:pack_log/features/promo/service/promo_code_service.dart';
import 'package:pack_log/features/promo/view/promo_code_sheet.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';
import 'package:pack_log/shared/widgets/ds_sheet_header.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../screenshots/support/harness.dart';

class _PromoService extends Mock implements PromoCodeService {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    useSystemSqlite();
  });

  testWidgets('uno swipe durante il salvataggio non chiude il foglio', (
    tester,
  ) async {
    final service = _PromoService();
    final pending = Completer<void>();
    when(() => service.savePending(any())).thenAnswer((_) => pending.future);
    final app = await ScreenshotApp.start(
      tester,
      theme: ShotTheme.dark,
      setup: AppSetup(
        extraOverrides: [promoCodeServiceProvider.overrideWithValue(service)],
      ),
    );
    try {
      showPromoCodeSheet(
        tester.element(find.byType(Scaffold).last),
        redeemNow: false,
      );
      await app.settle();
      await app.enterText(find.byKey(const Key('promo_sheet_field')), 'ESTATE');
      await app.tap(find.byKey(const Key('promo_sheet_activate')));
      await tester.drag(find.byType(DsSheetHeader), const Offset(0, 600));
      await app.settle();
      expect(find.byKey(const Key('promo_sheet_field')), findsOneWidget);
    } finally {
      pending.complete();
      await app.settle();
      await app.finish();
    }
  });

  testWidgets(
    'errore locale conserva il codice, permette di riprovare e impedisce doppio invio',
    (tester) async {
      final service = _PromoService();
      final first = Completer<void>();
      var calls = 0;
      when(() => service.savePending(any())).thenAnswer((_) {
        calls++;
        return calls == 1 ? first.future : Future.value();
      });
      final app = await ScreenshotApp.start(
        tester,
        theme: ShotTheme.dark,
        setup: AppSetup(
          extraOverrides: [promoCodeServiceProvider.overrideWithValue(service)],
        ),
      );
      final context = tester.element(find.byType(Scaffold).last);
      showPromoCodeSheet(context, redeemNow: false);
      await app.settle();
      expect(
        tester
            .widget<DsButton>(find.byKey(const Key('promo_sheet_activate')))
            .onPressed,
        isNull,
      );
      await app.enterText(find.byKey(const Key('promo_sheet_field')), 'ESTATE');
      await app.tap(find.byKey(const Key('promo_sheet_activate')));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(calls, 1);
      first.completeError(StateError('storage non disponibile'));
      await app.settle();
      expect(find.text('promo.error_generic'.tr()), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('promo_sheet_field')),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        'ESTATE',
      );
      await app.tap(find.byKey(const Key('promo_sheet_activate')));
      expect(calls, 2);
      expect(find.byKey(const Key('promo_sheet_field')), findsNothing);
      await app.finish();
    },
  );
}
