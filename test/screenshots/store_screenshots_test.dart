/// Genera gli screenshot della scheda Google Play, in una lingua per volta.
/// Spento di default:
///
/// ```bash
/// flutter test test/screenshots/store_screenshots_test.dart \
///   --dart-define=STORE_SCREENSHOTS=true --dart-define=STORE_LOCALE=en
/// ```
///
/// Output in `build/store-screenshots/<lingua>/`: le schermate grezze, che
/// `tool/store/compose_screenshots.py` mette nel formato dello Store con la
/// didascalia. Per la scansione si possono passare due foto vere con
/// `--dart-define=STORE_PHOTO_1=<percorso>` e `STORE_PHOTO_2`; senza, si
/// usano le foto finte dell'harness.
library;

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/features/ai_input/providers/ai_import_notifier.dart';

import 'store/store_data.dart';
import 'support/fakes.dart';
import 'support/fonts.dart';
import 'support/harness.dart';

const _enabled = bool.fromEnvironment('STORE_SCREENSHOTS');
const _localeArg = String.fromEnvironment('STORE_LOCALE', defaultValue: 'it');
const _photo1 = String.fromEnvironment('STORE_PHOTO_1');
const _photo2 = String.fromEnvironment('STORE_PHOTO_2');

const _outputDir = 'build/store-screenshots';

final _english = _localeArg == 'en';
final _locale = _english ? const Locale('en', 'US') : const Locale('it', 'IT');
final _data = StoreData(english: _english);

typedef _Steps = Future<void> Function(ScreenshotApp app);

/// Porta in cima allo schermo, a [top] dp dal bordo, il testo [text].
Future<void> _scrollTo(
  ScreenshotApp app,
  String text, {
  double top = 120,
}) async {
  final finder = find.text(text).first;
  await app.tester.ensureVisible(finder);
  await app.settle(frames: 4);
  final y = app.tester.getTopLeft(finder).dy;
  await app.tester.drag(
    find.byType(Scrollable).first,
    Offset(0, top - y),
    warnIfMissed: false,
  );
  await app.settle();
}

Future<void> _pack(ScreenshotApp app, String tripId) async {
  await app.go('/trips');
  await app.push('/trips/$tripId/edit-items');
}

Future<void> _tapShown(ScreenshotApp app, Finder finder) async {
  await app.tester.ensureVisible(finder.first);
  await app.tap(finder);
}

final _scenarios = <(int, String, AppSetup, _Steps)>[
  (
    1,
    'valigia-ai',
    AppSetup(seedWith: _data.seed, locale: _locale),
    (app) async {
      await _pack(app, StoreData.tripId);
      await _scrollTo(app, 'trips.pack.items'.tr());
    },
  ),
  (
    2,
    'motivi',
    AppSetup(seedWith: _data.seed, locale: _locale),
    (app) async {
      await _pack(app, StoreData.tripId);
      await app.tap(find.text('trips.pack.ai.reasons_row'.tr()));
    },
  ),
  (
    4,
    'foglio-ai',
    AppSetup(seedWith: _data.seed, locale: _locale),
    (app) async {
      await _pack(app, StoreData.weekendTripId);
      await app.tap(find.byKey(const Key('pack_ai_suitcase')));
      final replace = find.text('trips.pack.ai.replace_confirm'.tr());
      if (replace.evaluate().isNotEmpty) await app.tap(replace);
      await _tapShown(app, find.text('trips.ai.activity.city'.tr()));
      await _tapShown(app, find.text('trips.ai.activity.formal_dinner'.tr()));
      await _tapShown(app, find.text('trips.ai.stay.hotel'.tr()));
      await app.tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, 2000),
      );
      await app.settle();
    },
  ),
  (
    3,
    'scansione',
    AppSetup(
      seedWith: _data.seed,
      locale: _locale,
      extraOverrides: [aiImportNotifierProvider.overrideWith(FakeAiImport.new)],
    ),
    (app) async {
      await app.go('/');
      await app.push('/houses/${StoreData.homeId}');
      await app.push('/houses/${StoreData.homeId}/ai-import/results');
      final first = _photo1.isEmpty ? photoShirt : File(_photo1);
      final second = _photo2.isEmpty ? photoJeans : File(_photo2);
      (app.container.read(aiImportNotifierProvider.notifier) as FakeAiImport)
          .emit(_data.scanResults(first: first, second: second));
      await app.settle();
    },
  ),
  (
    5,
    'meteo',
    AppSetup(seedWith: _data.seed, locale: _locale),
    (app) async {
      await app.go('/trips');
      await app.push('/trips/${StoreData.tripId}');
    },
  ),
  (
    6,
    'checklist',
    AppSetup(seedWith: _data.seed, locale: _locale),
    (app) async {
      await app.go('/trips');
      await app.push('/trips/${StoreData.tripId}');
      await _scrollTo(app, 'trips.pack.items'.tr());
    },
  ),
  (
    7,
    'casa',
    AppSetup(seedWith: _data.seed, locale: _locale),
    (app) async {
      await app.go('/');
      await app.push('/houses/${StoreData.homeId}');
    },
  ),
];

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    useSystemSqlite();
    await loadRealFonts();
    await createPhotoFixtures();
  });

  for (final (order, screen, setup, steps) in _scenarios) {
    testWidgets('$order $screen [$_localeArg]', skip: !_enabled, (
      tester,
    ) async {
      final app = await ScreenshotApp.start(
        tester,
        theme: ShotTheme.light,
        setup: setup,
      );
      await steps(app);
      await app.capture(
        Shot(
          flow: _locale.toLanguageTag(),
          flowTitle: 'Google Play',
          order: order,
          screen: screen,
          state: 'store',
          source: 'test/screenshots/store_screenshots_test.dart',
          description: 'Screenshot della scheda Google Play.',
          theme: ShotTheme.light,
          outputDir: _outputDir,
        ),
      );
      await app.finish();
    });
  }
}
