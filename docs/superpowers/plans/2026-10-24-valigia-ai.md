# Valigia con AI — piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** collegare l'Edge Function `pack-trip` all'app: foglio "Valigia con AI", pagina d'attesa, valigia generata nella pagina "Prepara la valigia", con dati salvati su Supabase.

**Architecture:** lato server, `pack-trip` impara le risposte per tappa (alloggio, lavatrice con la regola dei 5 giorni) e restituisce, accanto ai campi di oggi, una forma pensata per l'app (`capi` con tetto sulle quantità salvate, `avvisi`). Lato app, il viaggio guadagna due campi JSON sincronizzati (`aiSetup`: risposte del foglio; `aiResult`: proposta, avvisi, motivi), il foglio raccoglie le risposte tappa per tappa riusando il piano del meteo, la pagina d'attesa chiama la funzione e la pagina valigia, quando il viaggio ha `aiResult`, mostra solo i capi in valigia.

**Tech Stack:** Flutter 3.38.5 (Riverpod, freezed, go_router, easy_localization, Drift), Supabase (Postgres, Edge Functions TypeScript/Deno), test `flutter test` e `node --test`.

**Spec:** `docs/superpowers/specs/2026-10-24-valigia-ai-design.md` (stesso branch). Mockup: https://claude.ai/artifact/WoZJ5awxkzkFrRj4LeQQX5 (variante scelta: foglio "1", attesa "2", valigia "3" con gruppo "Dalla casa").

## Prerequisiti

- La PR #49 (bagagli dell'utente, Drift schema 11, `20261022190000_bagagli_senza_casa.sql`) è unita in `develop`. Il branch di lavoro `feat/valigia-ai` parte da `origin/develop` dopo quel merge. Questo piano porta Drift a **12**.
- Sul VPS: Flutter in `/srv/claude/workspaces/.tools/flutter-3.38.5/bin`; dopo `flutter pub get` serve `dart run build_runner build --delete-conflicting-outputs`. I test con Drift vogliono `libsqlite3.so`: `export LD_LIBRARY_PATH=<cartella con un link libsqlite3.so -> /usr/lib/x86_64-linux-gnu/libsqlite3.so.0>`. Deno per `deno check`: `/srv/claude/workspaces/.strumenti/node_modules/.bin/deno` con `DENO_DIR=/srv/claude/workspaces/.strumenti/deno-cache` (cancellare i `deno.lock` creati).

## Global Constraints

- Il generatore (`_shared/valigia/genera.ts`, `slots.ts`, `tappe.ts`, `dopo.ts`, `motivi.ts`, `quantita.ts`, `regole_capi.ts`, `costanti.ts`, ...) **non cambia**; gli oracoli in `_shared/valigia/test` restano verdi. Le novità stanno in `ingresso.ts` e in un modulo nuovo `uscita.ts`.
- Mai quantità inventate: −/+ solo se l'oggetto ha almeno 2 pezzi nell'armadio, massimo i pezzi salvati (`quantity` null = 1). Vale in pagina, nella scheda dell'oggetto, nel gruppo "Dalla casa" e per quello che arriva dal server.
- Mai copiare in silenzio le scelte di una tappa sulla successiva: una tappa nuova parte vuota; si copia solo con "Uguale a <tappa>".
- Un solo arancio per schermata: nel foglio è "Prepara la valigia"; nella pagina valigia è "Fatto". Pillole, interruttori, avvisi e righe mai arancio. Gli avvisi usano il colore `warning` del tema.
- Pillole del foglio: altezza 32 dp, testo `labelLarge` (14), niente spunta; scelta = bordo e testo `onSurface`, sfondo trasparente; non scelta = bordo `outlineVariant`, testo `onSurfaceVariant`; area toccabile 48 dp.
- La parola "capospalla" non compare mai nei testi per l'utente.
- Nei motivi solo il catalogo chiuso di `motivi.ts` (già restituito da `pack-trip`).
- Testi IT ed EN in `assets/translations/it-IT.json` e `en-US.json`, come il resto. I testi che arrivano dal server (motivi, avvisi) sono in italiano anche con l'app in inglese, come oggi.
- La regola dei 5 giorni è la costante `GIORNI_MAX_SENZA_LAVATRICE = 5`.
- Le 16 attività e i loro codici sono quelli della tabella della spec; "Immersioni e snorkeling" manda `immersioni` **e** `mare`.
- Supabase: le migrazioni nuove si applicano a DEV e PROD **prima** di distribuire il client che le usa (come la #49).
- Mai committare su `main`; PR verso `develop` aperta da Davide.

## Review Focus

- **Una tappa sola** (anche viaggio in corso ridotto a un luogo): il corpo deve usare `destinazione` + campi di viaggio, non `tappe` con un solo elemento, altrimenti il generatore prende la strada a tappe e la valigia cambia rispetto al bench. → test in Task 5.
- **Stesso capo in più punti della valigia** (due tappe, o ideale + ripiego, o capo anche essenziale): l'uscita somma per `item_id` prima del tetto, mai due righe per lo stesso oggetto. → test in Task 2.
- **Viaggio senza coordinate, troppo lungo (>60 g), con più di 8 tappe o già finito**: l'ingresso AI spiega perché non si può e non spende un credito. → test in Task 8.
- **Oggetto della proposta cancellato dalla casa** fra la generazione e la riapertura: la riga resta con la quantità salvata, senza stepper, e non fa cadere la pagina. → test in Task 10.
- **JSON salvato da una versione più nuova** (un'attività o un livello di avviso che questa versione non conosce): si scarta il valore sconosciuto, il resto del viaggio si legge. → test in Task 3.

---

### Task 1: `pack-trip` ingresso — alloggio e lavatrice per tappa

**Files:**
- Modify: `supabase/functions/_shared/valigia/ingresso.ts`
- Modify: `supabase/functions/pack-trip/index.ts` (solo il commento del contratto in testa)
- Test: `supabase/functions/_shared/valigia/test/ingresso.test.ts`

**Interfaces:**
- Produces:
  - `export const GIORNI_MAX_SENZA_LAVATRICE = 5;`
  - `export function lavatriceDaTappe(tappe: { giorni: number; lavatrice: boolean }[]): boolean` — vero solo se almeno una tappa ha la lavatrice e la serie di giorni consecutivi in tappe senza lavatrice non supera mai la costante (una tappa con lavatrice azzera la serie; la serie conta dall'inizio alla fine del viaggio).
  - `export function alloggioDaTappe(tappe: { nome: string; alloggio: string | null }[]): string | null` — nessun alloggio → null; tutti uguali (fra quelli dati) → quel valore; diversi → `"hotel (Islanda), appartamento (Olanda)"` nell'ordine delle tappe, saltando quelle senza.
  - `validaViaggio` accetta in ogni tappa `alloggio` (testo, max 80) e `lavatrice` (booleano). Se `v.lavatrice`/`v.alloggio` di viaggio sono presenti valgono loro (formato vecchio); altrimenti si ricavano dalle tappe con le due funzioni. Le tappe in uscita non portano `alloggio`/`lavatrice` (il resto della pipeline non cambia).

- [ ] **Step 1: test che falliscono** in `ingresso.test.ts`:

```ts
test("lavatrice: regola dei 5 giorni", () => {
  assert.equal(GIORNI_MAX_SENZA_LAVATRICE, 5);
  assert.equal(lavatriceDaTappe([{ giorni: 5, lavatrice: false }, { giorni: 4, lavatrice: true }]), true);
  assert.equal(lavatriceDaTappe([{ giorni: 7, lavatrice: false }, { giorni: 4, lavatrice: true }]), false);
  assert.equal(lavatriceDaTappe([{ giorni: 9, lavatrice: true }]), true);
  assert.equal(lavatriceDaTappe([{ giorni: 3, lavatrice: false }]), false);
  assert.equal(lavatriceDaTappe([{ giorni: 4, lavatrice: true }, { giorni: 6, lavatrice: false }]), false);
  assert.equal(lavatriceDaTappe([{ giorni: 3, lavatrice: false }, { giorni: 3, lavatrice: false }, { giorni: 2, lavatrice: true }]), false);
});

test("alloggio dalle tappe", () => {
  assert.equal(alloggioDaTappe([{ nome: "Islanda", alloggio: null }]), null);
  assert.equal(alloggioDaTappe([{ nome: "Islanda", alloggio: "hotel" }, { nome: "Olanda", alloggio: "hotel" }]), "hotel");
  assert.equal(alloggioDaTappe([{ nome: "Islanda", alloggio: "hotel" }, { nome: "Olanda", alloggio: "appartamento" }]),
    "hotel (Islanda), appartamento (Olanda)");
  assert.equal(alloggioDaTappe([{ nome: "Islanda", alloggio: null }, { nome: "Olanda", alloggio: "ostello" }]), "ostello");
});

test("tappe con alloggio e lavatrice", () => {
  const t = validaViaggio({ data_inizio: "2026-11-02", tappe: [
    { ...luogo, giorni: 5, alloggio: "hotel", lavatrice: false },
    { nome: "Porto", lat: 41.15, lon: -8.61, giorni: 4, alloggio: "appartamento", lavatrice: true }] }, OGGI);
  assert.equal(t.lavatrice, true);
  assert.equal(t.alloggio, "hotel (Lisbona), appartamento (Porto)");
  assert.equal("alloggio" in t.tappe![0], false);
  // il formato vecchio vince
  assert.equal(validaViaggio({ data_inizio: "2026-11-02", lavatrice: false, tappe: [{ ...luogo, giorni: 3, lavatrice: true }] }, OGGI).lavatrice, false);
  rifiuta({ data_inizio: "2026-11-02", tappe: [{ ...luogo, giorni: 3, lavatrice: "si" }] }, /lavatrice/);
});
```

- [ ] **Step 2:** `node --test supabase/functions/_shared/valigia/test/ingresso.test.ts` → FAIL (funzioni non esportate).
- [ ] **Step 3:** implementare in `ingresso.ts` le due funzioni e la lettura per tappa in `validaViaggio`. Aggiornare il commento del contratto in testa a `pack-trip/index.ts` (tappe con `alloggio`, `lavatrice`).
- [ ] **Step 4:** `node --test supabase/functions/_shared/valigia/test/` → tutti PASS (oracoli compresi).
- [ ] **Step 5:** commit `feat(pack-trip): alloggio e lavatrice per tappa, regola dei 5 giorni`.

### Task 2: `pack-trip` uscita — capi per l'app, tetto e avvisi

**Files:**
- Create: `supabase/functions/_shared/valigia/uscita.ts`
- Modify: `supabase/functions/pack-trip/index.ts`
- Test: `supabase/functions/_shared/valigia/test/uscita.test.ts`

**Interfaces:**
- Consumes: `Risultato` di `genera.ts` (`valigia.mancanti_canonici`, `motivi.capi`, `motivi.essenziali`).
- Produces:
  - `export const CODICE_POCHI = "pochi_pezzi";`
  - `export interface CapoApp { item_id: string; quantita: number; in_partenza: boolean; motivo: { codice: string; etichetta: string; frase: string } }`
  - `export interface AvvisoApp { id: string; codice: string; livello: "importante" | "utile"; titolo: string; perche: string; cerca: string | null }`
  - `export function uscitaApp(valigia: Record<string, any>, motivi: { capi: Record<string, any>[]; essenziali: Record<string, any>[] }, salvate: Map<string, number | null>): { capi: CapoApp[]; avvisi: AvvisoApp[] }`
  - Risposta di `pack-trip`: i campi di oggi **più** `capi` e `avvisi`.

Regole di `uscitaApp`:
- `capi`: da `motivi.capi` poi `motivi.essenziali`, uniti per `item_id` nell'ordine della prima comparsa: `quantita` sommata, `in_partenza` in OR, `motivo` del primo. Poi tetto: `min(somma, salvate.get(id) ?? 1)` (null = 1).
- Per ogni capo tagliato dal tetto, un avviso `{ codice: CODICE_POCHI, livello: motivo.codice === "essenziale" ? "importante" : "utile", titolo: "Pochi <nome> per questo viaggio", perche: "Ne servirebbero <somma>, nell'armadio ne hai <salvati>.", cerca: <nome> }`.
- Da `valigia.mancanti_canonici`: `livello` = `priorita === "necessario" ? "importante" : "utile"`, `titolo` = `slot` con l'iniziale maiuscola, `perche` = `reason`, `codice` = `tipo`, `cerca` = null.
- Ordine: prima gli "importante", poi gli "utile", stabile. `id` = `${codice}:${indice}` dopo l'ordinamento.

- [ ] **Step 1: test che falliscono** in `uscita.test.ts`, con valigia e motivi scritti a mano:

```ts
test("stesso capo in due punti: una riga, quantità sommata, tetto", () => {
  const motivi = { capi: [
      { item_id: "a", item: "Boxer neri", quantita: 3, in_partenza: false, motivo: { codice: "giorno", etichetta: "Tutti i giorni", frase: "x" } },
      { item_id: "a", item: "Boxer neri", quantita: 3, motivo: { codice: "giorno", etichetta: "Tutti i giorni", frase: "y" } },
      { item_id: "s", item: "Sneakers", quantita: 1, in_partenza: true, motivo: { codice: "giorno", etichetta: "Tutti i giorni", frase: "z" } }],
    essenziali: [{ item_id: "b", item: "Calzini", quantita: 6, motivo: { codice: "essenziale", etichetta: "Essenziali", frase: "w" } }] };
  const r = uscitaApp({ mancanti_canonici: [] }, motivi, new Map([["a", 4], ["s", null], ["b", 8]]));
  assert.deepEqual(r.capi.map((c) => [c.item_id, c.quantita, c.in_partenza]), [["a", 4, false], ["s", 1, true], ["b", 6, false]]);
  assert.equal(r.capi[0].motivo.frase, "x");
  assert.deepEqual(r.avvisi, [{ id: "pochi_pezzi:0", codice: "pochi_pezzi", livello: "utile",
    titolo: "Pochi Boxer neri per questo viaggio", perche: "Ne servirebbero 6, nell'armadio ne hai 4.", cerca: "Boxer neri" }]);
});

test("avvisi dai mancanti: importanti prima", () => {
  const r = uscitaApp({ mancanti_canonici: [
      { tipo: "assente", slot: "cappello da sole", reason: "UV alto", priorita: "consigliato" },
      { tipo: "assente", slot: "giacca impermeabile", reason: "pioggia 9 giorni su 12", priorita: "necessario" }] },
    { capi: [], essenziali: [] }, new Map());
  assert.deepEqual(r.avvisi.map((a) => [a.id, a.livello, a.titolo]),
    [["assente:0", "importante", "Giacca impermeabile"], ["assente:1", "utile", "Cappello da sole"]]);
});
```

- [ ] **Step 2:** `node --test supabase/functions/_shared/valigia/test/uscita.test.ts` → FAIL.
- [ ] **Step 3:** implementare `uscita.ts`. In `index.ts`: `.select("id, name, category, house_id, ai_metadata, quantity")`, mappa `salvate` da `righe`, risposta `json(200, { valigia, motivi, perche, geo, meteo, note_tecniche, ...uscitaApp(r.valigia, r.motivi, salvate) })`.
- [ ] **Step 4:** `node --test supabase/functions/_shared/valigia/test/` → PASS; `deno check supabase/functions/pack-trip/index.ts` pulito.
- [ ] **Step 5:** commit `feat(pack-trip): capi per l'app con tetto sulle quantità salvate e avvisi`.

### Task 3: modelli Dart della valigia AI

**Files:**
- Create: `lib/features/trips/model/ai_packing.dart` (+ generati freezed/json)
- Test: `test/features/trips/model/ai_packing_test.dart`

**Interfaces:**
- Produces:
  - `enum AiActivity { city, walks, trekking, cammino, highMountain, sea, diving, ski, camping, work, formalDinner, wedding, worship, nightlife, cycling, spa }` con `String get id` (stabile, salvato: `'city'`, `'walks'`, `'trekking'`, `'cammino'`, `'high_mountain'`, `'sea'`, `'diving'`, `'ski'`, `'camping'`, `'work'`, `'formal_dinner'`, `'wedding'`, `'worship'`, `'nightlife'`, `'cycling'`, `'spa'`), `List<String> get generatorCodes` (tabella della spec; `diving` → `['immersioni', 'mare']`), `String get labelKey` → `'trips.ai.activity.<id>'`. L'ordine dell'enum è l'ordine delle pillole.
  - `enum AiStay { hotel, apartment, hostel, camping, friends }` con `id` (`'hotel'`, ...), `generatorText` (`'hotel'`, `'appartamento'`, `'ostello'`, `'campeggio'`, `'da amici o parenti'`), `labelKey` → `'trips.ai.stay.<id>'`.
  - `@freezed AiStopAnswers({List<AiActivity> activities = const [], AiStay? stay, bool washer = false})` con `bool get isUntouched` (nessuna attività, nessun alloggio, lavatrice spenta) e `bool get isIncomplete` (nessuna attività **o** nessun alloggio).
  - `@freezed AiPackingSetup({String? houseId, String? luggageId, Map<String, AiStopAnswers> stops = const {}})` — chiave = `stopKey` (Task 5).
  - `@freezed AiReason({required String code, required String label, required String sentence})`
  - `@freezed AiPackedItem({required String itemId, required int quantity, bool inDeparture = false, required AiReason reason})`
  - `enum AiWarningLevel { important, useful }` (JSON `'importante'`, `'utile'`)
  - `@freezed AiWarning({required String id, required String code, required AiWarningLevel level, required String title, required String why, String? search})`
  - `@freezed AiReasonPoint({required String code, required String title, List<String> sentences = const [], List<String> items = const []})`
  - `@freezed AiPackingResult({required DateTime generatedAt, required String houseId, List<AiPackedItem> proposal = const [], List<AiWarning> warnings = const [], List<AiReasonPoint> reasons = const [], List<String> dismissedWarnings = const []})` con `List<AiWarning> get openWarnings` (senza i `dismissedWarnings`).
  - `fromJson`/`toJson` per tutti. Attività, alloggi e livelli sconosciuti: si scartano (attività), diventano null (alloggio) o si scarta l'avviso (livello); mai un'eccezione.

- [ ] **Step 1: test che falliscono**: andata e ritorno JSON di un `AiPackingSetup` con due tappe e di un `AiPackingResult`; `AiActivity.diving.generatorCodes == ['immersioni', 'mare']`; `AiActivity.values.length == 16`; un JSON con `activities: ['city', 'paracadute']` dà `[AiActivity.city]`; uno con un avviso `level: 'critico'` dà `warnings` senza quell'avviso; `AiStopAnswers().isUntouched` vero, `AiStopAnswers(washer: true).isUntouched` falso, `AiStopAnswers(activities: [AiActivity.sea]).isIncomplete` vero.
- [ ] **Step 2:** `flutter test test/features/trips/model/ai_packing_test.dart` → FAIL.
- [ ] **Step 3:** implementare (convertitori JSON per i valori sconosciuti), `build_runner`.
- [ ] **Step 4:** test → PASS.
- [ ] **Step 5:** commit `feat(trips): modelli della valigia AI`.

### Task 4: dati sul viaggio — Drift 12, Supabase, sync

**Files:**
- Modify: `lib/core/database/tables/trips_table.dart` (due colonne testo nullable `aiPackingSetup`, `aiPackingResult`)
- Modify: `lib/core/database/database.dart` (`schemaVersion` 12; `if (from < 12) { await m.addColumn(trips, trips.aiPackingSetup); await m.addColumn(trips, trips.aiPackingResult); }`)
- Modify: `lib/features/trips/model/trip_model.dart` (`AiPackingSetup? aiSetup`, `AiPackingResult? aiResult`)
- Modify: `lib/features/trips/repositories/drift_trip_repository.dart` (lettura/scrittura JSON, come `legs`)
- Modify: `lib/core/sync/sync_serializers.dart` (`ai_packing_setup`, `ai_packing_result` in `tripToJson` e nel companion del pull)
- Create: `supabase/migrations/20261025090000_valigia_ai.sql`
- Test: `test/core/database/trips_ai_packing_migration_test.dart`, `test/core/sync/sync_serializers_test.dart`, `test/features/trips/repositories/drift_trip_repository_test.dart`

**Interfaces:**
- Consumes: modelli del Task 3.
- Produces: `TripModel.aiSetup`, `TripModel.aiResult`, salvati con `tripNotifierProvider.notifier.updateTrip` e sincronizzati.

Migrazione Supabase (stessa semantica di `legs`: `null` = "nessuna informazione", il pull lascia il dato locale):

```sql
-- Valigia con AI (schema locale 12): risposte del foglio e valigia proposta.
-- Nullable e senza default, come legs: null vuol dire "riga senza dati", e il
-- pull non cancella quello che il telefono ha. Applicare prima di distribuire
-- il client con schema 12.
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS ai_packing_setup jsonb;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS ai_packing_result jsonb;
```

- [ ] **Step 1: test che falliscono**: (a) migrazione da 11 a 12 che conserva un viaggio con tappe, oggetti e bagagli, con le due colonne a null (sullo stile di `luggage_optional_house_migration_test.dart`); (b) `tripToJson` scrive `ai_packing_setup`/`ai_packing_result` come oggetti JSON (non stringhe) e null quando mancano; (c) il pull con `ai_packing_result: null` lascia `Value.absent()`, con un oggetto lo salva; (d) repository: salva e rilegge un viaggio con `aiSetup` e `aiResult` uguali.
- [ ] **Step 2:** `flutter test` dei tre file → FAIL.
- [ ] **Step 3:** implementare; `build_runner`; aggiungere la migrazione SQL.
- [ ] **Step 4:** `flutter test test/core test/features/trips` → PASS.
- [ ] **Step 5:** commit `feat(trips): risposte e valigia AI sul viaggio (Drift 12, Supabase)`.

### Task 5: tappe con chiave e corpo della richiesta

**Files:**
- Modify: `lib/features/trips/model/trip_weather.dart` (`WeatherStopRequest.stopKey`, `kMainStopKey`)
- Create: `lib/features/trips/model/pack_trip_request.dart`
- Test: `test/features/trips/model/pack_trip_request_test.dart`, `test/features/trips/model/trip_weather_test.dart` (esistente)

**Interfaces:**
- Consumes: `planTripWeather`, `AiPackingSetup`, `LuggageModel`.
- Produces:
  - `const kMainStopKey = 'main';` e `final String stopKey` in `WeatherStopRequest` (`kMainStopKey` per la meta, `leg.id` per le tappe). **Non** entra in `toJson` né nella `signature` (la cache del meteo non cambia).
  - `class AiStop { final String key; final String name; final int days; }` e `List<AiStop> aiStopsOf(TripWeatherRequest plan)` — una voce per chiave, nell'ordine della prima comparsa, `days` sommati (un luogo spezzato in due periodi è una tappa sola del foglio).
  - `String? luggageDescription(LuggageModel? luggage)`: `smallBackpack` → `"zaino da <effectiveVolumeLiters> litri"`; `cabinBaggage` → `"trolley cabina"`; `holdBaggage` → `"valigia grande"`; `custom` → `"<nome> da <litri> litri"` o `"<nome>"` senza litri; tagliato a 80 caratteri; null senza bagaglio.
  - `Map<String, dynamic> packTripBody({required TripWeatherRequest plan, required AiPackingSetup setup, required String houseId, LuggageModel? luggage})`:
    - una sola chiave nel piano → `{'house_id', 'trip': {'data_inizio', 'giorni', 'destinazione': {nome, paese?, lat, lon}, 'attivita', 'alloggio'?, 'lavatrice', 'bagaglio'?}}`;
    - più chiavi → `{'house_id', 'trip': {'data_inizio', 'tappe': [{nome, paese?, lat, lon, giorni, attivita, alloggio?, lavatrice}], 'bagaglio'?}}` (una voce per ogni periodo del piano, con le risposte della sua chiave);
    - `attivita` = codici del generatore delle pillole scelte, senza doppioni, nell'ordine delle pillole.

- [ ] **Step 1: test che falliscono**:

```dart
test('una tappa sola: destinazione e campi di viaggio, mai tappe', () {
  final body = packTripBody(plan: onePlacePlan, setup: AiPackingSetup(stops: {
    kMainStopKey: AiStopAnswers(activities: [AiActivity.diving, AiActivity.sea], stay: AiStay.hotel, washer: true)}),
    houseId: 'h1', luggage: cabin);
  final trip = body['trip'] as Map<String, dynamic>;
  expect(trip.containsKey('tappe'), isFalse);
  expect(trip['attivita'], ['immersioni', 'mare']);
  expect(trip['alloggio'], 'hotel');
  expect(trip['lavatrice'], true);
  expect(trip['bagaglio'], 'trolley cabina');
});
test('due tappe: risposte per tappa', () { /* tappe[1]['attivita'] == ['visite in citta'], tappe[1]['alloggio'] == 'appartamento', tappe[0]['lavatrice'] == false */ });
test('stesso luogo in due periodi: una tappa del foglio', () { expect(aiStopsOf(abaPlan).map((s) => s.key), ['main', 'leg1']); });
test('luggageDescription', () { expect(luggageDescription(backpack20), 'zaino da 20 litri'); expect(luggageDescription(customNoLiters), 'Borsa rossa'); });
test('stopKey non cambia la firma del meteo', () { /* signature uguale a quella di prima del cambio, con un valore scritto nel test */ });
```

- [ ] **Step 2:** `flutter test test/features/trips/model/` → FAIL.
- [ ] **Step 3:** implementare.
- [ ] **Step 4:** test → PASS.
- [ ] **Step 5:** commit `feat(trips): corpo della richiesta per pack-trip`.

### Task 6: servizio `pack-trip`

**Files:**
- Create: `lib/features/trips/services/pack_trip_service.dart`
- Test: `test/features/trips/services/pack_trip_service_test.dart`

**Interfaces:**
- Consumes: `AiPackingResult`, `AppConfig`, sessione Supabase (stesso schema di `TripWeatherService`).
- Produces:
  - Eccezioni: `PackTripCreditsException` (429), `PackTripEmptyWardrobeException` (422 con `"Wardrobe is empty"`), `PackTripWardrobeTooLargeException` (422 con `"Wardrobe too large"`), `PackTripException(String message)` (tutto il resto: rete, 400, 5xx, risposta illeggibile).
  - `class PackTripService { PackTripService({http.Client Function()? client, String? Function()? token}); Future<AiPackingResult> generate(Map<String, dynamic> body, {required String houseId}); void cancel(); }` — `cancel` chiude il client in corso; la `generate` annullata solleva `PackTripException('annullata')`.
  - `AiPackingResult parsePackTripResponse(Map<String, dynamic> json, {required String houseId, required DateTime now})`: `capi` → `proposal` (`motivo.codice/etichetta/frase` → `AiReason`), `avvisi` → `warnings`, `perche` (`codice`, `titolo`, `frasi`, `capi`) → `reasons`.
  - `@riverpod PackTripService packTripService(Ref ref)` (non keepAlive).

- [ ] **Step 1: test che falliscono** con un `MockClient` di `package:http/testing.dart`: 200 con un corpo di esempio (due capi, un avviso, un punto) → proposta, avvisi, motivi giusti; 429 → `PackTripCreditsException`; 422 empty / too large → le due eccezioni; 502 → `PackTripException`; corpo non JSON → `PackTripException`. Il test passa `token: () => 'jwt'` (default: il JWT della sessione Supabase).
- [ ] **Step 2:** `flutter test test/features/trips/services/pack_trip_service_test.dart` → FAIL.
- [ ] **Step 3:** implementare.
- [ ] **Step 4:** → PASS.
- [ ] **Step 5:** commit `feat(trips): servizio pack-trip`.

### Task 7: pillole senza spunta

**Files:**
- Create: `lib/features/trips/view/widgets/ai/ai_choice_pill.dart`
- Modify: `lib/features/trips/view/widgets/pack/pack_parts.dart` (`PackPill`: niente `Icons.check`, l'icona resta la sua; scelta = sfondo trasparente, bordo e testo `onSurface`)
- Test: `test/features/trips/view/widgets/ai_choice_pill_test.dart`, test esistenti di `pack_suitcase_screen_test.dart` aggiornati

**Interfaces:**
- Produces: `AiChoicePill({Key? key, required String label, required bool selected, required VoidCallback onTap})`.

- [ ] **Step 1: test che falliscono**: altezza renderizzata 32; area toccabile ≥ 48 (`tester.getSize` del `Semantics`/`InkWell` padded); nessun `Icons.check`; con `selected` il bordo e il testo sono `colorScheme.onSurface` e lo sfondo trasparente; senza, bordo `outlineVariant` e testo `onSurfaceVariant`; `PackPill(selected: true)` non mostra `Icons.check`.
- [ ] **Step 2:** → FAIL. **Step 3:** implementare. **Step 4:** `flutter test test/features/trips` → PASS.
- [ ] **Step 5:** commit `feat(ui): pillole compatte senza spunta`.

### Task 8: il foglio "Valigia con AI"

**Files:**
- Create: `lib/features/trips/view/widgets/ai/ai_packing_sheet.dart`
- Create: `lib/features/trips/view/widgets/ai/ai_stop_form.dart` (meteo della tappa, attività, alloggio, lavatrice)
- Create: `lib/features/trips/model/ai_availability.dart`
- Modify: traduzioni IT/EN (`trips.ai.*`)
- Test: `test/features/trips/view/ai_packing_sheet_test.dart`, `test/features/trips/model/ai_availability_test.dart`

**Interfaces:**
- Consumes: `AiChoicePill`, `AiStop`/`aiStopsOf`, `tripWeatherNotifierProvider(tripId)` (`TripWeatherReady.weather.stops`, nello stesso ordine del piano), `houseNotifierProvider`, `luggageNotifierProvider`, `showAddEditLuggageSheet`, `showDsFormSheet`/`DsFormSheet`.
- Produces:
  - `sealed class AiAvailability` = `AiAvailable(TripWeatherRequest plan)` | `AiUnavailable(WeatherUnavailable reason)`; `AiAvailability aiAvailabilityOf(TripModel trip, {required List<HouseModel> houses, required DateTime today})` (da `planTripWeather`). `AiUnavailable` ha `String get messageKey` (`trips.ai.unavailable.<reason>`).
  - `HouseModel? proposedPackingHouse(List<HouseModel> houses, TripModel trip)` spostata qui dalla pagina valigia (stessa logica di `_proposedHouse`).
  - `Future<AiPackingSetup?> showAiPackingSheet(BuildContext context, {required TripModel trip, required TripWeatherRequest plan})` — riparte da `trip.aiSetup` se c'è; restituisce le risposte con "Prepara la valigia", null se chiuso.

Comportamento (dalla spec e dal mockup "1"):
- In cima "Da quale casa prendi i vestiti" (pillole delle case, preselezionata `aiSetup.houseId` o `proposedPackingHouse`) e "Con che bagaglio parti" (pillole dei bagagli, una scelta, preselezionata `aiSetup.luggageId` o il primo bagaglio del viaggio; senza bagagli il link "Nuovo bagaglio").
- Con 2+ tappe del foglio: "Tappa i di n · <nome>", barra a segmenti, scheda meteo della tappa (se il meteo è pronto; altrimenti niente scheda), poi `AiStopForm`. "Avanti: <prossima>" e "Indietro". Dalla seconda tappa, se la tappa è `isUntouched`, il bottone tratteggiato "Uguale a <precedente>" copia le tre risposte.
- Con una tappa: niente stepper e niente meteo.
- "Prepara la valigia" (primario, icona `Icons.auto_awesome`) nell'ultima tappa. Primo tocco con una tappa `isIncomplete` (solo con 2+ tappe): avviso sopra il bottone "<Tappa> è ancora da compilare…" con "Uguale a <tappa compilata>" e "La compilo io" (va a quella tappa). Secondo tocco: chiude restituendo le risposte.
- Senza case: messaggio e niente bottone (non si spende un credito).

- [ ] **Step 1: test che falliscono**: `aiAvailabilityOf` per un viaggio senza coordinate → `AiUnavailable(missingPlace)`, finito → `past`, 61 giorni → `tooLong`, 9 tappe → `tooManyStops`; widget: con una tappa non c'è "Tappa 1 di"; con due la seconda parte vuota anche se la prima è compilata; "Uguale a Islanda" copia e scompare; primo tocco su "Prepara la valigia" con tappa vuota mostra l'avviso e non chiude, il secondo chiude con le risposte; nessun widget del foglio usa `colorScheme.primary` tranne il bottone finale (cercare i `Text`/`BoxDecoration` con quel colore); "Immersioni e snorkeling" scelta → `AiActivity.diving` nelle risposte.
- [ ] **Step 2:** → FAIL. **Step 3:** implementare (con le traduzioni). **Step 4:** → PASS.
- [ ] **Step 5:** commit `feat(trips): foglio Valigia con AI`.

### Task 9: pagina d'attesa ed errori

**Files:**
- Create: `lib/features/trips/view/ai_packing_wait_screen.dart`
- Modify: `lib/core/routing/app_router.dart` (route `/trips/:id/ai-packing`, `extra` = `PackTripJob`)
- Modify: `lib/shared/helpers/snack_bar_helper.dart` (`static void showUndo(BuildContext context, String message, {required VoidCallback onUndo})`, con `SnackBarAction` `common.undo`; serve dal Task 10)
- Modify: traduzioni (`trips.ai.wait.*`, `trips.ai.error.*`)
- Test: `test/features/trips/view/ai_packing_wait_screen_test.dart`

**Interfaces:**
- Consumes: `PackTripService`, `gptUsageProvider`.
- Produces: `class PackTripJob { final Map<String, dynamic> body; final String houseId; final String title; final int nights; }`; `AiPackingWaitScreen({required String tripId, required PackTripJob job})`, che fa `context.pop<AiPackingResult>(result)` alla risposta e `context.pop()` (null) con "Annulla".

Comportamento: icona AI, "Preparo la valigia", "<title> · N notti", tre passi a tempo (0 s, 3 s, 6 s; scelta di Claude), "Di solito ci vogliono una decina di secondi", "Annulla" (chiama `cancel`). Dopo una risposta (anche errore) si invalida `gptUsageProvider`. Errori, a pagina intera con un'uscita:
- `PackTripCreditsException` → testo sui crediti finiti, bottone "Vai al Profilo" (`/profile`).
- `PackTripEmptyWardrobeException` → "Questa casa non ha vestiti", bottone che porta a `/houses/<houseId>`.
- `PackTripWardrobeTooLargeException` → testo con il massimo di 400 capi, "Chiudi".
- `PackTripException` → "Riprova" (stessa richiesta) e "Chiudi".

- [ ] **Step 1: test che falliscono** con un `PackTripService` finto via override del provider: successo → la route restituisce il risultato; ogni eccezione → il suo testo e i suoi bottoni; "Riprova" richiama `generate` una seconda volta; "Annulla" chiama `cancel` e restituisce null.
- [ ] **Step 2:** → FAIL. **Step 3:** implementare. **Step 4:** → PASS.
- [ ] **Step 5:** commit `feat(trips): pagina d'attesa della valigia AI`.

### Task 10: pagina valigia — modalità "solo in valigia"

**Files:**
- Modify: `lib/features/trips/view/pack_suitcase_screen.dart`
- Modify: `lib/features/trips/view/widgets/pack/pack_parts.dart` (`PackItemRow`)
- Create: `lib/features/trips/view/widgets/ai/ai_pack_item_sheet.dart`
- Create: `lib/features/trips/view/widgets/ai/ai_home_group.dart`
- Modify: traduzioni (`trips.pack.ai.*`)
- Test: `test/features/trips/view/pack_suitcase_ai_mode_test.dart`

**Interfaces:**
- Consumes: `TripModel.aiResult`, `AppSnackBar.showUndo`, `itemNotifierProvider(houseId)`.
- Produces:
  - `PackItemRow` con quattro parametri nuovi: `bool packedOnly = false`, `bool inDeparture = false`, `VoidCallback? onRemove`, `VoidCallback? onOpen`. In `packedOnly`: niente casella, × a destra (`Key('pack_remove_<id>')`) che chiama `onRemove`, tocco sul nome chiama `onOpen`, sotto il nome "Da indossare in partenza" se `inDeparture`; stepper con le stesse regole (solo con `available > 1`, massimo `available`) ma `minValue: 0`, e lo 0 chiama `onRemove`. `item` può essere null in questa modalità (oggetto cancellato dalla casa): si mostra il nome del `TripItem`, niente stepper.
  - `Future<void> showAiPackItemSheet(BuildContext context, {required TripItem item, required int available, AiReason? reason, bool inDeparture = false, required ValueChanged<int> onQuantity, required VoidCallback onRemove})`: "Perché è in valigia" (etichetta e frase), "Da indossare in partenza", quantità con "Ne hai N nell'armadio" (stepper solo con N ≥ 2), "Togli dalla valigia".
  - `AiHomeGroup({required List<ItemModel> items, required ValueChanged<ItemModel> onAdd})`: riquadro chiuso "Dalla casa · N oggetti", sottotitolo "Toiletries, elettronica e varie: li scegli tu", aperto elenca gli oggetti con "+ Aggiungi"; senza oggetti non si disegna.

Comportamento quando `_aiResult != null` (stato della pagina, idratato da `trip.aiResult`):
- Niente selettore "Da <casa>": la casa è `aiResult.houseId`.
- "Cosa porti" mostra solo `_items`, raggruppati per categoria come oggi, con `PackItemRow(packedOnly: true)`; `inDeparture` e `reason` dalla voce della proposta con lo stesso `itemId`.
- Sotto il titolo la nota grigia con l'icona "i": "Ho scelto i vestiti e l'essenziale per l'igiene. Il resto lo scegli tu: lo trovi in fondo alla valigia."
- La ricerca diventa "Aggiungi dal tuo armadio": cerca fra gli oggetti della casa non in `_items`; il tocco su un risultato lo aggiunge con quantità 1 (snackbar con Annulla); in fondo la riga "Nuovo oggetto" di oggi (`PackAddRow`).
- In fondo `AiHomeGroup` con gli oggetti della casa di categoria diversa da `vestiti` e non in `_items`; "+ Aggiungi" → quantità 1, snackbar con Annulla.
- Togliere (× o − a 0) → snackbar "Tolto: <nome>" con Annulla, che rimette voce e quantità.
- La valigia manuale (senza `aiResult`) resta com'è.

- [ ] **Step 1: test che falliscono** con un viaggio con `aiResult` e una casa finta: si vedono solo gli oggetti in valigia; nessun `Checkbox`; boxer (salvati 4, in valigia 4) → stepper con + spento; calzino unico → niente stepper; × toglie e Annulla rimette con la stessa quantità; "Dalla casa · 3 oggetti" chiuso, aperto mostra solo non-vestiti, "+ Aggiungi" sposta l'oggetto nella lista e il conteggio scende a 2; un `TripItem` il cui oggetto non c'è più nella casa si vede, senza stepper, e la pagina non lancia eccezioni; il selettore "Da" non c'è; un viaggio senza `aiResult` mostra ancora caselle e selettore.
- [ ] **Step 2:** → FAIL. **Step 3:** implementare. **Step 4:** `flutter test test/features/trips` → PASS.
- [ ] **Step 5:** commit `feat(trips): valigia generata con solo i capi in valigia`.

### Task 11: avvisi, motivi, Rigenera e salvataggio

**Files:**
- Modify: `lib/features/trips/view/pack_suitcase_screen.dart`
- Create: `lib/features/trips/view/widgets/ai/ai_pack_rows.dart` (le due righe e i due fogli)
- Modify: traduzioni
- Test: `test/features/trips/view/pack_suitcase_ai_flow_test.dart`

**Interfaces:**
- Consumes: `showAiPackingSheet`, `aiAvailabilityOf`, `packTripBody`, `aiStopsOf`, `PackTripJob`, route `/trips/:id/ai-packing`.
- Produces:
  - `AiPackRows({required List<AiWarning> warnings, required List<AiReasonPoint> reasons, required ValueChanged<String> onSearch, required ValueChanged<String> onDismiss})`: riga "Cosa manca a questo viaggio" (icona e numero in `warning`; senza avvisi "Non manca niente", grigia) che apre il foglio degli avvisi (livello Importante/Utile, titolo, perché; "Cerca nell'armadio" solo con `search` non null: chiude e scrive la ricerca; "Ok, capito" chiama `onDismiss(id)`); riga neutra "Perché queste scelte" che apre il foglio dei motivi (un punto per motivo, nell'ordine ricevuto).
  - `PackSuitcaseScreen({..., bool startAi = false})`; route `/trips/:id/edit-items?from=new&ai=1` → `startAi: true`.

Comportamento:
- Le righe stanno sotto `PackSummaryLine`, solo con `_aiResult`. "Ok, capito" aggiunge l'id a `dismissedWarnings` nello stato della pagina (si salva con "Fatto"; `_isDirty` ne tiene conto).
- L'icona AI della barra (`Key('pack_ai_suitcase')`) diventa attiva, tooltip "Prepara con AI"/"Rigenera". Con `AiUnavailable` resta grigia e il tocco mostra il motivo. Tocco: se `_items` non è vuota chiede "Vuoi sostituire la valigia?" (conferma distruttiva); poi `showAiPackingSheet`; con le risposte: salva subito `aiSetup` sul viaggio (solo quel campo, sul viaggio letto ora dal provider), poi `context.push<AiPackingResult>('/trips/<id>/ai-packing', extra: PackTripJob(...))`.
- Con un risultato: costruisce `_items` dalla proposta (nome e categoria dall'oggetto della casa; oggetti non più in casa saltati), `_luggages` = il bagaglio scelto se c'è, `_aiResult` = risultato, e **salva subito** viaggio con oggetti, bagagli, `aiSetup` e `aiResult` (scelta di Claude: la generazione costa un credito e non deve perdersi con un "Esci senza salvare"); poi la pagina riparte da quello stato (`_initial*` aggiornati).
- `startAi`: dopo il primo frame apre il foglio come il tocco sull'icona (senza la domanda, la valigia è vuota).
- "Fatto" salva anche `aiResult` (con i `dismissedWarnings`). Il registro "cosa ha proposto l'AI / cosa ha tenuto l'utente" è `aiResult.proposal` contro `trip.items`, entrambi su Supabase (scelta di Claude: nessuna tabella in più).

- [ ] **Step 1: test che falliscono** con servizio e router finti: tocco sull'icona con valigia piena → domanda; "Annulla" della domanda non apre il foglio; risposta del foglio + risultato → la pagina mostra la proposta e `updateTrip` è stato chiamato con `aiResult` e `aiSetup`; "Ok, capito" toglie l'avviso e, dopo "Fatto", il viaggio salvato ha l'id in `dismissedWarnings`; "Cerca nell'armadio" scrive `search` nella ricerca; con `startAi` il foglio si apre da solo; viaggio senza coordinate → icona grigia e snackbar col motivo, nessuna chiamata al servizio.
- [ ] **Step 2:** → FAIL. **Step 3:** implementare. **Step 4:** `flutter test test/features/trips` → PASS.
- [ ] **Step 5:** commit `feat(trips): avvisi, motivi e Rigenera nella valigia AI`.

### Task 12: ingressi — passo 1 e foglio Crea

**Files:**
- Modify: `lib/features/trips/view/new_trip_screen.dart` (`NewTripScreen({..., bool aiIntent = false})`, `_buildBottomBar`, `_save`)
- Modify: `lib/core/routing/app_router.dart` (`/new-trip?ai=1` → `aiIntent: true`)
- Modify: `lib/shared/widgets/create_sheet.dart` (`CreateAction.aiSuitcase`, riga accesa, niente "In arrivo")
- Modify: `lib/shared/widgets/main_shell.dart` (`case CreateAction.aiSuitcase:` → analytics `ai_suitcase`, `context.push('/new-trip?ai=1')`)
- Modify: traduzioni (togliere `trips.pack.ai_coming_soon`; aggiungere `trips.new.prepare_with_ai`, `trips.new.pack_myself`)
- Test: `test/features/trips/view/new_trip_screen_test.dart`, `test/shared/widgets/create_sheet_test.dart`

**Interfaces:**
- Consumes: route `/trips/:id/edit-items?from=new&ai=1` (Task 11).
- Produces: `_save({required bool goToPacking, bool withAi = false})` → con `withAi` apre `/trips/<id>/edit-items?from=new&ai=1`.

Barra in fondo del passo 1 (scelta di Claude, per l'unico arancio):
- normale: "Avanti" (primario, arancio), sotto "Prepara con AI" (`DsButton` `secondary`, icona `Icons.auto_awesome`), poi il link "Più tardi";
- con `aiIntent`: "Prepara con AI" primario, sotto il link "Preparo io la valigia" (→ passo 2 manuale), poi "Più tardi".
In modifica di un viaggio (`tripId` non null) niente di nuovo.

- [ ] **Step 1: test che falliscono**: il bottone AI c'è nel passo 1 e salva poi apre la route con `ai=1`; con `aiIntent` il primario è "Prepara con AI"; in modifica non c'è; il foglio Crea mostra "Valigia con AI" attiva e restituisce `CreateAction.aiSuitcase`; nessun testo "In arrivo" nella riga.
- [ ] **Step 2:** → FAIL. **Step 3:** implementare. **Step 4:** `flutter test` (tutta la suite) → PASS; `flutter analyze` pulito.
- [ ] **Step 5:** commit `feat(trips): ingressi della valigia AI`.

### Task 13: screenshot, documenti, consegna

**Files:**
- Modify: `test/screenshots/ui_screenshots_test.dart`, `test/screenshots/support/seed.dart` (flusso "valigia-ai": foglio a una e due tappe, avviso finale, attesa, valigia generata con avvisi, gruppo "Dalla casa" aperto, scheda oggetto)
- Modify: `docs/ui-flows.md` (sezione valigia AI; aggiornare le parti superate da #42–#49)

- [ ] **Step 1:** aggiungere il flusso e generare: `flutter test test/screenshots --dart-define=UI_SCREENSHOTS=true --dart-define=UI_SCREENSHOTS_THEMES=dark --plain-name "valigia-ai"` → immagini prodotte senza errori.
- [ ] **Step 2:** confronto a occhio con il mockup (pillole, un solo arancio, testi); correggere.
- [ ] **Step 3:** `flutter analyze`, `flutter test`, `node --test supabase/functions/_shared/valigia/test/`, `deno check supabase/functions/pack-trip/index.ts` → tutto verde.
- [ ] **Step 4:** commit `docs: flussi e screenshot della valigia AI`; push del branch; testo della PR per Davide con il promemoria: applicare `20261025090000_valigia_ai.sql` (e, se non già fatto, `20261020090000_generatore_valigie.sql`, `20261021120000_crediti_ai.sql`) a DEV e PROD prima di distribuire; segreti `ANTHROPIC_API_KEY`, `TYPESAFE_API_KEY`, `OPEN_METEO_API_KEY`; ridistribuire `pack-trip`.
