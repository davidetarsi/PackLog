import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/features/trips/view/widgets/ai/ai_pack_reassurance.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../helpers/memory_asset_loader.dart';

const _it = Locale('it', 'IT');
const _en = Locale('en', 'US');

const _testoIt =
    'Con questa valigia hai il necessario per questo viaggio. Se vuoi portare altro, aggiungilo dalla ricerca.';
const _testoEn =
    'This suitcase has what you need for this trip. If you want to bring more, add it from search.';

Future<void> _pump(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [_it, _en],
      path: 'assets/translations',
      assetLoader: MemoryAssetLoader(readAppTranslations()),
      fallbackLocale: _en,
      startLocale: locale,
      saveLocale: false,
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          home: const Scaffold(body: AiPackReassurance()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('in italiano mostra il testo it', (tester) async {
    await _pump(tester, _it);
    expect(find.text(_testoIt), findsOneWidget);
  });

  testWidgets('in inglese mostra il testo en', (tester) async {
    await _pump(tester, _en);
    expect(find.text(_testoEn), findsOneWidget);
  });

  testWidgets('usa bodySmall con colore onSurfaceVariant', (tester) async {
    await _pump(tester, _it);
    final text = tester.widget<Text>(find.text(_testoIt));
    final context = tester.element(find.byType(AiPackReassurance));
    final theme = Theme.of(context);
    expect(text.style?.fontSize, theme.textTheme.bodySmall?.fontSize);
    expect(text.style?.color, theme.colorScheme.onSurfaceVariant);
  });
}
