import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/features/profile/view/sheets/profile_language_sheet.dart';
import 'package:pack_log/features/profile/view/sheets/profile_theme_sheet.dart';
import 'package:pack_log/shared/widgets/ds_dialog.dart';
import 'package:pack_log/shared/widgets/ds_picker_sheet.dart';
import 'package:pack_log/shared/widgets/ds_settings.dart';
import 'package:pack_log/shared/widgets/ds_sheet_header.dart';

/// Legge i JSON veri di ogni lingua. Caricamento sincrono nel test: con i
/// file dell'asset bundle il primo frame resterebbe senza traduzioni.
class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final file = File(
      'assets/translations/${locale.languageCode}-${locale.countryCode}.json',
    );
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

/// Monta un bottone che apre [open] con il proprio context (quello della
/// schermata, come nel profilo).
Widget _host({required Future<void> Function(BuildContext) open}) {
  return EasyLocalization(
    supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
    path: 'assets/translations',
    fallbackLocale: const Locale('en', 'US'),
    startLocale: const Locale('it', 'IT'),
    saveLocale: false,
    assetLoader: const _FileAssetLoader(),
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const Key('open'),
              onPressed: () => open(context),
              child: const Text('apri'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openAndSettle(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('lingua', () {
    testWidgets('foglio con le due lingue e la spunta su quella attuale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(open: (context) => showProfileLanguageSheet(context)),
      );
      await tester.pumpAndSettle();
      await _openAndSettle(tester);

      expect(find.byType(DsSheetHeader), findsOneWidget);
      expect(find.byType(DsDialog), findsNothing);
      expect(find.text('Italiano'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('🇮🇹'), findsOneWidget);
      expect(find.text('🇬🇧'), findsOneWidget);
      expect(find.text('🇺🇸'), findsNothing);

      // La spunta sta solo sulla riga della lingua attuale (Italiano).
      expect(find.byIcon(Icons.check), findsOneWidget);
      final italianoRow = find.ancestor(
        of: find.text('Italiano'),
        matching: find.byType(DsSettingsRow),
      );
      expect(
        find.descendant(of: italianoRow, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
    });

    testWidgets('scegliere English cambia la lingua e chiude', (tester) async {
      await tester.pumpWidget(
        _host(open: (context) => showProfileLanguageSheet(context)),
      );
      await tester.pumpAndSettle();
      await _openAndSettle(tester);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(
        tester.element(find.byType(Scaffold).first).locale,
        const Locale('en', 'US'),
      );
      expect(find.byType(DsPickerSheet<Locale>), findsNothing);
      expect(find.byType(DsSheetHeader), findsNothing);
    });
  });

  group('tema', () {
    testWidgets('scegliere Scuro chiama onSetThemeMode(ThemeMode.dark)', (
      tester,
    ) async {
      final chosen = <ThemeMode>[];
      await tester.pumpWidget(
        _host(
          open: (context) => showProfileThemeSheet(
            context,
            currentThemeMode: ThemeMode.light,
            onSetThemeMode: chosen.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openAndSettle(tester);

      await tester.tap(find.text('Scuro'));
      await tester.pumpAndSettle();

      expect(chosen, [ThemeMode.dark]);
      expect(find.byType(DsSheetHeader), findsNothing);
    });

    testWidgets('chiudere con la x non cambia niente', (tester) async {
      final chosen = <ThemeMode>[];
      await tester.pumpWidget(
        _host(
          open: (context) => showProfileThemeSheet(
            context,
            currentThemeMode: ThemeMode.light,
            onSetThemeMode: chosen.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openAndSettle(tester);

      await tester.tap(find.byKey(const Key('sheet_close')));
      await tester.pumpAndSettle();

      expect(chosen, isEmpty);
      expect(find.byType(DsSheetHeader), findsNothing);
    });
  });
}
