import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pack_log/features/profile/view/dialogs/profile_logout_dialog.dart';
import 'package:pack_log/shared/theme/app_theme.dart';
import 'package:pack_log/shared/widgets/ds_button.dart';
import 'package:pack_log/shared/widgets/ds_text_button.dart';
import '../../../../helpers/memory_asset_loader.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget wrap({required Widget child}) => EasyLocalization(
    supportedLocales: const [Locale('en', 'US'), Locale('it', 'IT')],
    path: 'assets/translations',
    fallbackLocale: const Locale('it'),
    saveLocale: false,
    startLocale: const Locale('it', 'IT'),
    useOnlyLangCode: false,
    assetLoader: MemoryAssetLoader(readAppTranslations()),
    child: Builder(
      builder: (context) => MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: Scaffold(body: child),
      ),
    ),
  );

  testWidgets('logout semplice mette Annulla in evidenza ed Esci neutro', (
    tester,
  ) async {
    ProfileLogoutChoice? choice;
    await tester.pumpWidget(
      wrap(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              choice = await showProfileLogoutDialog(context, 0);
            },
            child: const Text('Apri'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();

    final cancel = tester.widget<DsButton>(find.byType(DsButton));
    expect(cancel.label, 'Annulla');
    expect(cancel.variant, DsButtonVariant.primary);
    final exit = tester.widget<DsTextButton>(find.byType(DsTextButton));
    expect(exit.label, 'Esci comunque');
    expect(exit.destructive, isFalse);

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(choice, ProfileLogoutChoice.cancel);
  });

  testWidgets('logout con modifiche mantiene Sincronizza prima primaria', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showProfileLogoutDialog(context, 3),
            child: const Text('Apri'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();

    final primary = tester.widget<DsButton>(find.byType(DsButton).first);
    expect(find.byType(DsButton), findsOneWidget);
    final secondary = tester
        .widgetList<DsTextButton>(find.byType(DsTextButton))
        .toList();
    expect(secondary.map((button) => button.label), [
      'Esci comunque',
      'Annulla',
    ]);
    expect(
      secondary.every((button) => !button.accent && !button.destructive),
      isTrue,
    );
    expect(primary.label, 'Sincronizza ed esci');
    expect(primary.variant, DsButtonVariant.primary);
  });
}
