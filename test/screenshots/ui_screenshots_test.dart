/// Genera uno screenshot PNG per ogni schermata/stato dell'app, divisi per
/// flusso, più un `manifest.json`. Non è un test di regressione: serve a
/// portare la UI fuori dal telefono (Figma, review) senza emulatore.
///
/// Spento di default, così `flutter test` resta veloce:
///
/// ```bash
/// flutter test test/screenshots --dart-define=UI_SCREENSHOTS=true
/// ```
///
/// Output in `build/ui-screenshots/`. Vedi `docs/ui-flows.md`.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_log/core/sync/sync_provider.dart';
import 'package:pack_log/features/ai_input/model/ai_failure_reason.dart';
import 'package:pack_log/features/ai_input/model/ai_import_state.dart';
import 'package:pack_log/features/ai_input/providers/ai_import_notifier.dart';
import 'package:pack_log/features/tour/model/onboarding_state.dart';
import 'package:pack_log/features/trips/providers/trip_provider.dart';
import 'package:pack_log/features/trips/services/trip_weather_service.dart';
import 'package:pack_log/features/trips/view/widgets/pack/pack_parts.dart';
import 'package:pack_log/features/trips/view/widgets/trip_calendar.dart';
import 'package:pack_log/shared/widgets/quantity_stepper.dart';

import 'support/fakes.dart';
import 'support/fonts.dart';
import 'support/harness.dart';
import 'support/seed.dart';

const _enabled = bool.fromEnvironment('UI_SCREENSHOTS');

/// `--dart-define=UI_SCREENSHOTS_THEMES=dark` per un solo tema.
const _themesArg = String.fromEnvironment(
  'UI_SCREENSHOTS_THEMES',
  defaultValue: 'dark,light',
);

typedef Steps = Future<void> Function(ScreenshotApp app);

class Scenario {
  final int order;
  final String screen;
  final String state;
  final String source;
  final String description;
  final String? route;
  final AppSetup setup;
  final Steps steps;

  const Scenario(
    this.order,
    this.screen,
    this.state, {
    required this.source,
    required this.description,
    required this.steps,
    this.route,
    this.setup = const AppSetup(),
  });
}

class Flow {
  final String id;
  final String title;
  final List<Scenario> scenarios;

  const Flow(this.id, this.title, this.scenarios);
}

// ── Helper di interazione ────────────────────────────────────────────────────

Finder _text(String key) => find.text(key.tr());
Finder _icon(IconData icon) => find.byIcon(icon);

Future<void> _openCreateSheet(ScreenshotApp app, [String tab = '/']) async {
  await app.go(tab);
  await app.tap(find.byKey(const Key('nav_create')));
}

Future<void> _houseDetail(ScreenshotApp app, [String id = kHomeId]) async {
  await app.go('/');
  await app.push('/houses/$id');
}

Future<void> _tripDetail(
  ScreenshotApp app, [
  String id = kUpcomingTripId,
]) async {
  await app.go('/trips');
  await app.push('/trips/$id');
}

/// Apre la pagina valigia di un viaggio, sopra la tab Viaggi.
Future<void> _pack(ScreenshotApp app, String id) async {
  await app.go('/trips');
  await app.push('/trips/$id/edit-items');
}

/// Scorre la pila dei viaggi Prossimi di una cartolina verso sinistra.
Future<void> _swipePile(ScreenshotApp app) async {
  await app.tester.drag(
    find.byKey(const Key('postcard_pile')),
    const Offset(-330, 0),
  );
  await app.settle();
}

Future<void> _openManageSheet(ScreenshotApp app) async {
  await _houseDetail(app);
  await app.tap(_icon(Icons.more_vert));
}

Future<void> _emitAi(ScreenshotApp app, AiImportState state) async {
  (app.container.read(aiImportNotifierProvider.notifier) as FakeAiImport).emit(
    state,
  );
  await app.settle();
}

class _SyncingForever extends Syncing {
  @override
  bool build() => true;
}

// ── Nuovo viaggio ────────────────────────────────────────────────────────────

/// Mese prossimo: sempre nel futuro, e il calendario va scorso fino a lì.
final _nextMonth = DateTime(DateTime.now().year, DateTime.now().month + 1);

DateTime _nextMonthDay(int day) =>
    DateTime(_nextMonth.year, _nextMonth.month, day);

Finder _placeField() => _fieldIn('new_trip_place_search');

/// Il campo di testo dentro un widget con quella chiave.
Finder _fieldIn(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

Future<void> _openNewTrip(ScreenshotApp app) async {
  await app.go('/trips');
  await app.push('/new-trip');
}

/// Scrive [query] nel campo della meta o della tappa e sceglie il primo luogo.
Future<void> _searchPlace(ScreenshotApp app, Finder field, String query) async {
  await app.tap(field);
  await app.enterText(field, query);
  await app.tap(find.byKey(const Key('place_search_location_0')));
}

/// Tocca un giorno del calendario, scorrendolo se fuori schermo.
Future<void> _tapCalendarDay(ScreenshotApp app, DateTime day) async {
  final tester = app.tester;
  final finder = find.byKey(
    ValueKey('trip_calendar_day_${DateFormat('yyyy-MM-dd').format(day)}'),
  );
  await tester.scrollUntilVisible(
    finder,
    50,
    scrollable: find.descendant(
      of: find.byType(TripCalendar),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.ensureVisible(finder);
  await app.tap(finder);
}

/// Foglio "Quando?": il primo tocco riparte dalla partenza, il secondo sceglie
/// il ritorno.
Future<void> _pickTripDates(
  ScreenshotApp app, {
  required DateTime departure,
  required DateTime end,
}) async {
  await app.tap(find.byKey(const Key('new_trip_dates')));
  await _tapCalendarDay(app, departure);
  await _tapCalendarDay(app, end);
  await app.tap(_text('trips.confirm_dates'));
}

/// Passo 1 compilato: Lisbona come meta, dal 10 al 13 del mese prossimo.
Future<void> _fillStep1(ScreenshotApp app) async {
  await _openNewTrip(app);
  await _searchPlace(app, _placeField(), 'Lisbona');
  await _pickTripDates(
    app,
    departure: _nextMonthDay(10),
    end: _nextMonthDay(13),
  );
}

Future<void> _openStopSheet(ScreenshotApp app) async {
  await app.tester.ensureVisible(find.byKey(const Key('new_trip_add_stop')));
  await app.tap(find.byKey(const Key('new_trip_add_stop')));
}

Future<void> _fillStopPlace(ScreenshotApp app, String query) =>
    _searchPlace(app, _fieldIn('stop_sheet_place'), query);

/// Foglio "Fino a quando?" della tappa.
Future<void> _fillStopEnd(ScreenshotApp app, DateTime end) async {
  await app.tap(find.byKey(const Key('stop_sheet_dates')));
  await _tapCalendarDay(app, end);
  await app.tap(_text('common.confirm'));
}

/// Aggiunge in coda la tappa Sintra, finita il giorno [end].
Future<void> _addSintraStop(ScreenshotApp app, {required DateTime end}) async {
  await _openStopSheet(app);
  await _fillStopPlace(app, 'Sintra');
  await _fillStopEnd(app, end);
  await app.tap(find.byKey(const Key('stop_sheet_save')));
}

// ── Flussi ───────────────────────────────────────────────────────────────────

const _houses = 'lib/features/houses/view/houses_screen.dart';
const _houseDetailSrc = 'lib/features/houses/view/house_detail_screen.dart';
const _trips = 'lib/features/trips/view/trips_screen.dart';
const _tripDetailSrc = 'lib/features/trips/view/trip_detail_screen.dart';
const _addTrip = 'lib/features/trips/view/new_trip_screen.dart';
const _placeSearchSrc = 'lib/features/trips/view/widgets/place_search.dart';
const _stopSheetSrc = 'lib/features/trips/view/widgets/stop_sheet.dart';
const _datesSheetSrc = 'lib/features/trips/view/widgets/trip_dates_sheet.dart';
const _packSrc = 'lib/features/trips/view/pack_suitcase_screen.dart';
const _packWeatherSrc =
    'lib/features/trips/view/widgets/pack/pack_weather.dart';
const _profile = 'lib/features/profile/view/profile_screen.dart';
const _aiResults = 'lib/features/ai_input/view/ai_results_screen.dart';

final flows = <Flow>[
  Flow('01-primo-avvio', 'Primo avvio: onboarding e login', [
    Scenario(
      1,
      'onboarding',
      'slide-case',
      route: '/onboarding',
      source: 'lib/features/onboarding/view/onboarding_screen.dart',
      description:
          'Prima slide (case). Nei test il video non parte: si vede l\'icona di fallback.',
      setup: const AppSetup(onboardingCompleted: false, authenticated: false),
      steps: (app) async {},
    ),
    Scenario(
      2,
      'onboarding',
      'slide-oggetti',
      route: '/onboarding',
      source: 'lib/features/onboarding/view/onboarding_screen.dart',
      description: 'Seconda slide (oggetti).',
      setup: const AppSetup(onboardingCompleted: false, authenticated: false),
      steps: (app) async {
        await app.tap(_text('onboarding.next'));
      },
    ),
    Scenario(
      3,
      'onboarding',
      'slide-viaggi',
      route: '/onboarding',
      source: 'lib/features/onboarding/view/onboarding_screen.dart',
      description: 'Ultima slide (viaggi), CTA "Inizia".',
      setup: const AppSetup(onboardingCompleted: false, authenticated: false),
      steps: (app) async {
        await app.tap(_text('onboarding.next'));
        await app.tap(_text('onboarding.next'));
      },
    ),
    Scenario(
      4,
      'login',
      'default',
      route: '/login',
      source: 'lib/features/auth/view/login_screen.dart',
      description:
          'Login con Google; sotto, l\'avviso che continuare vale come '
          'accettazione dei Termini.',
      setup: const AppSetup(authenticated: false, seed: SeedLevel.empty),
      steps: (app) async {},
    ),
  ]),

  Flow('02-tour-ai', 'Tour post-login: import AI guidato', [
    Scenario(
      1,
      'ai-intro',
      'default',
      route: '/onboarding-ai-intro',
      source: 'lib/features/tour/view/ai_onboarding_intro_screen.dart',
      description:
          'Prima schermata dopo il login: invito a fotografare i capi.',
      setup: const AppSetup(
        seed: SeedLevel.empty,
        tourStep: OnboardingStep.aiIntro,
      ),
      steps: (app) async {},
    ),
    Scenario(
      2,
      'ai-intro',
      'scelta-sorgente',
      route: '/onboarding-ai-intro',
      source: 'lib/features/tour/view/ai_onboarding_intro_screen.dart',
      description: 'Bottom sheet fotocamera / galleria.',
      setup: const AppSetup(
        seed: SeedLevel.empty,
        tourStep: OnboardingStep.aiIntro,
      ),
      steps: (app) async {
        await app.tap(_text('onboarding_tour.ai_intro.cta'));
      },
    ),
    Scenario(
      3,
      'ai-risultati',
      'analisi-in-corso',
      route: '/onboarding-ai-intro/results',
      source: _aiResults,
      description: 'Analisi GPT in corso (foto 2 di 3).',
      setup: AppSetup(
        seed: SeedLevel.empty,
        tourStep: OnboardingStep.aiIntro,
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(
            () => FakeAiImport(aiLoadingState()),
          ),
        ],
      ),
      steps: (app) async {
        await app.push('/onboarding-ai-intro/results');
      },
    ),
    Scenario(
      4,
      'ai-risultati',
      'capi-riconosciuti',
      route: '/onboarding-ai-intro/results',
      source: _aiResults,
      description:
          'Capi riconosciuti, CTA "Salva" (primo import, senza scelta casa).',
      setup: AppSetup(
        seed: SeedLevel.empty,
        tourStep: OnboardingStep.aiIntro,
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(FakeAiImport.new),
        ],
      ),
      steps: (app) async {
        await app.push('/onboarding-ai-intro/results');
        await _emitAi(app, aiResultsState(houseId: null));
      },
    ),
  ]),

  Flow('02b-tour', 'Tour dopo la prova AI: tre suggerimenti', [
    Scenario(
      1,
      'tour',
      'casa-creata',
      route: '/houses/:id',
      source: 'lib/features/tour/widgets/tour_trigger_wrapper.dart',
      description: 'Dentro la casa creata dalla prova AI: tocca il nome.',
      setup: const AppSetup(
        tourStep: OnboardingStep.houseDetailTooltip,
        tourHouseId: kHomeId,
      ),
      steps: (app) async {
        await _houseDetail(app);
        await app.settle(frames: 30);
      },
    ),
    Scenario(
      2,
      'tour',
      'crea',
      route: '/',
      source: 'lib/features/tour/controllers/tour_orchestrator.dart',
      description: 'Sul bottone Crea: viaggi, case e scansioni partono da qui.',
      setup: const AppSetup(tourStep: OnboardingStep.createTripTooltip),
      steps: (app) async {
        await app.go('/');
        await app.settle(frames: 30);
      },
    ),
    Scenario(
      3,
      'tour',
      'nuovo-viaggio',
      route: '/new-trip',
      source: 'lib/features/tour/widgets/tour_trigger_wrapper.dart',
      description: 'Nel nuovo viaggio: destinazione, date, poi la valigia.',
      setup: const AppSetup(tourStep: OnboardingStep.tripCreationTooltip),
      steps: (app) async {
        await app.go('/');
        await app.push('/new-trip');
        await app.settle(frames: 30);
      },
    ),
  ]),

  Flow('03-case', 'Tab Case: elenco e creazione', [
    Scenario(
      1,
      'case',
      'vuoto',
      route: '/',
      source: _houses,
      description: 'Nessuna casa: empty state con CTA.',
      setup: const AppSetup(seed: SeedLevel.empty),
      steps: (app) => app.go('/'),
    ),
    Scenario(
      2,
      'case',
      'sincronizzazione',
      route: '/',
      source: _houses,
      description: 'Lista vuota durante il primo download: skeleton.',
      setup: AppSetup(
        seed: SeedLevel.empty,
        extraOverrides: [syncingProvider.overrideWith(_SyncingForever.new)],
      ),
      steps: (app) => app.go('/'),
    ),
    Scenario(
      3,
      'case',
      'elenco',
      route: '/',
      source: _houses,
      description:
          'Quattro case: principale (puntina), badge "in viaggio"/"ospite", nome lungo, casa vuota.',
      steps: (app) => app.go('/'),
    ),
    Scenario(
      4,
      'case',
      'menu-contestuale',
      route: '/',
      source: 'lib/shared/widgets/entity_context_menu.dart',
      description: 'Long press su una casa: copia / principale / elimina.',
      steps: (app) async {
        await app.go('/');
        await app.longPress(find.text('Casa al mare'));
      },
    ),
    Scenario(
      5,
      'crea',
      'foglio-da-case',
      route: '/',
      source: 'lib/shared/widgets/create_sheet.dart',
      description:
          'Crea dalla tab Case: Scansiona con AI (con la casa), link a mano, poi Nuova casa e Nuovo viaggio.',
      steps: _openCreateSheet,
    ),
    Scenario(
      6,
      'casa-form',
      'nuova',
      source: 'lib/features/houses/view/add_edit_house_screen.dart',
      description: 'Bottom sheet nuova casa (dalla riga in fondo alla lista).',
      steps: (app) async {
        await app.go('/');
        await app.tap(find.text('houses.new_house_row'.tr()));
      },
    ),
    Scenario(
      7,
      'casa-form',
      'ricerca-luogo',
      source: 'lib/shared/widgets/location_autocomplete_field.dart',
      description: 'Ricerca del luogo: risultati sotto il campo.',
      steps: (app) async {
        await app.go('/');
        await app.tap(find.text('houses.new_house_row'.tr()));
        await app.tester.enterText(
          find.descendant(
            of: find.byKey(const Key('house_sheet_location')),
            matching: find.byType(TextField),
          ),
          'Lis',
        );
        await app.settle();
      },
    ),
  ]),

  Flow('04-dettaglio-casa', 'Dettaglio casa: inventario e gestione', [
    Scenario(
      1,
      'dettaglio-casa',
      'pieno',
      route: '/houses/:id',
      source: _houseDetailSrc,
      description:
          'Inventario a gruppi con etichette fisse, filtro spazi, barra con rapid-fire e AI; gestisci e ricerca in alto.',
      steps: _houseDetail,
    ),
    Scenario(
      2,
      'dettaglio-casa',
      'filtro-spazio',
      route: '/houses/:id',
      source: _houseDetailSrc,
      description: 'Filtro sullo spazio "Armadio camera".',
      steps: (app) async {
        await _houseDetail(app);
        await app.tap(find.textContaining('Armadio camera'));
      },
    ),
    Scenario(
      3,
      'dettaglio-casa',
      'vuota',
      route: '/houses/:id',
      source: 'lib/features/items/view/items_screen.dart',
      description:
          'Casa vuota: "Scansiona con AI" e il link "scrivili a mano".',
      steps: (app) => _houseDetail(app, kEmptyHouseId),
    ),
    Scenario(
      4,
      'dettaglio-casa',
      'rapid-fire',
      route: '/houses/:id',
      source: 'lib/features/items/widgets/rapid_fire_input.dart',
      description:
          'Pagina "aggiungi": la casa sparisce, sopra il campo le pillole delle categorie col nome intero.',
      steps: (app) async {
        await _houseDetail(app);
        await app.tap(find.byType(TextField).last);
        await app.enterText(find.byType(TextField).last, 'Pigiama');
      },
    ),
    Scenario(
      5,
      'dettaglio-casa',
      'selezione-multipla',
      route: '/houses/:id',
      source: _houseDetailSrc,
      description:
          'Selezione: caselle arancio, velo neutro, barra Sposta · In viaggio · Elimina.',
      steps: (app) async {
        await _houseDetail(app);
        await app.longPress(find.text('Maglione di lana'));
        await app.tap(find.text('Jeans blu'));
      },
    ),
    Scenario(
      6,
      'sposta-oggetti',
      'scelta-casa',
      source: 'lib/features/items/view/bulk_move_sheet.dart',
      description:
          'Foglio "Sposta": tocco sulla casa (o sullo spazio) e l\'oggetto è spostato.',
      steps: (app) async {
        await _houseDetail(app);
        await app.longPress(find.text('Maglione di lana'));
        await app.tap(find.byKey(const Key('selection_move')));
      },
    ),
    Scenario(
      7,
      'aggiungi-a-viaggio',
      'scelta-viaggio',
      source: 'lib/features/trips/view/trip_picker_sheet.dart',
      description: 'Sheet "scegli un viaggio" dalla selezione multipla.',
      steps: (app) async {
        await _houseDetail(app);
        await app.longPress(find.text('Maglione di lana'));
        await app.tap(find.byKey(const Key('selection_trip')));
      },
    ),
    Scenario(
      8,
      'gestisci-casa',
      'menu',
      source: 'lib/features/houses/view/house_manage_sheet.dart',
      description:
          'Sheet gestione con "Seleziona oggetti" in cima, poi modifica, principale, spazi, bagagli ed elimina.',
      steps: _openManageSheet,
    ),
    Scenario(
      9,
      'casa-form',
      'modifica',
      source: 'lib/features/houses/view/add_edit_house_screen.dart',
      description: 'Modifica casa esistente.',
      steps: (app) async {
        await _openManageSheet(app);
        await app.tap(
          find.ancestor(of: _icon(Icons.edit), matching: find.byType(ListTile)),
        );
      },
    ),
    Scenario(
      10,
      'spazi',
      'elenco',
      source: 'lib/features/spaces/view/spaces_management_screen.dart',
      description: 'Gestione spazi della casa.',
      steps: (app) async {
        await _openManageSheet(app);
        await app.tap(_text('spaces.manage'));
      },
    ),
    Scenario(
      11,
      'bagagli',
      'elenco',
      source: 'lib/features/luggages/view/luggages_management_screen.dart',
      description: 'Gestione bagagli della casa.',
      steps: (app) async {
        await _openManageSheet(app);
        await app.tap(_text('luggages.manage'));
      },
    ),
    Scenario(
      12,
      'casa',
      'conferma-eliminazione',
      source: _houseDetailSrc,
      description: 'Dialog di conferma eliminazione casa.',
      steps: (app) async {
        await _openManageSheet(app);
        await app.tap(find.byType(ListTile).last);
      },
    ),
    Scenario(
      13,
      'dettaglio-casa',
      'non-trovata',
      route: '/houses/:id',
      source: _houseDetailSrc,
      description: 'Id inesistente (es. casa eliminata da un altro device).',
      steps: (app) => _houseDetail(app, 'casa-che-non-esiste'),
    ),
    Scenario(
      14,
      'dettaglio-casa',
      'ricerca',
      route: '/houses/:id',
      source: _houseDetailSrc,
      description:
          'Ricerca nella casa: "cal" lascia i soli oggetti che corrispondono.',
      steps: (app) async {
        await _houseDetail(app);
        await app.tap(find.byKey(const Key('house_search')));
        await app.enterText(find.byKey(const Key('house_search_field')), 'cal');
      },
    ),
    Scenario(
      15,
      'dettaglio-casa',
      'gruppo-chiuso',
      route: '/houses/:id',
      source: _houseDetailSrc,
      description: 'Gruppo Vestiti chiuso toccando la sua etichetta.',
      steps: (app) async {
        await _houseDetail(app);
        await app.tap(find.textContaining('Vestiti ·'));
      },
    ),
    Scenario(
      16,
      'dettaglio-casa',
      'temporanei',
      route: '/houses/:id',
      source: _houseDetailSrc,
      description:
          'Casa al mare: gruppo Temporanei in cima, con la provenienza nell\'etichetta.',
      steps: (app) => _houseDetail(app, kSeaHouseId),
    ),
    Scenario(
      17,
      'dettaglio-casa',
      'aggiungi-gia-in-casa',
      route: '/houses/:id',
      source: _houseDetailSrc,
      description: 'Pagina "aggiungi": scrivendo "calz" compare Già in casa.',
      steps: (app) async {
        await _houseDetail(app);
        await app.tap(find.byType(TextField).last);
        await app.enterText(find.byType(TextField).last, 'calz');
      },
    ),
    Scenario(
      18,
      'sposta-oggetti',
      'scelta-spazio',
      source: 'lib/features/items/view/bulk_move_sheet.dart',
      description:
          'Da Casa al mare, seleziona Infradito e scegli Casa Milano: il foglio mostra gli spazi e Senza spazio.',
      steps: (app) async {
        await _houseDetail(app, kSeaHouseId);
        await app.longPress(find.text('Infradito'));
        await app.tap(find.byKey(const Key('selection_move')));
        await app.tap(find.text('Casa Milano'));
      },
    ),
  ]),

  Flow('05-oggetti', 'Oggetti: creazione e modifica', [
    Scenario(
      1,
      'oggetto-aggiungi',
      'da-crea',
      source: _houseDetailSrc,
      description:
          'Crea → "scrivili a mano": pagina "aggiungi" della casa con il campo attivo.',
      steps: (app) async {
        await _openCreateSheet(app);
        await app.tap(find.byKey(const Key('create_manual_items')));
      },
    ),
    Scenario(
      2,
      'oggetto-scheda',
      'modifica',
      source: 'lib/features/items/view/item_sheet.dart',
      description:
          'Tocco su un oggetto: la scheda oggetto in modifica, la stessa della '
          'creazione. Nome in un campo, categorie su una riga (scelta piena), '
          'quantità e spazio accanto all\'etichetta, Dettagli con la nota.',
      steps: (app) async {
        await _houseDetail(app);
        await app.tap(find.text('Maglione di lana'));
      },
    ),
    Scenario(
      3,
      'oggetto-scheda',
      'menu',
      source: 'lib/features/items/view/item_sheet.dart',
      description:
          'Menu ⋮ della scheda: Sposta in un\'altra casa ed Elimina (rosso).',
      steps: (app) async {
        await _houseDetail(app);
        await app.tap(find.text('Maglione di lana'));
        await app.tap(find.byKey(const Key('item_sheet_menu')));
      },
    ),
  ]),

  Flow('06-import-ai', 'Import AI da dettaglio casa', [
    Scenario(
      1,
      'import-ai',
      'scelta-sorgente',
      route: '/houses/:id',
      source: _houseDetailSrc,
      description:
          'Foglio Galleria/Fotocamera aperto dal bottone AI della casa.',
      setup: AppSetup(
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(
            () => FakeAiImport(const AiImportState()),
          ),
        ],
      ),
      steps: (app) async {
        await _houseDetail(app);
        await app.tap(_icon(Icons.auto_awesome));
        expect(_text('ai_import.source_gallery'), findsOneWidget);
        expect(_text('ai_import.source_camera'), findsOneWidget);
      },
    ),
    Scenario(
      2,
      'ai-risultati',
      'analisi-in-corso',
      route: '/houses/:id/ai-import/results',
      source: _aiResults,
      description: 'Analisi in corso.',
      setup: AppSetup(
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(
            () => FakeAiImport(aiLoadingState()),
          ),
        ],
      ),
      steps: (app) async {
        await _houseDetail(app);
        await app.push('/houses/$kHomeId/ai-import/results');
      },
    ),
    Scenario(
      3,
      'ai-risultati',
      'capi-riconosciuti',
      route: '/houses/:id/ai-import/results',
      source: _aiResults,
      description: 'Risultati con casa di destinazione selezionata.',
      setup: AppSetup(
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(FakeAiImport.new),
        ],
      ),
      steps: (app) async {
        await _houseDetail(app);
        await app.push('/houses/$kHomeId/ai-import/results');
        await _emitAi(app, aiResultsState());
      },
    ),
    Scenario(
      4,
      'ai-risultati',
      'scelta-casa',
      route: '/houses/:id/ai-import/results',
      source: _aiResults,
      description: 'Sheet di scelta della casa di destinazione.',
      setup: AppSetup(
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(FakeAiImport.new),
        ],
      ),
      steps: (app) async {
        await _houseDetail(app);
        await app.push('/houses/$kHomeId/ai-import/results');
        await _emitAi(app, aiResultsState());
        await app.tap(find.byKey(const Key('ai_destination')));
      },
    ),
    Scenario(
      5,
      'ai-risultati',
      'un-capo-tolto',
      route: '/houses/:id/ai-import/results',
      source: _aiResults,
      description: 'Secondo capo escluso dalla selezione senza rimuoverlo.',
      setup: AppSetup(
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(FakeAiImport.new),
        ],
      ),
      steps: (app) async {
        await _houseDetail(app);
        await app.push('/houses/$kHomeId/ai-import/results');
        await _emitAi(app, aiResultsState());
        await app.tap(find.byType(Checkbox).at(1));
      },
    ),
    Scenario(
      6,
      'ai-risultati',
      'nome-in-modifica',
      route: '/houses/:id/ai-import/results',
      source: _aiResults,
      description: 'Primo nome AI aperto in modifica.',
      setup: AppSetup(
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(FakeAiImport.new),
        ],
      ),
      steps: (app) async {
        await _houseDetail(app);
        await app.push('/houses/$kHomeId/ai-import/results');
        await _emitAi(app, aiResultsState());
        await app.tap(find.byKey(const Key('ai_result_name')).first);
      },
    ),
    Scenario(
      7,
      'ai-risultati',
      'c-e-gia',
      route: '/houses/:id/ai-import/results',
      source: _aiResults,
      description: 'Foglio “C’è già?” aperto per la T-shirt presente in casa.',
      setup: AppSetup(
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(FakeAiImport.new),
        ],
      ),
      steps: (app) async {
        await _houseDetail(app);
        await app.push('/houses/$kHomeId/ai-import/results');
        await _emitAi(app, aiResultsState());
        await app.tap(find.byKey(const Key('ai_already_here')).at(1));
      },
    ),
    Scenario(
      8,
      'ai-risultati',
      'collegato',
      route: '/houses/:id/ai-import/results',
      source: _aiResults,
      description: 'T-shirt riconosciuta collegata all’oggetto già presente.',
      setup: AppSetup(
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(FakeAiImport.new),
        ],
      ),
      steps: (app) async {
        await _houseDetail(app);
        await app.push('/houses/$kHomeId/ai-import/results');
        await _emitAi(app, aiResultsState());
        await app.tap(find.byKey(const Key('ai_already_here')).at(1));
        await app.tap(find.byKey(const Key('add_details_item-0')));
      },
    ),
    Scenario(
      9,
      'ai-risultati',
      'casa-vuota',
      route: '/houses/:id/ai-import/results',
      source: _aiResults,
      description: 'Risultati per una casa vuota senza azioni “C’è già?”.',
      setup: AppSetup(
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(FakeAiImport.new),
        ],
      ),
      steps: (app) async {
        await _houseDetail(app, kEmptyHouseId);
        await app.push('/houses/$kEmptyHouseId/ai-import/results');
        await _emitAi(app, aiResultsState(houseId: kEmptyHouseId));
      },
    ),
    Scenario(
      10,
      'ai-risultati',
      'conferma-uscita',
      route: '/houses/:id/ai-import/results',
      source: _aiResults,
      description: 'Conferma di uscita con capi ancora selezionati.',
      setup: AppSetup(
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(FakeAiImport.new),
        ],
      ),
      steps: (app) async {
        await _houseDetail(app);
        await app.push('/houses/$kHomeId/ai-import/results');
        await _emitAi(app, aiResultsState());
        await app.tap(find.byKey(const Key('ai_results_close')));
      },
    ),
    Scenario(
      11,
      'ai-risultati',
      'errore-parziale',
      route: '/houses/:id/ai-import/results',
      source: _aiResults,
      description: 'Alcune foto analizzate, poi errore di rete con retry.',
      setup: AppSetup(
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(FakeAiImport.new),
        ],
      ),
      steps: (app) async {
        await _houseDetail(app);
        await app.push('/houses/$kHomeId/ai-import/results');
        await _emitAi(app, aiPartialFailureState());
      },
    ),
    Scenario(
      12,
      'ai-risultati',
      'errore-rete',
      route: '/houses/:id/ai-import/results',
      source: _aiResults,
      description: 'Nessun risultato: errore di rete.',
      setup: AppSetup(
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(FakeAiImport.new),
        ],
      ),
      steps: (app) async {
        await _houseDetail(app);
        await app.push('/houses/$kHomeId/ai-import/results');
        await _emitAi(app, aiFailureState(AiFailureReason.network));
      },
    ),
    Scenario(
      13,
      'ai-risultati',
      'limite-raggiunto',
      route: '/houses/:id/ai-import/results',
      source: _aiResults,
      description: 'Quota AI esaurita.',
      setup: AppSetup(
        extraOverrides: [
          aiImportNotifierProvider.overrideWith(FakeAiImport.new),
        ],
      ),
      steps: (app) async {
        await _houseDetail(app);
        await app.push('/houses/$kHomeId/ai-import/results');
        await _emitAi(app, aiFailureState(AiFailureReason.limitReached));
      },
    ),
  ]),

  Flow('07-viaggi', 'Tab Viaggi: elenco e filtri', [
    Scenario(
      1,
      'viaggi',
      'vuoto',
      route: '/trips',
      source: _trips,
      description: 'Nessun viaggio.',
      setup: const AppSetup(seed: SeedLevel.empty),
      steps: (app) => app.go('/trips'),
    ),
    Scenario(
      2,
      'viaggi',
      'prossimi',
      route: '/trips',
      source: _trips,
      description:
          'Tab "Prossimi": cartolina in cima (viaggio in corso) con la pila dietro.',
      steps: (app) => app.go('/trips'),
    ),
    Scenario(
      3,
      'viaggi',
      'prossimi-scorrimento',
      route: '/trips',
      source: 'lib/features/trips/view/widgets/postcard/postcard_pile.dart',
      description:
          'Prossimi dopo uno scorrimento: seconda cartolina (Lisbona, tappa '
          'Sintra, due bagagli).',
      steps: (app) async {
        await app.go('/trips');
        await _swipePile(app);
      },
    ),
    Scenario(
      4,
      'viaggi',
      'prossimi-valigia-vuota',
      route: '/trips',
      source: 'lib/features/trips/view/widgets/postcard/postcard_pile.dart',
      description:
          'Prossimi, secondo scorrimento: Torino, senza oggetti né bagagli.',
      steps: (app) async {
        await app.go('/trips');
        await _swipePile(app);
        await _swipePile(app);
      },
    ),
    Scenario(
      5,
      'viaggi',
      'passati',
      route: '/trips',
      source: _trips,
      description: 'Tab "Passati".',
      steps: (app) async {
        await app.go('/trips');
        await app.tap(_text('trips.filter_past'));
      },
    ),
    Scenario(
      6,
      'viaggi',
      'salvati',
      route: '/trips',
      source: _trips,
      description: 'Tab "Salvati".',
      steps: (app) async {
        await app.go('/trips');
        await app.tap(_text('trips.filter_saved'));
      },
    ),
    Scenario(
      7,
      'viaggi',
      'menu-contestuale',
      route: '/trips',
      source: 'lib/shared/widgets/entity_context_menu.dart',
      description:
          'Pressione lunga sulla cartolina in cima: copia / salva / elimina.',
      steps: (app) async {
        await app.go('/trips');
        await app.longPress(find.byKey(const Key('postcard_pile_top')));
      },
    ),
    Scenario(
      8,
      'viaggi',
      'prossimi-vuoto',
      route: '/trips',
      source: _trips,
      description:
          'Prossimi senza viaggi in corso o futuri: solo i passati restano. '
          'Lo stato si ottiene eliminando i viaggi futuri dal repository.',
      steps: (app) async {
        await app.go('/trips');
        await app.tester.runAsync(() async {
          final notifier = app.container.read(tripNotifierProvider.notifier);
          for (final id in [
            kActiveTripId,
            kUpcomingTripId,
            kEmptyTripId,
            kSavedTripId,
          ]) {
            await notifier.deleteTrip(id);
          }
        });
        await app.settle();
      },
    ),
    Scenario(
      9,
      'crea',
      'foglio-da-viaggi',
      route: '/trips',
      source: 'lib/shared/widgets/create_sheet.dart',
      description:
          'Crea dalla tab Viaggi: Nuovo viaggio sale sopra Nuova casa.',
      steps: (app) => _openCreateSheet(app, '/trips'),
    ),
    Scenario(
      10,
      'viaggi',
      'dopo-passo-1',
      route: '/trips',
      source: 'lib/features/trips/view/new_trip_screen.dart',
      description:
          'Passo 1 compilato (Siviglia) e "Prepara la valigia più tardi": la '
          'pila si apre sul viaggio appena creato, in cima.',
      steps: (app) async {
        await _openNewTrip(app);
        await _searchPlace(app, _placeField(), 'Siviglia');
        await _pickTripDates(
          app,
          departure: _nextMonthDay(20),
          end: _nextMonthDay(23),
        );
        await app.tap(find.byKey(const Key('new_trip_later')));
        // Il viaggio appena creato è la cartolina in cima alla pila.
        expect(
          find.descendant(
            of: find.byKey(const Key('postcard_pile_top')),
            matching: find.text('Siviglia'),
          ),
          findsWidgets,
        );
      },
    ),
  ]),

  Flow('08-nuovo-viaggio', 'Creazione viaggio: passo 1 in ordine di itinerario', [
    Scenario(
      1,
      'nuovo-viaggio',
      'vuoto',
      route: '/new-trip',
      source: _addTrip,
      description:
          'Passo 1 appena aperto: "Dove vai?", "Quando?", itinerario vuoto, '
          'nome del viaggio, "Avanti" spento.',
      steps: (app) async {
        await _openNewTrip(app);
      },
    ),
    Scenario(
      2,
      'nuovo-viaggio',
      'dove-vai-case',
      route: '/new-trip',
      source: _placeSearchSrc,
      description:
          'Tocco su "Dove vai?": le case in cima alla lista, poi i luoghi '
          'quando si scrive.',
      steps: (app) async {
        await _openNewTrip(app);
        await app.tap(_placeField());
      },
    ),
    Scenario(
      3,
      'nuovo-viaggio',
      'compilato-una-tappa',
      route: '/new-trip',
      source: _addTrip,
      description:
          'Meta Lisbona e date: l\'itinerario ha la tappa di arrivo e il '
          'ritorno calcolato, "Avanti" acceso.',
      steps: (app) async {
        await _fillStep1(app);
      },
    ),
    Scenario(
      4,
      'tappa-nuova',
      'foglio-vuoto',
      route: '/new-trip',
      source: _stopSheetSrc,
      description:
          'Foglio "Nuova tappa" appena aperto, con la partenza dalla meta.',
      steps: (app) async {
        await _fillStep1(app);
        await _openStopSheet(app);
      },
    ),
    Scenario(
      5,
      'tappa-nuova',
      'foglio-compilato',
      route: '/new-trip',
      source: _stopSheetSrc,
      description:
          'Foglio con Sintra scelta e "Fino a quando?" impostato: la riga dice '
          'il ritorno e il numero di notti.',
      steps: (app) async {
        await _fillStep1(app);
        await _openStopSheet(app);
        await _fillStopPlace(app, 'Sintra');
        await _fillStopEnd(app, _nextMonthDay(15));
      },
    ),
    Scenario(
      6,
      'nuovo-viaggio',
      'due-tappe',
      route: '/new-trip',
      source: _addTrip,
      description:
          'Due tappe: Lisbona e Sintra, poi il ritorno in fondo alla catena. '
          '"Aggiungi tappa" resta in fondo all\'itinerario.',
      steps: (app) async {
        await _fillStep1(app);
        await _addSintraStop(app, end: _nextMonthDay(15));
      },
    ),
    Scenario(
      7,
      'nuovo-viaggio',
      'dati-mancanti',
      route: '/new-trip',
      source: _addTrip,
      description:
          'Tocco su "Avanti" a modulo vuoto: il campo "Dove vai?" e il campo '
          'delle date si colorano di errore, con il messaggio sotto ciascuno.',
      steps: (app) async {
        await _openNewTrip(app);
        await app.tap(find.byKey(const Key('new_trip_next')));
      },
    ),
    Scenario(
      8,
      'tappa',
      'zero-notti',
      route: '/new-trip',
      source: _addTrip,
      description:
          'La meta finisce il giorno in cui finisce la tappa: la tappa ha zero '
          'notti, il messaggio la segnala e "Avanti" è spento.',
      steps: (app) async {
        await _fillStep1(app);
        await _addSintraStop(app, end: _nextMonthDay(15));
        await _pickTripDates(
          app,
          departure: _nextMonthDay(10),
          end: _nextMonthDay(15),
        );
      },
    ),
    Scenario(
      9,
      'date-viaggio',
      'foglio-date',
      source: _datesSheetSrc,
      description:
          'Foglio "Quando?" a schermo quasi intero, con il calendario del mese '
          'prossimo e "Conferma date" spento.',
      steps: (app) async {
        await _openNewTrip(app);
        await app.tap(find.byKey(const Key('new_trip_dates')));
      },
    ),
  ]),

  Flow('09-dettaglio-viaggio', 'Dettaglio viaggio e pagina valigia', [
    Scenario(
      1,
      'dettaglio-viaggio',
      'checklist',
      route: '/trips/:id',
      source: _tripDetailSrc,
      description:
          'Viaggio futuro con tappe, bagagli e oggetti parzialmente spuntati.',
      steps: _tripDetail,
    ),
    Scenario(
      2,
      'dettaglio-viaggio',
      'in-corso',
      route: '/trips/:id',
      source: _tripDetailSrc,
      description: 'Viaggio in corso verso una casa.',
      steps: (app) => _tripDetail(app, kActiveTripId),
    ),
    Scenario(
      3,
      'dettaglio-viaggio',
      'senza-oggetti',
      route: '/trips/:id',
      source: _tripDetailSrc,
      description: 'Viaggio senza oggetti: CTA "Prepara la valigia".',
      steps: (app) => _tripDetail(app, kEmptyTripId),
    ),
    Scenario(
      4,
      'viaggio',
      'conferma-eliminazione',
      source: _tripDetailSrc,
      description: 'Dialog di eliminazione viaggio, dal menu ⋮.',
      steps: (app) async {
        await _tripDetail(app);
        await app.tap(find.byKey(const Key('trip_detail_menu')));
        await app.tap(_text('common.delete'));
      },
    ),
    Scenario(
      5,
      'modifica-info-viaggio',
      'default',
      route: '/trips/:id/edit-info',
      source: 'lib/features/trips/view/edit_trip_info_screen.dart',
      description: 'Modifica nome, destinazione, date e tappe.',
      steps: (app) async {
        await _tripDetail(app);
        await app.tap(find.byKey(const Key('trip_detail_summary')));
      },
    ),
    Scenario(
      6,
      'valigia',
      'da-modifica-oggetti',
      route: '/trips/:id/edit-items',
      source: _packSrc,
      description:
          'Pagina valigia aperta da "Modifica valigia": riepilogo, bagagli, '
          'ricerca e oggetti della casa proposta. Senza indicatore dei passi.',
      steps: (app) async {
        await _tripDetail(app);
        await app.tap(find.byKey(const Key('trip_detail_cta')));
      },
    ),
    Scenario(
      7,
      'valigia',
      'dal-passo-1',
      route: '/trips/:id/edit-items',
      source: _packSrc,
      description:
          'Passo 2 di "Nuovo viaggio" appena salvato il passo 1: indicatore dei '
          'passi con "Viaggio" fatto, "Valigia" attivo, "Fatto" a zero oggetti.',
      steps: (app) async {
        await _fillStep1(app);
        await app.tap(find.byKey(const Key('new_trip_next')));
      },
    ),
    Scenario(
      8,
      'valigia',
      'con-scelte',
      route: '/trips/:id/edit-items',
      source: _packSrc,
      description:
          'Valigia con scelte e quantità: un bagaglio in più e la quantità di '
          '"Calzini" diminuita di uno. "Fatto" dice quanti oggetti.',
      steps: (app) async {
        await _tripDetail(app);
        await app.tap(find.byKey(const Key('trip_detail_cta')));
        await app.tap(find.text('Valigia grande'));
        // Calzini è a 7: il "+" è spento al massimo della casa, il "-" no. Si
        // toglie un capo senza deselezionare la riga.
        final calzini = find.byWidgetPredicate(
          (w) => w is QuantityStepper && w.value == 7,
        );
        await app.tap(
          find.descendant(
            of: calzini.first,
            matching: find.byIcon(Icons.remove_circle_outline),
          ),
        );
      },
    ),
    Scenario(
      9,
      'valigia',
      'dopo-cambio-casa',
      route: '/trips/:id/edit-items',
      source: _packSrc,
      description:
          'Dopo aver scelto un\'altra casa dal selettore "Da": gli oggetti '
          'della nuova casa, la selezione del viaggio resta.',
      steps: (app) async {
        await _tripDetail(app);
        await app.tap(find.byKey(const Key('trip_detail_cta')));
        await app.tap(find.widgetWithText(PackPill, 'Casa Milano'));
        await app.tap(find.text('Casa al mare'));
      },
    ),
    Scenario(
      10,
      'valigia',
      'ricerca-senza-esito',
      route: '/trips/:id/edit-items',
      source: _packSrc,
      description:
          'Ricerca di un oggetto che nella casa non c\'è: al posto dei '
          'risultati la riga "Aggiungi «Ciabatte» in Casa Milano".',
      steps: (app) async {
        await _tripDetail(app);
        await app.tap(find.byKey(const Key('trip_detail_cta')));
        await app.enterText(find.byType(TextField).first, 'Ciabatte');
      },
    ),
    Scenario(
      11,
      'valigia',
      'ricerca-con-esiti',
      route: '/trips/:id/edit-items',
      source: _packSrc,
      description:
          'Ricerca con risultati ma nessuno con quel nome esatto: la riga '
          '"Aggiungi" sta in fondo, dopo gli oggetti trovati.',
      steps: (app) async {
        await _tripDetail(app);
        await app.tap(find.byKey(const Key('trip_detail_cta')));
        await app.enterText(find.byType(TextField).first, 'Mag');
      },
    ),
    Scenario(
      12,
      'valigia',
      'nuovo-oggetto',
      route: '/trips/:id/edit-items',
      source: 'lib/features/items/view/item_sheet.dart',
      description:
          'Toccando "Aggiungi": la scheda oggetto in creazione, col nome '
          'scritto nella ricerca e la categoria proposta (bordata). In fondo '
          '"Lo trovi anche in Casa Milano." e "Aggiungi e metti in valigia".',
      steps: (app) async {
        await _tripDetail(app);
        await app.tap(find.byKey(const Key('trip_detail_cta')));
        await app.enterText(find.byType(TextField).first, 'Ciabatte');
        await app.tap(find.byKey(const Key('pack_add_row')));
      },
    ),
    Scenario(
      13,
      'valigia',
      'casa-vuota',
      route: '/trips/:id/edit-items',
      source: _packSrc,
      description:
          'Casa senza oggetti: stato vuoto senza azioni, con l\'aiuto '
          '"Scrivilo nella ricerca qui sopra per aggiungerlo."',
      steps: (app) async {
        await _tripDetail(app);
        await app.tap(find.byKey(const Key('trip_detail_cta')));
        await app.tap(find.widgetWithText(PackPill, 'Casa Milano'));
        await app.tap(find.widgetWithText(ListTile, 'Monolocale Torino'));
      },
    ),
    Scenario(
      14,
      'dettaglio-viaggio',
      'non-trovato',
      route: '/trips/:id',
      source: _tripDetailSrc,
      description: 'Id inesistente.',
      steps: (app) => _tripDetail(app, 'viaggio-che-non-esiste'),
    ),
    Scenario(
      15,
      'valigia',
      'meteo-previsione',
      route: '/trips/:id/edit-items',
      source: _packWeatherSrc,
      description:
          'Viaggio in corso verso una casa: il meteo della casa dai giorni '
          'che restano, con la previsione e "Aggiorna".',
      steps: (app) => _pack(app, kActiveTripId),
    ),
    Scenario(
      16,
      'valigia',
      'meteo-tetto',
      route: '/trips/:id/edit-items',
      source: _packWeatherSrc,
      description:
          'Tetto giornaliero del meteo finito e nessuna copia: al posto delle '
          'tappe il messaggio discreto, senza "Aggiorna".',
      setup: AppSetup(
        extraOverrides: [
          tripWeatherServiceProvider.overrideWithValue(
            FakeTripWeatherCapReached(),
          ),
        ],
      ),
      steps: (app) => _pack(app, kUpcomingTripId),
    ),
    Scenario(
      17,
      'valigia',
      'meteo-non-disponibile',
      route: '/trips/:id/edit-items',
      source: _packWeatherSrc,
      description:
          'Viaggio verso una casa senza località: il meteo non si può '
          'chiedere e la sezione lo dice.',
      steps: (app) => _pack(app, kEmptyTripId),
    ),
    Scenario(
      18,
      'meteo',
      'dettaglio-tappa',
      route: '/trips/:id/weather',
      source: 'lib/features/trips/view/trip_weather_screen.dart',
      description:
          'Toccando la tappa con la previsione: i giorni che restano, ognuno '
          'con il riepilogo e le sei fasce di quattro ore.',
      steps: (app) async {
        await _pack(app, kActiveTripId);
        await app.tap(find.text('Casa al mare').last);
      },
    ),
  ]),

  Flow('10-profilo', 'Tab Profilo: impostazioni e account', [
    Scenario(
      1,
      'profilo',
      'default',
      route: '/profile',
      source: _profile,
      description: 'Impostazioni, uso AI, sync, privacy, account.',
      steps: (app) async {
        await app.go('/');
        await app.push('/profile');
      },
    ),
    Scenario(
      2,
      'profilo',
      'fine-pagina',
      route: '/profile',
      source: _profile,
      description: 'Scroll in fondo: info app, esci, elimina account.',
      steps: (app) async {
        await app.go('/');
        await app.push('/profile');
        await app.tester.drag(
          find.byType(ListView).first,
          const Offset(0, -1200),
        );
        await app.settle();
      },
    ),
    Scenario(
      3,
      'profilo',
      'sync-in-sospeso',
      route: '/profile',
      source: 'lib/features/profile/widgets/sync_status_tile.dart',
      description: 'Modifiche non sincronizzate.',
      setup: const AppSetup(unsyncedChanges: 3),
      steps: (app) async {
        await app.go('/');
        await app.push('/profile');
      },
    ),
    Scenario(
      4,
      'lingua',
      'dialog',
      source: 'lib/features/profile/view/dialogs/profile_language_dialog.dart',
      description: 'Dialog scelta lingua.',
      steps: (app) async {
        await app.go('/');
        await app.push('/profile');
        await app.tap(_text('settings.language'));
      },
    ),
    Scenario(
      5,
      'tema',
      'dialog',
      source: 'lib/features/profile/view/dialogs/profile_theme_dialog.dart',
      description: 'Dialog scelta tema.',
      steps: (app) async {
        await app.go('/');
        await app.push('/profile');
        await app.tap(_text('settings.theme'));
      },
    ),
    Scenario(
      6,
      'elimina-account',
      'dialog',
      source:
          'lib/features/profile/view/dialogs/profile_delete_account_dialog.dart',
      description: 'Conferma eliminazione account.',
      steps: (app) async {
        await app.go('/');
        await app.push('/profile');
        await app.tester.drag(
          find.byType(ListView).first,
          const Offset(0, -1200),
        );
        await app.settle();
        await app.tap(_text('profile.delete_account_cta'));
      },
    ),
  ]),

  Flow('12-errori', 'Errori di navigazione', [
    Scenario(
      1,
      'errore-router',
      'rotta-sconosciuta',
      source: 'lib/core/routing/app_router.dart',
      description: 'Pagina di errore del router (link rotto).',
      steps: (app) => app.go('/rotta/che/non/esiste'),
    ),
  ]),
];

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    useSystemSqlite();
    await loadRealFonts();
    await createPhotoFixtures();
  });
  tearDownAll(Manifest.write);

  final themes = _themesArg
      .split(',')
      .map((t) => ShotTheme.values.byName(t.trim()))
      .toList();

  for (final flow in flows) {
    group(flow.id, () {
      for (final s in flow.scenarios) {
        for (final theme in themes) {
          final name =
              '${s.order.toString().padLeft(2, '0')} ${s.screen} '
              '${s.state} [${theme.name}]';
          testWidgets(name, skip: !_enabled, (tester) async {
            final app = await ScreenshotApp.start(
              tester,
              theme: theme,
              setup: s.setup,
            );
            await s.steps(app);
            await app.capture(
              Shot(
                flow: flow.id,
                flowTitle: flow.title,
                order: s.order,
                screen: s.screen,
                state: s.state,
                source: s.source,
                description: s.description,
                route: s.route,
                theme: theme,
              ),
            );
            await app.finish();
          });
        }
      }
    });
  }
}
