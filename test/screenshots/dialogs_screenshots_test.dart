/// Screenshot dei dialog reali di conferma, catturati attraverso gli helper
/// condivisi e gli entrypoint usati dall'app.
///
/// Esecuzione: flutter test test/screenshots/dialogs_screenshots_test.dart
/// --dart-define=DIALOG_SCREENSHOTS=true
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/features/profile/view/dialogs/profile_delete_account_dialog.dart';
import 'package:pack_log/features/profile/view/dialogs/profile_logout_dialog.dart';
import 'package:pack_log/features/profile/widgets/sync_details_dialog.dart';
import 'package:pack_log/shared/helpers/dialog_helpers.dart';
import 'package:pack_log/shared/widgets/ds_dialog.dart';
import 'package:pack_log/shared/widgets/error_retry_dialog.dart';

import 'support/fonts.dart';
import 'support/harness.dart';
import 'support/seed.dart';

const _enabled = bool.fromEnvironment('DIALOG_SCREENSHOTS');
const _output = 'build/ui-screenshots';

typedef _OpenDialog = Future<void> Function(ScreenshotApp app);

class _DialogCase {
  const _DialogCase(
    this.order,
    this.screen,
    this.state,
    this.source,
    this.open,
  );

  final int order;
  final String screen;
  final String state;
  final String source;
  final _OpenDialog open;
}

BuildContext _context(ScreenshotApp app) =>
    app.tester.element(find.byType(Scaffold).first);

void _expectNoRawTranslationKeys(ScreenshotApp app) {
  final textWidgets = app.tester.widgetList<Text>(
    find.descendant(of: find.byType(DsDialog), matching: find.byType(Text)),
  );
  final untranslated = textWidgets
      .map((widget) => widget.data ?? '')
      .where(
        (text) =>
            RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$').hasMatch(text),
      )
      .toList();
  expect(untranslated, isEmpty, reason: 'chiavi di traduzione grezze');
}

Future<void> _captureConfirmation(
  ScreenshotApp app, {
  required String title,
  required String message,
  required String confirm,
  bool destructive = true,
}) async {
  unawaited(
    DialogHelpers.showConfirmation(
      context: _context(app),
      title: title,
      message: message,
      confirmLabel: confirm,
      isDestructive: destructive,
    ),
  );
  await app.settle();
}

Future<void> _captureDelete(
  ScreenshotApp app, {
  required String itemType,
  required String itemName,
  String? title,
  String? warning,
  String? message,
}) async {
  unawaited(
    DialogHelpers.showDeleteConfirmation(
      context: _context(app),
      itemType: itemType,
      itemName: itemName,
      customTitle: title,
      customMessage: message,
      warningText: warning,
    ),
  );
  await app.settle();
}

final _cases = <_DialogCase>[
  _DialogCase(
    1,
    'casa',
    'elimina',
    'lib/features/houses/view/widgets/house_actions.dart',
    (app) => _captureDelete(
      app,
      itemType: 'common.house_type'.tr(),
      itemName: 'Casa al mare',
    ),
  ),
  _DialogCase(
    2,
    'spazio',
    'elimina',
    'lib/features/spaces/view/add_edit_space_screen.dart',
    (app) => _captureDelete(
      app,
      itemType: '',
      itemName: 'Armadio camera',
      title: 'spaces.delete'.tr(),
      warning: 'spaces.delete_warning'.tr(),
    ),
  ),
  _DialogCase(
    3,
    'bagaglio',
    'elimina',
    'lib/features/luggages/view/add_edit_luggage_screen.dart',
    (app) => _captureDelete(
      app,
      itemType: '',
      itemName: 'Zaino 30 L',
      title: 'luggages.delete'.tr(),
      warning: 'luggages.delete_warning'.tr(),
    ),
  ),
  _DialogCase(
    4,
    'oggetto',
    'elimina',
    'lib/features/items/view/item_sheet.dart',
    (app) => _captureDelete(
      app,
      itemType: 'common.item_type'.tr(),
      itemName: 'Giacca impermeabile',
    ),
  ),
  _DialogCase(
    5,
    'kit',
    'elimina',
    'lib/features/kits/view/kit_detail_screen.dart',
    (app) => _captureDelete(
      app,
      itemType: '',
      itemName: 'Kit trekking',
      title: 'kits.delete'.tr(),
      warning: 'kits.delete_warning'.tr(),
    ),
  ),
  _DialogCase(
    6,
    'viaggio',
    'elimina',
    'lib/features/trips/view/trip_detail_screen.dart',
    (app) => _captureDelete(
      app,
      itemType: 'common.trip_type'.tr(),
      itemName: 'Weekend a Lisbona',
    ),
  ),
  _DialogCase(
    7,
    'scansione-ai',
    'scarta-risultati',
    'lib/features/ai_input/view/ai_results_screen.dart',
    (app) => _captureConfirmation(
      app,
      title: 'ai_import.discard_title'.tr(),
      message: 'ai_import.discard_body'.tr(),
      confirm: 'ai_import.discard'.tr(),
    ),
  ),
  _DialogCase(
    8,
    'nuovo-viaggio',
    'lascia',
    'lib/features/trips/view/new_trip_screen.dart',
    (app) => _captureConfirmation(
      app,
      title: 'trips.new.discard_title'.tr(),
      message: 'trips.new.discard_message'.tr(),
      confirm: 'common.confirm'.tr(),
    ),
  ),
  _DialogCase(
    14,
    'modifica-viaggio',
    'scarta-modifiche',
    'lib/features/trips/view/new_trip_screen.dart',
    (app) => _captureConfirmation(
      app,
      title: 'trips.edit.discard_title'.tr(),
      message: 'trips.edit.discard_message'.tr(),
      confirm: 'common.confirm'.tr(),
    ),
  ),
  _DialogCase(
    9,
    'valigia',
    'lascia',
    'lib/features/trips/view/pack_suitcase_screen.dart',
    (app) => _captureConfirmation(
      app,
      title: 'trips.pack.discard_title'.tr(),
      message: 'trips.pack.discard_message'.tr(),
      confirm: 'common.confirm'.tr(),
    ),
  ),
  _DialogCase(
    15,
    'valigia-ai',
    'lascia-modifiche-successive',
    'lib/features/trips/view/pack_suitcase_screen.dart',
    (app) => _captureConfirmation(
      app,
      title: 'trips.pack.discard_title'.tr(),
      message: 'trips.pack.ai.discard_message'.tr(),
      confirm: 'common.confirm'.tr(),
    ),
  ),
  _DialogCase(
    10,
    'valigia-ai',
    'sostituisci',
    'lib/features/trips/services/ai_packing_launcher.dart',
    (app) => _captureConfirmation(
      app,
      title: 'trips.pack.ai.replace_title'.tr(),
      message: 'trips.pack.ai.replace_message'.tr(),
      confirm: 'trips.pack.ai.replace_confirm'.tr(),
    ),
  ),
  _DialogCase(
    11,
    'posto-importante',
    'rimuovi',
    'lib/features/trips/view/widgets/slots/slot_edits.dart',
    (app) => _captureConfirmation(
      app,
      title: 'trips.slots.remove_title'.tr(args: ['Torcia frontale']),
      message: 'trips.slots.remove_body'.tr(),
      confirm: 'trips.slots.remove_confirm'.tr(),
    ),
  ),
  _DialogCase(
    12,
    'logout',
    'semplice',
    'lib/features/profile/view/dialogs/profile_logout_dialog.dart',
    (app) async {
      unawaited(showProfileLogoutDialog(_context(app), 0));
      await app.settle();
    },
  ),
  _DialogCase(
    20,
    'logout',
    'modifiche-non-sincronizzate',
    'lib/features/profile/view/dialogs/profile_logout_dialog.dart',
    (app) async {
      unawaited(showProfileLogoutDialog(_context(app), 3));
      await app.settle();
    },
  ),
  _DialogCase(
    16,
    'oggetti-selezionati',
    'elimina-in-blocco',
    'lib/features/houses/view/widgets/house_bulk_actions.dart',
    (app) => _captureDelete(
      app,
      itemType: '',
      itemName: '',
      title: 'items.bulk_delete_confirm_title'.tr(args: ['3']),
      message: 'items.bulk_delete_confirm_body'.tr(),
    ),
  ),
  _DialogCase(
    17,
    'elimina-casa',
    'impossibile-con-oggetti',
    'lib/features/houses/view/widgets/house_actions.dart',
    (app) async {
      unawaited(
        DialogHelpers.showInfo(
          context: _context(app),
          title: 'common.error'.tr(),
          message: 'houses.cannot_delete_has_items'.tr(),
          details: [
            'houses.permanent_items_count'.tr(args: ['12']),
          ],
        ),
      );
      await app.settle();
    },
  ),
  _DialogCase(
    18,
    'salvataggio',
    'errore-riprova',
    'lib/shared/widgets/error_retry_dialog.dart',
    (app) async {
      unawaited(
        ErrorRetryDialog.show(
          context: _context(app),
          title: 'common.error'.tr(),
          message: 'errors.save_trip_failed'.tr(args: ['Weekend a Lisbona']),
          retryText: 'common.retry'.tr(),
          cancelText: 'common.cancel'.tr(),
        ),
      );
      await app.settle();
      final cancel = app.tester.getRect(find.text('common.cancel'.tr()));
      final retry = app.tester.getRect(find.text('common.retry'.tr()));
      expect(cancel.center.dy, closeTo(retry.center.dy, 1));
    },
  ),
  _DialogCase(
    19,
    'sincronizzazione',
    'dettagli-stato',
    'lib/features/profile/widgets/sync_details_dialog.dart',
    (app) async {
      unawaited(SyncDetailsDialog.show(_context(app)));
      await app.settle();
    },
  ),
];

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    useSystemSqlite();
    await loadRealFonts();
  });
  tearDownAll(Manifest.write);

  for (final theme in ShotTheme.values) {
    for (final scenario in _cases) {
      testWidgets(
        '${scenario.screen} ${scenario.state} [${theme.name}]',
        skip: !_enabled,
        (tester) async {
          final app = await ScreenshotApp.start(
            tester,
            theme: theme,
            setup: const AppSetup(seed: SeedLevel.empty),
          );
          try {
            await app.go('/');
            await scenario.open(app);
            _expectNoRawTranslationKeys(app);
            await app.capture(
              Shot(
                flow: '14-dialoghi',
                flowTitle: 'Dialog di conferma',
                order: scenario.order,
                screen: scenario.screen,
                state: scenario.state,
                source: scenario.source,
                description: 'Dialog reale mostrato dall’helper dell’app.',
                theme: theme,
                outputDir: _output,
              ),
            );
          } finally {
            await app.finish();
          }
        },
      );
    }

    for (final enabled in [false, true]) {
      testWidgets(
        'elimina-account ${enabled ? 'abilitato' : 'disabilitato'} [${theme.name}]',
        skip: !_enabled,
        (tester) async {
          const email = 'account@example.com';
          final app = await ScreenshotApp.start(
            tester,
            theme: theme,
            setup: const AppSetup(seed: SeedLevel.empty),
          );
          try {
            await app.go('/');
            unawaited(showProfileDeleteAccountDialog(_context(app), email));
            await app.settle();
            if (enabled) {
              await app.enterText(find.byType(TextField), email);
            }
            _expectNoRawTranslationKeys(app);
            await app.capture(
              Shot(
                flow: '14-dialoghi',
                flowTitle: 'Dialog di conferma',
                order: 13,
                screen: 'account',
                state: enabled ? 'conferma-abilitata' : 'conferma-disabilitata',
                source:
                    'lib/features/profile/view/dialogs/profile_delete_account_dialog.dart',
                description:
                    'Eliminazione account con conferma digitata: ${enabled ? 'abilitata' : 'disabilitata'}.',
                theme: theme,
                outputDir: _output,
              ),
            );
          } finally {
            await app.finish();
          }
        },
      );
    }
  }
}
