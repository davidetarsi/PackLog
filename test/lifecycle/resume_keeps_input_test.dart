import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/houses/view/add_edit_house_screen.dart';
import 'package:pack_log/features/items/view/item_sheet.dart';
import 'package:pack_log/features/luggages/view/add_edit_luggage_screen.dart';
import 'package:pack_log/features/promo/view/promo_code_sheet.dart';
import 'package:pack_log/features/spaces/view/add_edit_space_screen.dart';
import 'package:pack_log/features/ai_input/providers/ai_import_notifier.dart';
import 'package:pack_log/features/ai_input/view/ai_results_screen.dart';
import 'package:pack_log/features/trips/model/ai_packing.dart';
import 'package:pack_log/features/trips/model/ai_packing_request.dart';
import 'package:pack_log/features/trips/providers/ai_packing_run_provider.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/services/pack_trip_service.dart';
import 'package:pack_log/features/trips/view/ai_packing_wait_screen.dart';
import 'package:pack_log/features/trips/view/widgets/ai/ai_packing_sheet.dart';
import 'package:pack_log/features/trips/view/widgets/slots/slot_fill_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screenshots/support/fakes.dart';
import '../screenshots/support/harness.dart';
import '../screenshots/support/seed.dart';

/// Regola: quello che l'utente sta facendo non si perde quando l'app va in
/// background e torna. Al ritorno parte il pull, che fa ricaricare le liste:
/// la schermata o il foglio aperto devono restare com'erano, testo compreso.
///
/// Ogni voce di [_places] è un posto dell'app: per aggiungerne uno basta una
/// voce in più.
class _Place {
  const _Place(this.open, {this.setup, this.field, this.marker});

  /// Porta l'app nel posto.
  final Future<void> Function(ScreenshotApp app) open;
  final AppSetup? setup;

  /// Il campo in cui scrivere; senza, il primo della pagina.
  final Finder Function()? field;

  /// Un posto senza campi di testo (un'attesa): il widget che deve restare.
  final Type? marker;
}

Future<void> _go(ScreenshotApp app, String location, {String tab = '/'}) async {
  await app.go(tab);
  await app.push(location);
}

_Place _route(String location) => _Place((app) => _go(app, location));

/// Un foglio aperto sopra [location], come fa l'app.
_Place _sheet(String location, void Function(BuildContext context) show) =>
    _Place((app) async {
      await _go(app, location);
      final context = app.router.routerDelegate.navigatorKey.currentContext!;
      show(context);
      await app.settle();
    });

final Map<String, _Place> _places = {
  'ricerca nella casa': _Place((app) async {
    await _go(app, '/houses/$kHomeId');
    await app.tap(find.byKey(const Key('house_search')));
  }),
  'kit nuovo': _route('/houses/$kHomeId/kits/new'),
  'nuovo viaggio': _route('/new-trip'),
  'modifica del viaggio': _route('/trips/$kUpcomingTripId/edit-info'),
  'aggiungi alla valigia': _route('/trips/$kUpcomingTripId/edit-items'),
  'foglio della casa': _sheet(
    '/',
    (c) => unawaited(showAddEditHouseSheet(c, houseId: kHomeId)),
  ),
  'foglio dello spazio': _sheet(
    '/houses/$kHomeId',
    (c) => unawaited(showAddEditSpaceSheet(c, houseId: kHomeId)),
  ),
  'foglio del bagaglio': _sheet(
    '/',
    (c) => unawaited(showAddEditLuggageSheet(c, luggageId: 'lug-cabina')),
  ),
  'scheda dell oggetto': _sheet(
    '/houses/$kHomeId',
    (c) => unawaited(showItemSheet(c, houseId: kHomeId, itemId: 'item-0')),
  ),
  'codice promo': _sheet(
    '/profile',
    (c) => unawaited(showPromoCodeSheet(c, redeemNow: false)),
  ),
  'voce da riempire nel viaggio': _Place(
    (app) async {
      await _go(app, '/trips/$kSeoulTripId', tab: '/trips');
      await app.tester.ensureVisible(find.byKey(const Key('pack_row_missing')));
      await app.tap(find.byKey(const Key('pack_row_missing')));
      const row = Key('slot_row_slot-magliette');
      await app.tester.drag(
        find.byType(ListView).first,
        const Offset(0, -1200),
      );
      await app.settle();
      await app.tester.ensureVisible(find.byKey(row));
      await app.tap(find.byKey(row));
    },
    setup: AppSetup(
      seedWith: (c) async {
        await seed(c, SeedLevel.full);
        await seedValigiaPosti(c);
      },
    ),
    field: () => find.descendant(
      of: find.byKey(const Key('slot_sheet_input_slot-magliette')),
      matching: find.byType(TextField),
    ),
    marker: SlotFillSheet,
  ),
  'risultati dello scan': _Place(
    (app) async {
      await _go(app, '/houses/$kHomeId');
      await app.push('/houses/$kHomeId/ai-import/results');
      (app.container.read(aiImportNotifierProvider.notifier) as FakeAiImport)
          .emit(aiResultsState());
      await app.settle();
    },
    setup: AppSetup(
      extraOverrides: [aiImportNotifierProvider.overrideWith(FakeAiImport.new)],
    ),
    marker: AiResultsScreen,
  ),
  'scan in corso': _Place(
    (app) async {
      await _go(app, '/houses/$kHomeId');
      await app.push('/houses/$kHomeId/ai-import/results');
    },
    setup: AppSetup(
      extraOverrides: [
        aiImportNotifierProvider.overrideWith(
          () => FakeAiImport(aiLoadingState()),
        ),
      ],
    ),
    marker: AiResultsScreen,
  ),
  'foglio della valigia AI': _Place(
    (app) async {
      await _go(app, '/trips/$kSavedTripId', tab: '/trips');
      await app.tap(find.byWidgetPredicate((w) => w is PopupMenuButton));
      await app.tap(find.text('trips.pack.ai.regenerate'.tr()));
      await app.tap(find.text('trips.pack.ai.replace_confirm'.tr()));
    },
    setup: AppSetup(
      seedWith: (c) async {
        await seed(c, SeedLevel.full);
        await seedRigenera(c, kSavedTripId);
      },
    ),
    marker: AiPackingSheet,
  ),
  'attesa della valigia AI': _Place(
    (app) async {
      await app.go('/trips');
      final trips = await app.container.read(tripNotifierProvider.future);
      app.container
          .read(aiPackingRunProvider.notifier)
          .start(
            AiPackingRequest(
              trip: trips.firstWhere((t) => t.id == kUpcomingTripId),
              isNew: false,
              setup: const AiPackingSetup(houseId: kHomeId),
              job: const PackTripJob(
                body: <String, dynamic>{},
                houseId: kHomeId,
                title: 'Lisbona e Sintra',
                nights: 5,
              ),
            ),
          );
      unawaited(app.router.push('/ai-packing'));
      await app.settle();
    },
    setup: AppSetup(
      extraOverrides: [
        packTripServiceProvider.overrideWith((ref) => HangingPackTripService()),
      ],
    ),
    marker: AiPackingWaitScreen,
  ),
};

/// Vero se il focus è dentro un campo di testo.
bool _isTyping() =>
    FocusManager.instance.primaryFocus?.context?.widget is EditableText ||
    (FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>() !=
        null);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    useSystemSqlite();
    await createPhotoFixtures();
  });

  for (final entry in _places.entries) {
    final place = entry.value;
    testWidgets('${entry.key}: resta com è dopo background e pull', (
      tester,
    ) async {
      final app = await ScreenshotApp.start(
        tester,
        theme: ShotTheme.light,
        setup: place.setup ?? const AppSetup(),
      );
      await place.open(app);

      final marker = place.marker;
      if (marker != null) expect(find.byType(marker), findsOneWidget);
      final fields = (place.field ?? () => find.byType(TextField))();
      final canType = fields.evaluate().isNotEmpty;
      expect(
        canType || marker != null,
        isTrue,
        reason: 'nessun campo di testo aperto',
      );
      if (canType) await app.enterText(fields.first, 'Prova 42');
      final fieldsBefore = find.byType(TextField).evaluate().length;
      final hadFocus = _isTyping();

      // L'app va in background e torna; al ritorno il pull finisce.
      for (final state in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }
      app.container.read(syncTriggerProvider.notifier).increment();
      await tester.pump();
      expect(
        find.byType(TextField).evaluate(),
        hasLength(fieldsBefore),
        reason: 'durante il ricaricamento la pagina è stata sostituita',
      );
      if (marker != null) {
        expect(
          find.byType(marker),
          findsOneWidget,
          reason: 'durante il ricaricamento la pagina è stata sostituita',
        );
      }
      await app.settle();

      final texts = [
        for (final e in find.byType(TextField).evaluate())
          (e.widget as TextField).controller?.text.toLowerCase(),
      ];
      if (canType) {
        expect(texts, contains('prova 42'), reason: 'il testo è sparito');
      }
      expect(texts, hasLength(fieldsBefore), reason: 'la pagina è cambiata');
      if (marker != null) {
        expect(find.byType(marker), findsOneWidget, reason: 'pagina chiusa');
      }
      expect(_isTyping(), hadFocus, reason: 'il campo ha perso il focus');
      await app.finish();
    });
  }
}
