# Percorso fino alla prima valigia — piano di lavoro

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** dall'installazione alla prima valigia generata con il minor numero di passi, anche con l'armadio vuoto, con una valigia fatta di **posti** (importante/utile; tuo/proposto/mancante; "da comprare") invece che di avvisi.

**Architecture:** lato funzione, un nuovo strato d'uscita `posti.ts` accanto a `uscita.ts`: legge il risultato del generatore senza toccare la scelta dei capi (888 identici) e produce `posti` e `informazioni` nella risposta di `pack-trip`, che ora accetta l'armadio vuoto. Lato app, i posti viaggiano dentro `ai_packing_result` (JSON già sincronizzato su Supabase, nessuna migrazione), si mostrano nel dettaglio del viaggio e si riempiono con il Rapid Fire, che impara le copie col numero. Il primo avvio passa da "Dove vai?" invece che dal tour delle foto.

**Tech Stack:** TypeScript (Deno Edge Functions, test con `node --test`), Flutter 3.38.5 + Riverpod + freezed + easy_localization, Amplitude.

**Spec:** `docs/superpowers/specs/2026-11-01-percorso-prima-valigia-design.md` (approvato da Davide il 1 novembre 2026). Mockup: https://claude.ai/artifact/UZm7aHL5nhL8T6YfPrssBN

## Global Constraints

- Worktree `/srv/claude/workspaces/PackLog-prima-valigia`, branch `feat/prima-valigia` (Task 0). Bench: `/srv/claude/workspaces/AI-checklist-test-script`, solo lettura (si esporta l'oracolo, non si cambia il codice del bench).
- Regole d'ambiente degli agenti: `/tmp/claude-1001/-srv-claude-workspaces-PackLog/a389a2f8-d273-43c6-b669-b6e7c79291e2/scratchpad/ds-piani/ambiente.md` (Flutter con `source /srv/claude/workspaces/.strumenti/flutter338.sh`, niente push, niente subagenti), con la cartella di lavoro di questo piano al posto di `PackLog-giri-dev`.
- La scelta dei capi non cambia: `confronta_celle.ts` e `confronta_motivi.ts` restano 888/888, e `uscitaApp` (avvisi) resta identica byte per byte: le app vecchie la leggono ancora.
- Gli oggetti proposti **non entrano mai nell'inventario** (`items`): vivono solo dentro `ai_packing_result` del viaggio.
- **Livello (Davide, 1 novembre):** è importante solo ciò che dipende da questo viaggio (freddo, pioggia, attività, occasioni). Magliette, pantaloni, intimo, calzini, pigiama e igiene sono sempre utili.
- **Barra (Davide, 1 novembre):** finché c'è un importante aperto, "N di M pronti" con la legenda; poi le spunte "N di M in valigia". Un proposto si spunta; un importante "da comprare" resta da sistemare.
- Testi nuovi in `assets/translations/it-IT.json` e `en-US.json`, con le parole esatte del piano; niente testo libero dal generatore.
- Colori del gradiente PackLog: arancio `#FF8A50`, ambra `#FBBF24`, rosa `#F472B6`; niente blu né viola; niente bottoni arancioni pieni nelle card dei posti.
- Movimento solo quando appare la stima del meteo e durante la generazione; con `MediaQuery.disableAnimations` tutto fermo.
- La revisione "Dogana delle Serate" non è ancora chiusa: i livelli "via" entreranno quando diventa asserzioni del bench, fuori da questo piano. Qui nessun posto nasce da un avviso che oggi non esiste.
- Nessun deploy, nessuna migrazione, nessun push: li fa Davide dopo il merge.
- Commit in italiano, con le due righe finali di `ambiente.md`.

## Review Focus

1. **Valigia generata da un'app vecchia (risultato senza `posti`)**: il dettaglio e "Modifica valigia" si comportano come oggi (avvisi visibili, barra delle spunte). → test in Task 4 e Task 7.
2. **Posto riempito con più copie di quelle rimaste** ("5 t-shirt" su "Magliette ×3"): il posto va a zero e sparisce, mai negativo; l'oggetto entra con 5. → test in Task 8.
3. **Viaggio senza posti e senza oggetti** (generazione con armadio vuoto andata male, o viaggio manuale): niente barra divisa per zero, resta lo stato vuoto di oggi. → test in Task 7.
4. **"2 in 1 caricatore"**: la pillola ×2 compare, toccarla la toglie e l'oggetto nasce col nome intero e 1 copia. → test in Task 5.
5. **Rigenerare dopo aver segnato "da comprare"**: la segnatura passa al posto dello stesso tipo, e un posto che non c'è più non lascia tracce nella vista "Da comprare". → test in Task 4 e Task 10.

---

### Task 0: Base del ramo

Il lavoro dipende da `feat/catalogo-tag` (in cima alla pila testi-inglese → quantita-copie → attivita-generatore → catalogo-tag) e da `fix/rifiniture-leo` (superfici, "Perché queste scelte" nascosto se vuoto, formatter della maiuscola). Unirli adesso evita di rifare il lavoro dopo.

- [ ] **Step 1:** `git -C /srv/claude/workspaces/PackLog-giri-dev worktree add /srv/claude/workspaces/PackLog-prima-valigia -b feat/prima-valigia feat/catalogo-tag`
- [ ] **Step 2:** nel nuovo worktree `git merge --no-ff fix/rifiniture-leo`. Conflitti attesi solo in `test/features/houses/view/house_detail_screen_test.dart` e `test/screenshots/ui_screenshots_test.dart`: si tengono i test di entrambi i lati.
- [ ] **Step 3:** `dart run build_runner build -d`, poi `flutter analyze` (pulito) e `flutter test` (tutto verde; atteso circa 1885 + i test di rifiniture). `node --test supabase/functions/_shared` come prima (104/105, `claude.test.ts` noto).
- [ ] **Step 4:** commit del merge (messaggio: `merge: rifiniture di Leo sotto il percorso della prima valigia`).

---

### Task 1: Posti dai mancanti — nomi e livello

**Files:**
- Create: `supabase/functions/_shared/valigia/posti_nomi.ts`
- Create: `supabase/functions/_shared/valigia/posti.ts`
- Modify: `supabase/functions/_shared/valigia/uscita.ts` (solo `export` di funzioni che già esistono)
- Test: `supabase/functions/_shared/valigia/test/posti.test.ts`

**Interfaces:**
- Consumes: da `uscita.ts`, da esportare senza cambiarle: `capoDelGap`, `meteoDelGap`, `soloElegante`, `freddoPer`, `attivitaPer`, `perQuestoArmadio`, `copyMancante` (già esportata).
- Produces:
  - `export type Livello = "importante" | "utile"`
  - `export function livelloPosto(g: Record<string, any>, capo: { sub: string | null; categoria: string }, viaggioFreddo: boolean): Livello`
  - `export function nomePosto(capo: { sub: string | null; categoria: string }, copie: number, qualifica: "freddo" | "acqua" | "elegante" | null, lingua: Lingua): { nome: string; aggiungi: string }`
  - `export function qualificaDelGap(g, capo, viaggioFreddo): "freddo" | "acqua" | "elegante" | null`: freddo se `meteoDelGap(...).freddo`, altrimenti acqua se `.acqua`, altrimenti elegante se `soloElegante(g)`.

**Regola del livello** (`livelloPosto`). Importante se e solo se vale una di queste:
- la sottocategoria è d'attività: `DA_ATTIVITA = {Hiking Boots, Water Shoes, Swimwear, Wetsuit, Ski Jacket, Ski Pants, Ski Suit, Snow Boots}`;
- `soloElegante(g)` (l'abito del matrimonio, le scarpe eleganti delle riunioni);
- la categoria è `Outerwear`, `Shoes` o `Accessory` e `meteoDelGap` dà freddo o acqua.

Tutto il resto è utile, compresi `Upper Body` e `Lower Body` col freddo: maglioni e strato termico sono proposti, come nel mockup.

**Nomi** (`posti_nomi.ts`): una tabella per ogni sottocategoria di `NOME_SOTTOCATEGORIA` e per ogni categoria di `NOME_CATEGORIA` (la generica di `capoDelGap`), con `it: [singolare, plurale]`, `genere: "m" | "f"`, `en: [singular, plural]` e `qualificabile: boolean`. Il plurale si usa quando `copie > 1` o per i nomi solo plurali (Pantaloni, Guanti, Scarpe, Jeans). Qualificatori:
- freddo: Outerwear/Shoes → it "invernale/invernali", en "Winter …"; altri → it "caldo/calda/caldi/calde", en "Warm …";
- acqua: it "impermeabile/impermeabili", en "Waterproof …";
- elegante: it "elegante/eleganti", en "Smart …".

Non si qualificano i nomi che lo dicono già (`qualificabile: false`): Down Jacket, Rain Jacket, Snow Boots, Thermal Top, Thermal Bottoms, Ski Jacket, Ski Pants, Ski Suit, Gloves, Umbrella, Blazer, Dress Shoes. `aggiungi`: in italiano "Aggiungi il tuo / la tua / i tuoi / le tue", secondo genere e numero del nome mostrato; in inglese sempre "Add yours".

- [ ] **Step 1: test che falliscono** (`posti.test.ts`, con gap costruiti a mano come in `uscita.test.ts`)

```ts
test("livello: la giacca col freddo e' importante, il maglione col freddo no", () => {
  const giacca = { tipo: "assente", category: "Outerwear", subCategories: ["Coat", "Down Jacket", "Casual Jacket", "Windbreaker"], warmth_richiesto: [4, 5], priorita: "necessario", essential: true };
  const maglione = { tipo: "assente", category: "Upper Body", subCategories: ["Sweater"], warmth_richiesto: [4, 5], priorita: "necessario", essential: true };
  assert.equal(livelloPosto(giacca, capoDelGap(giacca, true), true), "importante");
  assert.equal(livelloPosto(maglione, capoDelGap(maglione, true), true), "utile");
});
test("livello: magliette necessarie restano utili; costume e scarponi importanti; camicia elegante importante", () => { /* T-Shirt priorita necessario -> utile; Swimwear -> importante; Hiking Boots -> importante; Shirt formality ["Formal"] -> importante */ });
test("livello: scarpe senza freddo ne' pioggia sono utili", () => { /* Shoes, Sneakers, warmth [1,3], nessuna impermeabilita' -> utile */ });
test("nomi del mockup", () => {
  assert.deepEqual(nomePosto({ sub: null, categoria: "Outerwear" }, 1, "freddo", "it"), { nome: "Giacca invernale", aggiungi: "Aggiungi la tua" });
  assert.deepEqual(nomePosto({ sub: null, categoria: "Shoes" }, 1, "freddo", "it"), { nome: "Scarpe invernali", aggiungi: "Aggiungi le tue" });
  assert.deepEqual(nomePosto({ sub: "Cap/Hat", categoria: "Accessory" }, 1, "freddo", "it"), { nome: "Cappello caldo", aggiungi: "Aggiungi il tuo" });
  assert.deepEqual(nomePosto({ sub: "Gloves", categoria: "Accessory" }, 1, "freddo", "it"), { nome: "Guanti", aggiungi: "Aggiungi i tuoi" });
  assert.equal(nomePosto({ sub: "Sweater", categoria: "Upper Body" }, 3, "freddo", "it").nome, "Maglioni caldi");
  assert.equal(nomePosto({ sub: "T-Shirt", categoria: "Upper Body" }, 5, null, "it").nome, "Magliette");
  assert.equal(nomePosto({ sub: "T-Shirt", categoria: "Upper Body" }, 1, null, "it").nome, "Maglietta");
  assert.equal(nomePosto({ sub: "Trousers", categoria: "Lower Body" }, 1, null, "it").nome, "Pantaloni");
  assert.deepEqual(nomePosto({ sub: null, categoria: "Shoes" }, 1, "freddo", "en"), { nome: "Winter shoes", aggiungi: "Add yours" });
  assert.equal(nomePosto({ sub: "Sweater", categoria: "Upper Body" }, 3, "freddo", "en").nome, "Warm sweaters");
});
test("ogni sottocategoria e categoria ha il nome in tutte e due le lingue", () => { /* per ogni chiave di NOME_SOTTOCATEGORIA e NOME_CATEGORIA: nomePosto(...) non vuoto in it e en, singolare e plurale */ });
```

- [ ] **Step 2:** `cd supabase/functions/_shared && node --test valigia/test/posti.test.ts`. Atteso: FAIL, `posti.ts` non esiste.
- [ ] **Step 3:** scrivi la tabella, `livelloPosto`, `qualificaDelGap` e `nomePosto`, ed esporta da `uscita.ts` le funzioni elencate.
- [ ] **Step 4:** il test passa; `node --test valigia/test/uscita.test.ts` resta verde.
- [ ] **Step 5:** commit `feat(posti): livello e nomi dei posti della valigia`.

---

### Task 2: `postiApp` — copie, pezzi in meno, essenziali, informazioni

**Files:**
- Modify: `supabase/functions/_shared/valigia/posti.ts`
- Test: `supabase/functions/_shared/valigia/test/posti.test.ts`

**Interfaces:**
- Consumes: Task 1; `quantityFor` e `essenzialiPerViaggio` (`quantita.ts`); `caricaArmadio`, `Capo` (`capo.ts`); `lavanderiaPresunta` (`dopo.ts`); `copyMancante` (`uscita.ts`); costanti `K.REUSABLE`, `K.GIORNI_LAVANDERIA`, `K.TETTO_COPIE_STESSO_CAPO`.
- Produces:

```ts
export interface PostoApp {
  id: string;            // `${tipo}:${indice}`, indice nell'elenco finale
  tipo: string;          // sottocategoria del generatore, o categoria se generica, o famiglia: "intimo" | "calzini" | "notte" | "igiene"
  categoria: "vestiti" | "toiletries";
  livello: Livello;
  nome: string;
  copie: number;         // >= 1
  motivo: string | null;
  aggiungi: string;
}
export interface InfoApp { codice: string; titolo: string; perche: string }
export function postiApp(valigia: Record<string, any>, motivi: { capi: Record<string, any>[]; essenziali: Record<string, any>[] },
  salvate: Map<string, number | null>,
  contesto: { meteo?: Record<string, any> | null; viaggio?: Record<string, any> | null; armadio: Capo[]; lingua?: Lingua },
): { posti: PostoApp[]; informazioni: InfoApp[] }
```

**Da dove nascono i posti:**
1. **Mancanti** (`valigia.mancanti_canonici`, filtrati con `perQuestoArmadio`). Tipo `assente` o `posseduto_ma_inadatto`:
   - capo: `capoDelGap`;
   - livello: `livelloPosto`;
   - motivo: `copyMancante(...).perche`, così il motivo nomina le scarpe da corsa;
   - copie: 1 per le categorie di `K.REUSABLE`; altrimenti `quantityFor(sub, "", giorni, lavatrice, frequenza)`. `frequenza` è quella dello slot con lo stesso nome in `valigia.richiesti` ("daily" se manca). `giorni` e `lavatrice` sono quelli del viaggio, con giorni = `K.GIORNI_LAVANDERIA` quando `lavanderiaPresunta`; a tappe, la somma dei giorni delle tappe.
   - Tipo `quantita_insufficiente`: copie = `max(1, capi_diversi_necessari - ceil(usi_coperti / K.TETTO_COPIE_STESSO_CAPO))`.
2. **Pezzi in meno:** come il ramo `CODICE_POCHI` di `uscitaApp`. È un capo con `quantita > tetto`:
   - copie = la differenza;
   - tipo e nome: la sottocategoria del capo (dall'`armadio`), oppure la famiglia se è un essenziale;
   - livello: `livelloPosto`, ma mai importante se manca un pezzo solo;
   - motivo: lo stesso testo di "Ne servirebbero N, nell'armadio ne hai M".
3. **Essenziali di base assenti.** Le famiglie:
   - intimo: `mutand slip boxer perizoma intim underwear brief`;
   - calzini: `calz sock`;
   - notte: `RADICI_NOTTE`;
   - igiene: `beauty trousse necessaire nécessaire washbag toilette spazzolin dentifric shampoo deodorant`.

   Una famiglia senza nessuna voce in `valigia.essenziali` diventa un posto utile. Le copie si calcolano con `essenzialiPerViaggio` su un capo finto (`caricaArmadio([{ id: "posto:<famiglia>", name: "<nome italiano>", ... }])`), con gli stessi giorni, lavatrice e massima del generatore: così il numero è quello che avrebbe un utente con quell'oggetto.
   - Nomi: Mutande/Underwear, Calzini/Socks, Pigiama/Pyjamas, Necessaire/Toiletry bag.
   - Categoria: igiene → `toiletries`, le altre → `vestiti`.
4. **Uniti per `tipo`:** copie sommate; importante se lo è almeno uno; motivo di quello importante, o del primo.
5. **Ordine:** prima gli importanti, poi gli utili; dentro, l'ordine di nascita.

**Informazioni:** `volume_eccedente` e lavanderia diventano `InfoApp`, con gli stessi testi di oggi (`copyMancante` per il volume, le frasi della lavanderia di `uscitaApp`). Non sono mai posti. `postiApp` non tocca `uscitaApp`.

- [ ] **Step 1: test che falliscono**
  - armadio vuoto, viaggio a Seul di 31 notti (minime -7, 4 giorni di pioggia), mancanti costruiti come li dà il generatore per Outerwear, Shoes, Cap/Hat, Gloves, Sweater, T-Shirt, Trousers:
    - importanti esattamente {Giacca invernale, Scarpe invernali, Cappello caldo, Guanti};
    - utili comprendono Maglioni caldi, Magliette, Pantaloni, Mutande, Calzini, Pigiama, Necessaire;
    - nessun posto con `copie < 1`.
  - `quantita_insufficiente` con `usi_richiesti: 10, usi_coperti: 4, capi_diversi_necessari: 2` → copie 1.
  - capo T-Shirt con `quantita: 5` e salvate 2 → un posto utile "Magliette" ×3, tipo "T-Shirt".
  - mutande con `quantita: 8` e salvate 3 → posto "Mutande" ×5, tipo "intimo"; nessun altro posto "intimo".
  - armadio con un capo "Mutande" (senza copie) → nessun posto intimo; con armadio vuoto il posto intimo ha le stesse copie che `essenzialiPerViaggio` dà a quel capo.
  - due mancanti T-Shirt da slot diversi → un posto solo, copie sommate.
  - gonna, vestito e cravatta senza averne nell'armadio → nessun posto (`perQuestoArmadio`).
  - viaggio di 31 giorni senza lavatrice → `informazioni` contiene `lavanderia`; `volume_eccedente` → `informazioni`, mai `posti`.
  - inglese: nomi e `aggiungi` in inglese.
- [ ] **Step 2:** il test fallisce.
- [ ] **Step 3:** scrivi `postiApp` in `posti.ts`.
- [ ] **Step 4:** `node --test valigia/test/posti.test.ts valigia/test/uscita.test.ts` verdi.
- [ ] **Step 5:** commit `feat(posti): postiApp con copie, pezzi in meno ed essenziali di base`.

---

### Task 3: `pack-trip` accetta l'armadio vuoto e risponde con i posti

**Files:**
- Modify: `supabase/functions/pack-trip/index.ts`
- Modify (solo se serve per l'armadio vuoto): `supabase/functions/_shared/valigia/genera.ts`
- Test: `supabase/functions/_shared/valigia/test/genera.test.ts`
- Create: `supabase/functions/_shared/valigia/test/misura_posti.ts`

**Interfaces:**
- Consumes: `postiApp` (Task 2).
- Produces: la risposta di `pack-trip` aggiunge `posti: PostoApp[]` e `informazioni: InfoApp[]` accanto a `capi` e `avvisi`, che restano identici. Il commento in testa a `index.ts` documenta i due campi.

- [ ] **Step 1: test che fallisce** in `genera.test.ts`: `generaValigia` con `righe = []`, modello finto che restituisce gli slot di un caso del campione (`oracolo_celle_campione.json`, primo caso `singola`), Jev `null`, clima finto → nessuna eccezione, `valigia.ideali` vuoto, `valigia.mancanti_canonici.length > 0`, e `postiApp(...)` dà almeno un posto.
- [ ] **Step 2:** il test fallisce, oppure passa già: in quel caso lo si tiene come guardia e si va avanti.
- [ ] **Step 3:** in `index.ts` togli il `422 "Wardrobe is empty"`. Lascia `MAX_CAPI` e il 422 "Wardrobe too large". Aggiungi `...postiApp(r.valigia, r.motivi, salvate, { meteo, viaggio, armadio: caricaArmadio(righe), lingua })` alla risposta.
- [ ] **Step 4:** verifiche:
  - `node --test supabase/functions/_shared` (104/105 + i nuovi);
  - `node valigia/test/confronta_celle.ts <oracolo intero>` e `confronta_motivi.ts`: 888/888;
  - `deno check` di `pack-trip`, con solo gli errori noti (`claude.ts`); cancella il `deno.lock` che il check crea.
- [ ] **Step 5: script di misura** `misura_posti.ts`, uso: `node valigia/test/misura_posti.ts ORACOLO.json --armadio vuoto|meta`.
  - Rigioca ogni caso dell'oracolo come `confronta_celle.ts`, ma con l'armadio vuoto (`[]`) oppure a metà (le righe di indice pari). Poi chiama `postiApp`; `viaggio` e `meteo` minimi si ricavano dagli `args` del caso.
  - **Salta i casi dell'insieme v4** (sigillato).
  - Stampa per insieme:
    - posti per valigia (media e mediana);
    - importanti per valigia (media, mediana, massimo);
    - quota di valigie con più di 6 importanti;
    - i 15 nomi importanti e i 15 utili più frequenti;
    - gli id dei casi con più di 8 importanti.
- [ ] **Step 6:** esporta l'oracolo intero dal bench, come nel ledger del catalogo (`esporta_oracolo.py celle`, nel venv del bench, verso lo scratchpad). Lancia lo script nei due modi e salva l'uscita in `docs/superpowers/specs/2026-11-01-misura-posti.md`, che leggerà Davide. Non ci sono soglie che bloccano.
- [ ] **Step 7:** commit `feat(pack-trip): armadio vuoto ammesso, posti e informazioni nella risposta`.

---

### Task 4: Il modello dei posti nell'app

**Files:**
- Modify: `lib/features/trips/model/ai_packing.dart` (+ `build_runner`)
- Modify: `lib/features/trips/services/pack_trip_service.dart` (`parsePackTripResponse`)
- Create: `lib/features/trips/model/suitcase_progress.dart`
- Test: `test/features/trips/model/ai_packing_test.dart`, `test/features/trips/services/pack_trip_service_test.dart`, `test/features/trips/model/suitcase_progress_test.dart`

**Interfaces:**
- Produces:

```dart
enum AiSlotLevel { @JsonValue('importante') important, @JsonValue('utile') useful }

@freezed
class AiSlot with _$AiSlot {
  const AiSlot._();
  const factory AiSlot({
    required String id,
    required String type,
    required ItemCategory category,
    required AiSlotLevel level,
    required String name,
    required int copies,       // copie proposte all'inizio
    required int remaining,    // copie ancora da riempire; 0 = sparito
    String? reason,
    required String addLabel,
    @Default(false) bool toBuy,
    @Default(false) bool checked,
  }) = _AiSlot;
  bool get isOpen => remaining > 0;
  factory AiSlot.fromJson(Map<String, dynamic> json) => _$AiSlotFromJson(json);
}

@freezed
class AiTripNote with _$AiTripNote {
  const factory AiTripNote({required String code, required String title, required String why}) = _AiTripNote;
  factory AiTripNote.fromJson(Map<String, dynamic> json) => _$AiTripNoteFromJson(json);
}
```

- `AiPackingResult` riceve `List<AiSlot>? slots` (null = risultato vecchio, senza posti) e `@Default(<AiTripNote>[]) List<AiTripNote> notes`, più due metodi:
  - `AiPackingResult withSlot(String slotId, AiSlot Function(AiSlot) change)`;
  - `bool get hasSlots => slots != null`.
- `AiPackingResult carryToBuy(AiPackingResult? previous, AiPackingResult next)`, funzione di primo livello in `ai_packing.dart`: un posto aperto di `next` diventa `toBuy` se in `previous` c'era un posto aperto, dello stesso `type`, segnato `toBuy`.
- `parsePackTripResponse` legge `posti` e `informazioni`:
  - copie → `copies` e `remaining`; `aggiungi` → `addLabel`; `categoria` "vestiti"/"toiletries" → `ItemCategory`;
  - un posto con livello o categoria sconosciuti si scarta, come gli avvisi;
  - `posti` assente → `slots: null`.
- `SuitcaseProgress`:

```dart
class SuitcaseProgress {
  factory SuitcaseProgress.of(TripModel trip);
  final int mine;            // trip.items.length
  final int proposed;        // posti utili aperti
  final int importantOpen;   // posti importanti aperti, "da comprare" compresi
  final int checked;         // oggetti spuntati + proposti spuntati
  bool get sorting => importantOpen > 0;
  int get ready => mine + proposed;
  int get readyTotal => mine + proposed + importantOpen;
  int get packTotal => mine + proposed;
  bool get isEmpty => readyTotal == 0;
}
```

- [ ] **Step 1: test che falliscono**
  - JSON con `posti` → `slots` letti, `remaining == copies`;
  - JSON senza `posti` → `slots == null`, `warnings` come oggi;
  - livello sconosciuto → posto scartato;
  - `toJson`/`fromJson` di andata e ritorno con `toBuy` e `checked`;
  - `carryToBuy`: "Scarf" toBuy prima e c'è dopo → toBuy; "Scarf" non c'è più → niente; posto chiuso prima → niente;
  - `SuitcaseProgress`:
    - 4 oggetti, 9 utili aperti, 5 importanti aperti (uno `toBuy`) → `sorting`, `ready 13`, `readyTotal 18`;
    - 9 oggetti (4 spuntati), 2 utili aperti (1 spuntato), 0 importanti → `!sorting`, `checked 5`, `packTotal 11`;
    - 0 e 0 → `isEmpty`.
- [ ] **Step 2:** i test falliscono.
- [ ] **Step 3:** scrivi il codice e lancia `build_runner`.
- [ ] **Step 4:** test mirati verdi, `flutter analyze` pulito.
- [ ] **Step 5:** commit `feat(valigia): modello dei posti e avanzamento in due fasi`.

---

### Task 5: Rapid Fire con le copie

**Files:**
- Create: `lib/features/items/helpers/copies_parser.dart`
- Modify: `lib/features/items/widgets/rapid_fire_input.dart`
- Modify: `assets/translations/it-IT.json`, `en-US.json`
- Test: `test/features/items/helpers/copies_parser_test.dart`, `test/features/items/widgets/rapid_fire_input_test.dart` (crea se manca)

**Interfaces:**
- Produces:
  - `({String name, int copies})? parseCopies(String text)`;
  - `RapidFireInput` riceve due parametri:
    - `ValueChanged<ItemModel>? onItemCreated`, chiamato dopo un `addItem` riuscito;
    - `String? hintText`, che sostituisce `items.rapid_fire_hint`.

**Regole di `parseCopies`:**
- numero iniziale `^\s*(\d{1,2})\s+(\S.*)$`;
- oppure numero dopo una virgola in fondo `^(.*\S)\s*,\s*(\d{1,2})\s*$`;
- vale solo con N fra 2 e 99; se ci sono tutti e due, vince l'iniziale;
- niente "x2" né "n".

**La pillola:**
- "×N" compare accanto al campo quando `parseCopies` dà un risultato;
- toccarla la toglie per questo testo (torna quando il campo si svuota);
- all'invio, con la pillola si crea `name` con `quantity: copies`, altrimenti il testo intero con 1.

**Testi:**
- `items.rapid_fire_hint` diventa "Es. 2 t-shirt nere" / "E.g. 2 black t-shirts";
- la prima volta che la pillola compare, sotto il campo c'è la riga `items.copies_tip`: "Il numero all'inizio sono le copie. Tocca ×{} per toglierlo." / "A number at the start sets the copies. Tap ×{} to remove it.";
- la riga non torna più dopo (`SharedPreferences`, chiave `rapid_fire_copies_tip_seen`).

- [ ] **Step 1: test che falliscono**
  - "2 t-shirt nere" → (t-shirt nere, 2);
  - "t-shirt nera, 2" → (t-shirt nera, 2);
  - "t-shirt nera,2" → (t-shirt nera, 2);
  - "1 t-shirt" → null; "0 calzini" → null; "iPhone 15" → null; "Cavo, 100" → null;
  - "2 in 1 caricatore" → (in 1 caricatore, 2);
  - "x2 calzini" e "calzini x2" → null;
  - widget:
    - scrivere "2 t-shirt nere" mostra "×2" e l'invio crea l'oggetto "T-shirt nere" con quantità 2 (la maiuscola la mette il formatter);
    - toccare "×2" su "2 in 1 caricatore" e inviare crea "2 in 1 caricatore" con quantità 1;
    - la riga del suggerimento compare una volta sola;
    - `onItemCreated` riceve l'oggetto creato.
- [ ] **Step 2:** i test falliscono.
- [ ] **Step 3:** scrivi il parser e le modifiche al widget.
- [ ] **Step 4:** test mirati verdi, e `test/features/houses` verde: la casa usa lo stesso campo.
- [ ] **Step 5:** commit `feat(rapid-fire): copie col numero davanti o dopo la virgola`.

---

### Task 6: Il gradiente di PackLog, la stima del meteo e l'attesa

**Files:**
- Create: `lib/shared/widgets/packlog_gradient.dart`
- Modify: `lib/features/trips/view/widgets/pack/pack_weather.dart`
- Modify: `lib/features/trips/view/ai_packing_wait_screen.dart`
- Modify: traduzioni
- Test: `test/shared/widgets/packlog_gradient_test.dart`, test esistenti del meteo e dell'attesa

**Interfaces:**
- Produces:
  - `const kPackLogGradientColors = [Color(0xFFFF8A50), Color(0xFFFBBF24), Color(0xFFF472B6)]`;
  - `class PackLogGradientBorder extends StatefulWidget { child, double radius, double width = 1.5, int loops = 0 /* 0 = fermo, -1 = finché è montato */, Duration period = const Duration(seconds: 6) }`;
  - `class PackLogSparkle extends StatefulWidget { double size, bool breathing = false }`, la scintilla piena col gradiente.
  - Entrambi stanno fermi con `MediaQuery.disableAnimationsOf(context)`. Dopo i giri, il bordo resta colorato e fermo.

**Comportamento:**
- **Card del meteo:**
  - in cima c'è la riga con `PackLogSparkle` e "Stima" (`trips.weather.estimate`: "Stima" / "Estimate") quando la fonte è il clima o mista, "Previsione" (`trips.weather.forecast_label`: "Previsione" / "Forecast") quando è la previsione, in grigio (`onSurfaceVariant`);
  - la card è dentro `PackLogGradientBorder`;
  - **2 giri solo se la stima arriva mentre la pagina è aperta** (lo stato passa da caricamento a pronto); aperta con il meteo già in cache, il bordo è fermo.
- **Attesa:**
  - l'icona in cima diventa `PackLogSparkle(breathing: true)`;
  - l'elenco dei tre passi sta in un `PackLogGradientBorder(loops: -1)`.

- [ ] **Step 1: test che falliscono**
  - con `loops: 2` il bordo si muove e dopo `2 × period` non ha più ticker attivi;
  - con `disableAnimations` nessun ticker;
  - il meteo dal clima mostra "Stima"; aperto con lo stato già pronto → `loops == 0`; da caricamento a pronto → `loops == 2`;
  - l'attesa mostra `PackLogSparkle` e `PackLogGradientBorder`.
- [ ] **Step 2:** i test falliscono.
- [ ] **Step 3:** scrivi il codice.
- [ ] **Step 4:** test mirati e `test/features/trips/view/ai_packing_wait_screen_test.dart` verdi.
- [ ] **Step 5:** commit `feat(ds): gradiente PackLog sulla stima del meteo e sull'attesa`.

---

### Task 7: I posti nel dettaglio del viaggio

**Files:**
- Modify: `lib/features/trips/view/trip_detail_screen.dart` (diventa `ConsumerStatefulWidget`, per il Task 8)
- Create: `lib/features/trips/view/widgets/slots/slot_widgets.dart`
- Modify: `lib/features/trips/providers/trip_provider.dart`
- Modify: traduzioni
- Test: `test/features/trips/view/trip_detail_slots_test.dart`, `test/features/trips/providers/trip_provider_test.dart` (o il file esistente dei test del notifier)

**Interfaces:**
- Consumes: Task 4 (`AiSlot`, `SuitcaseProgress`, `withSlot`); Task 6 (`PackLogGradientBorder`, `PackLogSparkle`).
- Produces, in `TripNotifier`:
  - `Future<void> updateAiSlot(String tripId, String slotId, AiSlot Function(AiSlot) change)`: scrive con `updateTrip`, aggiornando prima lo stato, come `toggleItemCheck`;
  - in `slot_widgets.dart`: `ImportantSlotCard`, `ToBuySlotRow`, `ProposedSlotsCard`, `SuitcaseProgressHeader`, `TripNoteRow`.

**Come si vede** (solo con `aiResult?.hasSlots == true`; altrimenti la sezione di oggi, invariata):
- **Testata "Cosa porti", con `SuitcaseProgressHeader`:**
  - se `sorting`: la barra `ready/readyTotal`, il testo `trips.detail.ready_count` "{} di {} pronti" / "{} of {} ready" e la legenda di tre voci:
    - `trips.detail.legend_mine` "{} tue" / "{} yours";
    - `trips.detail.legend_proposed` "{} proposte da PackLog" / "{} suggested by PackLog";
    - `trips.detail.legend_important` "{} importanti da sistemare" / "{} important to sort out";
  - altrimenti la barra delle spunte di oggi (`checked/packTotal`, `trips.detail.packed_count`);
  - `isEmpty` → lo stato vuoto di oggi.
- **Sotto la testata:** una `TripNoteRow` per ogni `notes` (icona info, titolo, perché).
- **Per categoria**, nell'ordine di `ItemCategory.values`. La testata del gruppo conta posti aperti più oggetti; dentro:
  1. `ImportantSlotCard` per ogni importante aperto e non `toBuy`:
     - etichetta piccola con bandierina `trips.slots.important` "Importante" / "Important";
     - nome (con ×N se `remaining > 1`) e motivo in una riga;
     - due azioni testuali: `addLabel` e `trips.slots.to_buy` "Da comprare" / "To buy". Niente bottoni pieni.
  2. `ToBuySlotRow` per ogni importante aperto e `toBuy`:
     - riga più spenta: "Importante" · "Da comprare" · nome;
     - azione testuale `trips.slots.got_it` "Presa" / "Got it", che apre il Task 8 per quel posto.
  3. `ProposedSlotsCard` con gli utili aperti (i `toBuy` in fondo):
     - dentro `PackLogGradientBorder` fermo;
     - intestazione con `PackLogSparkle` e `trips.slots.proposed_header` "Proposti da PackLog · tocca per mettere i tuoi" / "Suggested by PackLog · tap to add yours";
     - righe con scintilla (con `!sorting`: casella al posto della scintilla), nome, ×N e freccina;
     - il tocco sulla riga apre il Task 8; la casella cambia `checked`.
  4. Gli oggetti dell'utente, con la riga di oggi.
- **"Da comprare" sulla card:**
  - `updateAiSlot(... toBuy: true)`;
  - snack `trips.slots.marked_to_buy` "Segnato da comprare" / "Marked to buy", con Annulla che rimette `toBuy: false`.

- [ ] **Step 1: test che falliscono** (widget, con un viaggio finto come nel mockup: 4 oggetti, 9 utili, 4 importanti aperti + 1 importante `toBuy`)
  - si vedono "13 di 18 pronti", "4 tue", "9 proposte da PackLog", "5 importanti da sistemare";
  - 4 `ImportantSlotCard`, 1 `ToBuySlotRow`, 1 `ProposedSlotsCard`;
  - toccare "Da comprare" su una card la sposta fra le righe da comprare e la legenda non cambia;
  - Annulla la riporta;
  - con tutti gli importanti chiusi compare "N di M in valigia" e le righe proposte hanno la casella; spuntarne una alza il conteggio;
  - risultato senza posti (`slots: null`) → la schermata è quella di oggi (test esistenti invariati);
  - viaggio senza oggetti né posti → stato vuoto;
  - `notes` con lavanderia → la riga "Prevedi una lavanderia".
- [ ] **Step 2:** i test falliscono.
- [ ] **Step 3:** scrivi il codice.
- [ ] **Step 4:** test mirati verdi, `flutter analyze` pulito.
- [ ] **Step 5:** commit `feat(viaggio): la valigia fatta di posti nel dettaglio del viaggio`.

---

### Task 8: Riempire un posto con il Rapid Fire

**Files:**
- Create: `lib/features/trips/view/widgets/slots/slot_rapid_fire_bar.dart`
- Modify: `lib/features/trips/view/trip_detail_screen.dart`
- Modify: `lib/features/trips/providers/trip_provider.dart`
- Modify: `lib/core/routing/app_router.dart` (`/trips/:id` legge `?slot=`)
- Modify: traduzioni
- Test: `test/features/trips/view/trip_detail_slot_fill_test.dart`, test del notifier

**Interfaces:**
- Consumes: Task 5 (`RapidFireInput.onItemCreated`, `hintText`); Task 7 (`updateAiSlot`, widget dei posti).
- Produces:
  - `TripDetailScreen({required String tripId, String? initialSlotId})`;
  - `Future<void> fillAiSlot(String tripId, String slotId, TripItem item)` in `TripNotifier`. Una sola scrittura: l'oggetto entra fra gli `items` (se c'è già lo stesso id, si sommano le quantità) e `remaining = max(0, remaining - item.quantity)`.

**Comportamento:**
- **Aprire la barra.** Toccare un proposto, "Aggiungi il tuo" o "Presa", oppure aprire `/trips/:id?slot=<id>`, mette in fondo alla pagina, al posto di "Modifica valigia", la `SlotRapidFireBar`:
  - chip di contesto: `PackLogSparkle`, `trips.slots.context_chip` "{} · {} da personalizzare" / "{} · {} to personalise" (nome, remaining), X per chiudere;
  - azione testuale "Da comprare" a lato;
  - il `RapidFireInput` della casa di partenza (`aiResult.houseId`) con hint "Es. 2 t-shirt nere".
- **Ogni invio:**
  - crea l'oggetto nella casa, come il Rapid Fire di sempre (la scheda dettagli parte da sola);
  - poi `fillAiSlot` con `TripItem(id, name, category, quantity: item.quantity ?? 1, originHouseId: houseId)`;
  - la riga del posto si aggiorna sotto gli occhi; a `remaining == 0` la barra si chiude.
- **"Da comprare" nella barra:** `toBuy: true`, chiude la barra, snack con Annulla.
- **La casa di partenza non esiste più:** la barra non si apre e uno snack lo dice (`trips.slots.no_house`: "La casa di partenza non c'è più" / "The departure home no longer exists").

- [ ] **Step 1: test che falliscono**
  - toccare "Magliette ×5" apre la barra con "Magliette · 5 da personalizzare";
  - inviare "2 t-shirt nere" crea l'oggetto con quantità 2 nella casa, lo mette in valigia e il posto mostra ×3;
  - inviare "5 t-shirt" su ×3 → posto sparito, barra chiusa, oggetto con 5;
  - `?slot=` apre la barra all'avvio;
  - "Da comprare" nella barra marca il posto;
  - `fillAiSlot` su un posto inesistente non cambia nulla.
- [ ] **Step 2:** i test falliscono.
- [ ] **Step 3:** scrivi il codice.
- [ ] **Step 4:** test mirati verdi.
- [ ] **Step 5:** commit `feat(viaggio): riempire un posto con il Rapid Fire`.

---

### Task 9: Dopo la generazione si arriva alla valigia

**Files:**
- Modify: `lib/features/trips/view/pack_suitcase_screen.dart`
- Test: `test/features/trips/view/pack_suitcase_ai_flow_test.dart`, `pack_suitcase_ai_mode_test.dart`

**Interfaces:**
- Consumes: Task 4 (`hasSlots`, `carryToBuy`).

**Comportamento:**
- **`_adoptResult`:**
  - salva `carryToBuy(trip.aiResult, result)`;
  - se il risultato ha i posti e il salvataggio è riuscito, lascia la pagina e mostra il dettaglio: `context.pushReplacement('/trips/${trip.id}')` se `fromNewTrip`, altrimenti `context.pop()`;
  - senza posti (funzione vecchia) resta come oggi.
- **Con un risultato con i posti**, "Modifica valigia" passa ad `AiPackRows` `warnings: const []`: niente "Cosa manca a questo viaggio", i motivi restano. Per i risultati vecchi, invariato.

- [ ] **Step 1: test che falliscono**
  - generazione dal nuovo viaggio con posti → la rotta finale è il dettaglio del viaggio, e il viaggio salvato ha `slots`;
  - rigenerare da "Modifica valigia" → si torna al dettaglio, e un posto `toBuy` dello stesso tipo resta `toBuy`;
  - risultato senza posti → comportamento di oggi (i test esistenti restano verdi).
- [ ] **Step 2:** i test falliscono.
- [ ] **Step 3:** scrivi il codice.
- [ ] **Step 4:** `test/features/trips/view/` verde.
- [ ] **Step 5:** commit `feat(valigia): dopo la generazione si vede la valigia`.

---

### Task 10: La vista "Da comprare"

**Files:**
- Create: `lib/features/trips/view/to_buy_screen.dart`
- Create: `lib/features/trips/providers/to_buy_provider.dart` (+ `build_runner`)
- Modify: `lib/features/trips/view/trips_screen.dart`
- Modify: `lib/core/routing/app_router.dart` (rotta `/trips/to-buy`, dichiarata prima di `/trips/:id`)
- Modify: traduzioni
- Test: `test/features/trips/view/to_buy_screen_test.dart`, `test/features/trips/providers/to_buy_provider_test.dart`

**Interfaces:**
- Consumes: Task 4, Task 7 (`updateAiSlot`), Task 8 (`/trips/:id?slot=`).
- Produces: `class ToBuyEntry { final TripModel trip; final AiSlot slot; }` e il provider `toBuyEntries` → `List<ToBuyEntry>`: i posti aperti con `toBuy` di tutti i viaggi non cancellati. L'ordine segue la partenza del viaggio più vicina; dentro un viaggio, prima gli importanti.

**Comportamento:**
- **Nella tab Viaggi**, in cima, la riga `trips.to_buy.entry` "Da comprare · {}" / "To buy · {}". Compare solo con almeno una voce e apre `/trips/to-buy`.
- **La vista**, titolo `trips.to_buy.title` "Da comprare" / "To buy":
  - raggruppata per viaggio (nome del viaggio come testata);
  - ogni riga: "Importante" se lo è, nome, ×copie, azione "Presa" che porta a `/trips/<id>?slot=<slotId>`;
  - vuota: `trips.to_buy.empty` "Niente da comprare" / "Nothing to buy".

- [ ] **Step 1: test che falliscono**
  - due viaggi con posti `toBuy` → righe raggruppate, l'importante prima;
  - un posto chiuso (`remaining 0`) non c'è;
  - "Presa" naviga a `/trips/t1?slot=s1`;
  - la riga nella tab Viaggi compare con 1 e sparisce con 0.
- [ ] **Step 2:** i test falliscono.
- [ ] **Step 3:** scrivi il codice e lancia `build_runner`.
- [ ] **Step 4:** test mirati e `trips_screen_test.dart` verdi.
- [ ] **Step 5:** commit `feat(viaggi): la vista Da comprare`.

---

### Task 11: Il foglio della valigia AI per il primo viaggio

**Files:**
- Modify: `lib/features/trips/model/trip_weather.dart` (`WeatherStopRequest` riceve `final String? houseId`, non serializzato)
- Modify: `lib/features/trips/view/widgets/ai/ai_packing_sheet.dart`
- Modify: traduzioni
- Test: `test/features/trips/view/ai_packing_sheet_test.dart`, `test/features/trips/model/trip_weather_test.dart`

**Interfaces:**
- Consumes: `HouseNotifier.addHouse(HouseModel)`.
- Produces: `WeatherStopRequest.houseId`. Per la tappa principale è `trip.destinationHouseId`, per una tratta `leg.houseId`.

**Comportamento:**
- **Attività e alloggio obbligatori** anche con una tappa sola. "Prepara" con una tappa incompleta mostra l'avviso di oggi (`_IncompleteWarning`, con "Vai" e "Copia da") e non chiude mai il foglio: il secondo tocco non salta più.
- **Alloggio preselezionato:** una tappa con `houseId` e nessuna risposta parte con `stay: 'apartment'`, che resta modificabile.
- **Casa creata nel foglio**, solo per chi non ha nessuna casa:
  - al posto della scelta della casa, un campo `trips.ai.house_name_label` "Casa di partenza" / "Leaving from", già scritto `trips.ai.house_name_default` "Casa" / "Home";
  - il footer c'è anche senza case;
  - "Prepara" crea la casa (`addHouse`, nome dal campo, vuoto → il default) e restituisce `AiPackingSetup` con quel `houseId`.
  - Ruling: chi ha già una casa, anche vuota, la sceglie come oggi. Ora l'armadio vuoto è ammesso, quindi una seconda casa non serve.

- [ ] **Step 1: test che falliscono**
  - una tappa senza attività: "Prepara" due volte → il foglio resta aperto con l'avviso;
  - destinazione casa dell'utente → "Appartamento" già scelto;
  - nessuna casa → il campo "Casa"; "Prepara" crea una casa "Casa" e il setup ha il suo id;
  - con una casa → la scelta di oggi.
- [ ] **Step 2:** i test falliscono.
- [ ] **Step 3:** scrivi il codice.
- [ ] **Step 4:** `ai_packing_sheet_test.dart`, `ai_stop_form_test.dart` e `trip_weather_test.dart` verdi.
- [ ] **Step 5:** commit `feat(valigia-ai): attivita' e alloggio obbligatori, casa creata nel foglio`.

---

### Task 12: Il primo avvio passa da "Dove vai?"

**Files:**
- Modify: `lib/features/tour/model/onboarding_state.dart` (aggiungi `firstTrip` **in fondo** all'enum)
- Modify: `lib/features/tour/repositories/shared_prefs_onboarding_repository.dart` (senza passo salvato → `firstTrip`)
- Modify: `lib/features/tour/providers/post_login_onboarding_provider.dart` (`completeFirstTrip()`)
- Modify: `lib/core/routing/app_router.dart`
- Modify: `lib/features/trips/view/new_trip_screen.dart` (parametro `firstRun`)
- Modify: `lib/features/trips/view/pack_suitcase_screen.dart` (generazione riuscita → `completeFirstTrip()`)
- Modify: traduzioni
- Test: `test/core/routing/` (il file dei redirect esistente), `test/features/tour/`, `test/features/trips/view/new_trip_screen_test.dart`

**Interfaces:**
- Produces:
  - `OnboardingStep.firstTrip`;
  - `Future<void> PostLoginOnboarding.completeFirstTrip()`, che salva `done`;
  - `NewTripScreen(firstRun: bool)`, letto da `/new-trip?ai=1&first=1`.

**Comportamento:**
- **Account senza passo salvato** (installazione nuova): dopo il login il passo è `firstTrip`.
  - Il router porta a `/new-trip?ai=1&first=1` da ogni rotta della shell, una volta sola: il redirect vale finché il passo è `firstTrip` e la rotta non è `/new-trip`, `/trips/...` o `/onboarding...`.
  - Il tour delle foto (`aiIntro`) non parte più per i nuovi. Resta per "Ripeti il tour" (`reset` invariato) e per chi aveva già salvato `aiIntro`.
- **`firstRun`:**
  - il titolo è `trips.new.first_title` "Dove vai?" / "Where are you going?";
  - c'è una X che chiama `completeFirstTrip()` e porta a `/`;
  - il resto è il passo 1 con `aiIntent` (primario "Prepara con AI").
- **La generazione riuscita** del primo viaggio chiama `completeFirstTrip()`. I tip di casa e viaggio non partono per chi arriva da `firstTrip`: ha già fatto quello che spiegano.
- I passi salvati per indice non cambiano: `firstTrip` va in fondo.

- [ ] **Step 1: test che falliscono**
  - prefs vuote → `firstTrip`;
  - autenticato con `firstTrip` su `/` → redirect a `/new-trip?ai=1&first=1`;
  - su `/trips/x/edit-items` → nessun redirect;
  - prefs con `done` → nessun redirect;
  - prefs con `aiIntro` → la strada di oggi;
  - la X → `done` e `/`;
  - `completeFirstTrip` dopo la generazione → `done`.
- [ ] **Step 2:** i test falliscono.
- [ ] **Step 3:** scrivi il codice.
- [ ] **Step 4:** test mirati verdi, e `test/features/tour` tutto verde.
- [ ] **Step 5:** commit `feat(onboarding): il primo avvio porta alla prima valigia`.

---

### Task 13: Misurare con Amplitude

**Files:**
- Modify: i punti dove succedono gli eventi: `new_trip_screen.dart`, `pack_suitcase_screen.dart`, `trip_provider.dart`, `trip_detail_screen.dart`, `to_buy_screen.dart`
- Test: test esistenti di quei file, con l'analytics finta già usata nei test (`analyticsServiceProvider` sostituito)

**Eventi** (nomi decisi qui, proprietà in snake_case come gli altri):
- `first_trip_started` `{}`: salvataggio del passo 1 con `firstRun`;
- `first_suitcase_generated`, alla prima generazione riuscita dell'account (chiave `SharedPreferences` `first_suitcase_logged`):
  - `{slots_important, slots_proposed, slots_total, trip_items, from_first_run}`;
- `slot_filled` `{level, copies}`: ogni `fillAiSlot`;
- `slot_marked_to_buy` `{level, from}` (`from`: `card` | `bar`);
- `slot_bought` `{level}`: "Presa" seguito da un riempimento.

Ruling: niente evento di "ritorno". Il ritorno al giorno 1 e al giorno 7 si legge nella retention di Amplitude, con `first_suitcase_generated` come evento di partenza.

- [ ] **Step 1: test che falliscono:** ogni evento parte una volta con le proprietà giuste; `first_suitcase_generated` non riparte alla seconda generazione.
- [ ] **Step 2:** i test falliscono.
- [ ] **Step 3:** aggiungi le chiamate.
- [ ] **Step 4:** test mirati verdi.
- [ ] **Step 5:** commit `feat(analytics): eventi del percorso fino alla prima valigia`.

---

### Task 14: Chiusura

- [ ] **Step 1:** `flutter analyze` pulito; `flutter test` completo verde; `node --test supabase/functions/_shared` (solo `claude.test.ts` noto); `confronta_celle.ts` e `confronta_motivi.ts` 888/888; `deno check` di `pack-trip` con i soli errori noti.
- [ ] **Step 2:** screenshot del dettaglio con i posti, chiaro e scuro, con l'harness `test/screenshots/ui_screenshots_test.dart`: aggiungi lo scenario "valigia con posti" del mockup.
- [ ] **Step 3:** conta i tocchi dall'installazione alla prima valigia con armadio vuoto, prima (develop) e dopo, schermata per schermata, e scrivili nel testo della PR.
- [ ] **Step 4:** scrivi il testo della PR in `scratchpad/ds-piani/pr-prima-valigia.md`. Deve contenere:
  - la dipendenza da `feat/catalogo-tag` e `fix/rifiniture-leo`;
  - il deploy di `pack-trip`, senza migrazione né segreti nuovi;
  - l'ordine: **deploy della funzione prima del rilascio dell'app**. Un'app nuova con la funzione vecchia funziona come oggi; un'app vecchia con la funzione nuova non riceve più "Wardrobe is empty" e mostra gli avvisi di un armadio vuoto;
  - il link a `2026-11-01-misura-posti.md`.
- [ ] **Step 5:** commit finale, se rimane qualcosa da committare. Niente push: lo fa il controllore, dopo la revisione finale.
