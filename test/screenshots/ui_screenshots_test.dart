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

Future<void> _openManageSheet(ScreenshotApp app) async {
  await _houseDetail(app);
  await app.tap(_icon(Icons.more_horiz));
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

// ── Flussi ───────────────────────────────────────────────────────────────────

const _houses = 'lib/features/houses/view/houses_screen.dart';
const _houseDetailSrc = 'lib/features/houses/view/house_detail_screen.dart';
const _trips = 'lib/features/trips/view/trips_screen.dart';
const _tripDetailSrc = 'lib/features/trips/view/trip_detail_screen.dart';
const _addTrip = 'lib/features/trips/view/add_trip_screen.dart';
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
      'consenso-mancante',
      route: '/login',
      source: 'lib/features/auth/view/login_screen.dart',
      description: 'Login con Google, checkbox privacy non spuntata.',
      setup: const AppSetup(authenticated: false, seed: SeedLevel.empty),
      steps: (app) async {},
    ),
    Scenario(
      5,
      'login',
      'errore-consenso',
      route: '/login',
      source: 'lib/features/auth/view/login_screen.dart',
      description:
          'Tap su "Accedi con Google" senza consenso: snackbar di errore.',
      setup: const AppSetup(authenticated: false, seed: SeedLevel.empty),
      steps: (app) async {
        await app.tap(_text('login.sign_in_google'), frames: 4);
      },
    ),
    Scenario(
      6,
      'login',
      'consenso-dato',
      route: '/login',
      source: 'lib/features/auth/view/login_screen.dart',
      description: 'Checkbox spuntata, CTA abilitata.',
      setup: const AppSetup(authenticated: false, seed: SeedLevel.empty),
      steps: (app) async {
        await app.tap(find.byType(Checkbox));
      },
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
          'Tocco su un oggetto: nome come titolo, righe Categoria / Quantità / Spazio, solo Salva arancio.',
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
          'Menu ⋯ della scheda: Sposta in un\'altra casa ed Elimina (rosso).',
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
      'vuoto',
      route: '/houses/:id/ai-import',
      source: 'lib/features/ai_input/view/ai_clothing_sandbox_screen.dart',
      description: 'Schermata iniziale: scegli immagini.',
      steps: (app) async {
        await _houseDetail(app);
        await app.tap(_icon(Icons.auto_awesome));
      },
    ),
    Scenario(
      2,
      'import-ai',
      'scelta-sorgente',
      route: '/houses/:id/ai-import',
      source: 'lib/features/ai_input/view/ai_clothing_sandbox_screen.dart',
      description: 'Sheet fotocamera / galleria.',
      steps: (app) async {
        await _houseDetail(app);
        await app.tap(_icon(Icons.auto_awesome));
        await app.tap(_text('ai_import.pick_images'));
      },
    ),
    Scenario(
      3,
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
      4,
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
      5,
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
        await app.tap(_icon(Icons.other_houses_outlined));
      },
    ),
    Scenario(
      6,
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
      7,
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
      8,
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
      description: 'Tab "Prossimi": card hero del viaggio in corso + griglia.',
      steps: (app) => app.go('/trips'),
    ),
    Scenario(
      3,
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
      4,
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
      5,
      'viaggi',
      'menu-contestuale',
      route: '/trips',
      source: 'lib/shared/widgets/entity_context_menu.dart',
      description: 'Long press su un viaggio: copia / salva / elimina.',
      steps: (app) async {
        await app.go('/trips');
        await app.longPress(find.text('Lisbona, Portogallo').first);
      },
    ),
    Scenario(
      6,
      'crea',
      'foglio-da-viaggi',
      route: '/trips',
      source: 'lib/shared/widgets/create_sheet.dart',
      description:
          'Crea dalla tab Viaggi: Nuovo viaggio sale sopra Nuova casa.',
      steps: (app) => _openCreateSheet(app, '/trips'),
    ),
  ]),

  Flow('08-nuovo-viaggio', 'Creazione viaggio (wizard 2 passi)', [
    Scenario(
      1,
      'nuovo-viaggio',
      'passo1-vuoto',
      route: '/new-trip',
      source: _addTrip,
      description:
          'Passo 1: nome, destinazione (default "Altra località"), date, tappe.',
      steps: (app) async {
        await app.go('/trips');
        await app.push('/new-trip');
      },
    ),
    Scenario(
      2,
      'nuovo-viaggio',
      'passo1-errore',
      route: '/new-trip',
      source: _addTrip,
      description: '"Avanti" senza dati: snackbar di validazione.',
      steps: (app) async {
        await app.go('/trips');
        await app.push('/new-trip');
        await app.tap(_text('common.next'), frames: 4);
      },
    ),
    Scenario(
      4,
      'nuovo-viaggio',
      'scelta-casa',
      route: '/new-trip',
      source: 'lib/shared/widgets/ds_picker_sheet.dart',
      description: 'Picker della casa di destinazione.',
      steps: (app) async {
        await app.go('/trips');
        await app.push('/new-trip');
        await app.tap(_text('common.destination_house'));
        await app.tap(_text('common.none_selected'));
      },
    ),
    Scenario(
      3,
      'nuovo-viaggio',
      'destinazione-casa',
      route: '/new-trip',
      source: 'lib/features/trips/view/trip_info_form.dart',
      description: 'Destinazione "Casa": selettore di una delle proprie case.',
      steps: (app) async {
        await app.go('/trips');
        await app.push('/new-trip');
        await app.tap(_text('common.destination_house'));
      },
    ),
    Scenario(
      5,
      'date-viaggio',
      'calendario',
      source: 'lib/features/trips/view/trip_date_range_screen.dart',
      description: 'Selezione date (pagina a schermo intero).',
      steps: (app) async {
        await app.go('/trips');
        await app.push('/new-trip');
        await app.tap(_text('common.tap_to_set_dates'));
      },
    ),
    Scenario(
      6,
      'tappa',
      'nuova',
      source: 'lib/features/trips/view/widgets/trip_leg_sheet.dart',
      description: 'Sheet "Aggiungi tappa".',
      steps: (app) async {
        await app.go('/trips');
        await app.push('/new-trip');
        await app.tester.ensureVisible(_text('trips.leg_add'));
        await app.tap(_text('trips.leg_add'));
      },
    ),
  ]),

  Flow('09-dettaglio-viaggio', 'Dettaglio viaggio: checklist e modifica', [
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
      description: 'Viaggio senza oggetti: CTA "Aggiungi vestiti".',
      steps: (app) => _tripDetail(app, kEmptyTripId),
    ),
    Scenario(
      4,
      'viaggio',
      'conferma-eliminazione',
      source: _tripDetailSrc,
      description: 'Dialog di eliminazione viaggio.',
      steps: (app) async {
        await _tripDetail(app);
        await app.tap(_icon(Icons.delete_outline));
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
        await app.tap(_icon(Icons.edit_outlined));
      },
    ),
    Scenario(
      6,
      'modifica-oggetti-viaggio',
      'default',
      route: '/trips/:id/edit-items',
      source: 'lib/features/trips/view/edit_trip_items_screen.dart',
      description: 'Selezione degli oggetti da portare.',
      steps: (app) async {
        await _tripDetail(app);
        await app.tap(_text('trips.edit_items'));
      },
    ),
    Scenario(
      7,
      'dettaglio-viaggio',
      'non-trovato',
      route: '/trips/:id',
      source: _tripDetailSrc,
      description: 'Id inesistente.',
      steps: (app) => _tripDetail(app, 'viaggio-che-non-esiste'),
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
