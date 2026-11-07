# PackLog — passaggio di consegne

Aggiornato: 7 novembre 2026. Si aggiorna a ogni lavoro chiuso.

**Per riprendere in una sessione nuova:** "leggi `/srv/claude/workspaces/PackLog-giri-dev/docs/superpowers/handoff.md` e la memoria, poi riprendi dal primo punto aperto".

## 0. Dal 7 novembre (ha la precedenza sul resto)

- **Fatto con GPT, dal 5 al 7 nov:** Davide ha unito in develop le PR #98-#106; la #107 (quantità al mare) è aperta.
- **Revisione del 7 nov** (memoria `revisione-codex-7-novembre.md`):
  - il generatore dell'app non rifà più il banco: 618/888;
  - il #105 va contro la decisione del 18 ottobre sulle escursioni leggere;
  - ci sono errori nuovi nelle proposte.
- **Piano deciso da Davide il 7 nov:**
  1. **Banco su GitHub** (`davidetarsi/checklist-script-packlog`). Le valigie registrate sono committate e pushate su `feat/catalogo` (commit `337fa4e`). Davide apre la PR da `feat/catalogo` verso `main`: https://github.com/davidetarsi/checklist-script-packlog/compare/main...feat/catalogo
  2. **FATTO (7 nov): banco allineato**, ramo `feat/allinea-app-novembre` pushato.
     - Contiene #105 senza la conversione, il cammino compatto, le quantità al mare, le asserzioni di Santiago compatte (chiese = copertura, quantità solo coi capi tecnici) e la correzione delle "cene informali".
     - Numeri: holdout30 549/630, pool44 621/660, v2 494/504, v3 375/504, v4 277/504 (solo totale).
     - Esperimenti NON adottati: `exp/strati-minima` ed `exp/strati-attivita`, solo locali.
     - Davide deve aprire le PR: prima `feat/catalogo` → `main`, poi `feat/allinea-app-novembre`.
     - **Storico del punto 2, il piano iniziale:**
     - Dove: ramo `feat/allinea-app-novembre`, worktree `/srv/claude/workspaces/bench-allinea`, brief in `scratchpad/ds-piani/brief-allinea-banco.md`.
     - Del #105 si porta tutto tranne la conversione delle escursioni leggere.
     - Il cammino è compatto, deciso da Davide il 7 nov: le asserzioni di Santiago si riscrivono con una proposta separata che Davide deve approvare.
  3. **Misura sul banco** (v4 solo totale), poi rigenerazione degli oracoli; l'app deve rifare il banco 888/888.
  4. **FATTO (7 nov): app allineata.** Ramo `fix/allinea-banco` pushato: sostituisce la #107, che va chiusa senza unirla.
     - App = banco 888/888.
     - Comando di controllo: `valuta_con_banco.ts` + `VALUTA_CON_BANCO.md`.
     - Correzioni dei suggerimenti: niente ombrello, pioggia vera, giacca e cappello/sciarpa per fasce di minima, niente fuori contesto, nomi.
     - Regole fisse come test (`regole_posti.test.ts`).
     - PR: https://github.com/davidetarsi/PackLog/compare/develop...fix/allinea-banco
     - Deploy: solo `pack-trip`.
  5. **Poi:**
     - scarponi corretti solo nei nomi delle proposte;
     - "importante" solo con pioggia vera, perché oggi la giacca impermeabile è importante in 246 viaggi sopra i 28°;
     - niente stivali o scarpette fuori contesto;
     - nomi "Leggings/Camicie calde";
     - "5 camicie eleganti".
  6. **App:**
     - spezzare `house_detail_screen.dart` (1098 righe);
     - spostare in un widget piccolo la misura della barra del Rapid Fire, fatta durante il disegno (`:491`, `:683`);
     - `rapid_fire_input.dart` è a 557 righe.
- **Superati dai merge:** le sezioni A e B qui sotto (armadio tipico, Rapid Fire, PR da aprire) sono già in develop, in gran parte rifatte da GPT. Restano validi i punti C.

---

## A. In corso adesso (agenti ripartiti il 3 nov sera)

### A1. Generatore delle proposte: armadio tipico
- **Cosa:** il nome di ogni proposta (posto) lo sceglie la funzione di matching del generatore delle valigie, applicata a un armadio virtuale di capi tipici. Sostituisce i filtri a mano della "regola D".
- **Dove:**
  - ramo locale `feat/proposte-come-generatore`, worktree `/srv/claude/workspaces/PackLog-proposte`;
  - parte da `fix/posti-armadio-vuoto`;
  - commit già fatti: `50be99c` (regola D) e `d92aa67` (calore dalla scala della scansione). Nessuno è pushato.
- **Dati:** `docs/superpowers/dati/armadio-tipico-export.csv`, cioè 75 capi veri inseriti da Davide col Rapid Fire su DEV e schedati da Haiku e Jev.
  - Correzioni a mano documentate per 5 errori della scansione (vedi C3).
- **Passi:**
  1. Fixture dell'armadio, nella forma delle righe dell'armadio del generatore.
  2. Scelta del sub del posto con il matching del generatore; se nessun capo va bene, si torna a `capoDelGap`.
  3. Il generatore deve restare identico: `confronta_celle` sull'oracolo completo dà 888/888.
  4. Misura sui 838 viaggi mai visti, cioè l'oracolo completo meno i 50 del campione. Si confrontano base `3333ab2`, regola D `d92aa67` e armadio tipico.
  5. File markdown con 10 viaggi interi da far leggere a Davide.
- **Riferimenti:**
  - oracolo completo in `scratchpad/oracolo-completo/celle.json` (si rigenera con `python esporta_oracolo.py celle FILE` dal banco, offline);
  - script dell'holdout in `scratchpad/holdout/`.
  - Lo scratchpad è temporaneo: se manca, si rigenera.
- **Numeri finora (regola D, 838 viaggi):** accordo da 57,0% a 60,3%, con 466 migliorati e 226 peggiorati. I peggioramenti principali:
  - pantaloni → jeans (97);
  - giacca impermeabile → giacca a vento (32);
  - sneakers → scarponi (25);
  - pantaloni → pantaloncini (24);
  - felpa → felpa con cappuccio (17).
- **FATTO (3 nov sera), commit `eb0422d`, non pushato:**
  - accordo sugli 838 viaggi: 57,0% → 65,8% (1100 migliorati, 455 peggiorati);
  - generatore identico, 888/888;
  - 10 viaggi in `docs/superpowers/dati/dieci_viaggi_armadio_tipico.md`.
- **Scarpe trail:** restano tra gli scarponi da trekking (Hiking Boots), come nell'armadio. Davide il 3 nov: "nascono per la montagna, ma sono meno pesanti degli scarponi", quindi la lettura della scansione è corretta.
- **Errori aperti dell'armadio tipico, da sistemare prima del push:**
  1. **"Scarponi da trekking" in 335 viaggi su 888** (prima 128), anche a Marrakech a 39° con "escursioni leggere" e alle Maldive. Le scarpe trail (Hiking Boots, calore 2) vincono per qualsiasi escursione. Da capire se per le "escursioni leggere" al caldo debbano vincere sneakers o sandali: probabilmente serve guardare le activityTags e la fascia di calore nel matching per le scarpe. Va deciso con Davide.
  2. **Livigno:** "Scarponi da trekking invernali" invece dei doposci (Snow Boots), anche se nell'armadio i doposci ci sono. Va controllato perché il matching non li sceglie: per esempio, attività ski non mappata su Snow Boots, o il posto non chiede calore 5.
  3. **Nomi strani:** "Leggings caldi" (a Livigno dovrebbe essere calzamaglia termica o pantaloni da sci) e "Camicie calde". La tabella dei nomi qualifica capi che non andrebbero qualificati come "caldi" (`posti_nomi.ts`, `qualificabile`).
  4. **Regressioni principali:** piumino → cappotto (106), maglione → pile (80), stivali → sneakers (46), sneakers → scarponi (36), maglione → felpa con cappuccio (29), giacca a vento → giacca impermeabile (22), maglione → maglietta (19). Quelle di giacche e scarpe pesano meno, perché `unisciIlMeteo` le riunisce in "Giacca invernale" e "Scarpe invernali".
  5. **Copie:** +511 rispetto alla regola D (12.720 contro 12.209) sugli 838 viaggi. Causa non verificata: forse posti con nomi diversi che non si fondono più. Da controllare.
  6. **Correzioni a mano nella fixture** (`armadio_tipico.json`):
     - costume → Swimwear;
     - muta → Wetsuit. Formalità, attività, volume e copertura li ha inventati l'agente;
     - tuta da sci → Outerwear/Ski Suit;
     - pile leggero → Fleece;
     - calzini → calore 1.
- **Quando gli errori sono sistemati:**
  - mostrare a Davide la tabella e i 10 viaggi;
  - se va bene, pushare e dare il link della PR. Va unita dopo `fix/posti-armadio-vuoto`.
  - Deploy: solo `pack-trip`, prima DEV poi PROD.

### A2. Rapid Fire nella pagina della casa
- **Dove:** ramo `fix/rapid-fire-tastiera`, worktree `/srv/claude/workspaces/PackLog-rf`, da `develop`.
- **Tre difetti** (video di Davide del 3 nov, fotogrammi in `scratchpad/flicker/`):
  1. **Incolla:** tocco lungo → "Incolla" fa chiudere il campo e il testo non entra.
     - Causa probabile: il menu di selezione sta fuori dal `TapRegion` del campo in `lib/features/items/widgets/rapid_fire_input.dart`.
  2. **Flicker:** quando la tastiera si apre, campo e pillole restano sotto per qualche fotogramma e poi saltano su, con le pillole che si dissolvono di nuovo. In chiusura succede il contrario.
     - Il campo deve seguire `viewInsets` fotogramma per fotogramma, senza animazioni legate al focus.
  3. **Sovrapposizione:** con la tastiera aperta, l'ultimo oggetto di "Aggiunti ora" finisce sotto le pillole.
     - La lista deve riservare in fondo lo spazio della barra.
- **Pagina:** `lib/features/houses/view/house_detail_screen.dart` (`_AddPage`).
- **Quando finisce:** revisione, push, link della PR. Da provare sul telefono: incolla e tastiera.

---

## B. PR da aprire (Davide), base `develop`

Sono tutte pushate e revisionate. I testi sono in `scratchpad/ds-piani/pr-*.md`, già mandati in chat.

| Ramo | Cosa | Link | Note |
|---|---|---|---|
| `fix/meteo-valigia` | messaggi d'errore distinti (offline / server / crediti), log dell'archivio meteo con stato HTTP e motivo, test della riga meteo in ritardo | https://github.com/davidetarsi/PackLog/compare/develop...fix/meteo-valigia | deploy di `pack-trip` e `trip-weather` solo per il log più ricco |
| `fix/posti-armadio-vuoto` | copie unite col massimo nella stessa tappa (sopra, sotto, scarpe), muta mai importante, pantaloni lunghi da sera se tutte le tappe sono sopra 24° | https://github.com/davidetarsi/PackLog/compare/develop...fix/posti-armadio-vuoto | deploy di `pack-trip` |
| `feat/foglio-proposte` | foglio dal basso per riempire un posto (proposti, "Aggiungi le tue", "Presa"); via la variante B; chiusura automatica 200 ms dopo l'animazione | https://github.com/davidetarsi/PackLog/compare/develop...feat/foglio-proposte | provare sul telefono la tastiera su schermo piccolo e il volo della riga del kit |

**Già unite in develop il 3 nov:** #92, #95, #93, #94, #96, #97 (kit). Sui progetti DEV e PROD sono applicate la migrazione del catalogo e quella dei kit, e il deploy delle funzioni è fatto.

---

## C. Da fare dopo, in ordine, con il modo di lavorarci

### C1. Meteo giorno per giorno anche per le stime
- **Oggi:** la card del meteo apre la pagina giorno per giorno solo con le previsioni (fino a 16 giorni); per le stime dall'archivio no.
- **Come:**
  - In `supabase/functions/_shared/clima/meteo.ts`, percorso "normali climatiche", le 5 risposte annuali hanno già i dati di ogni giorno. Si aggiunge la media per giorno di calendario (tmax, tmin, pioggia, vento) e la si salva nella cache insieme al resto.
  - **Nessuna chiamata in più.** Le voci già in cache senza dettaglio si ricalcolano una volta.
  - Il calcolo usato dal generatore (`deriva`) **non cambia**: il dettaglio è un campo in più.
  - `trip-weather` lo restituisce per tappa. Nell'app, la card apre `/trips/:id/weather` anche per le stime, con l'etichetta "media degli ultimi 5 anni".
- **File app:** `lib/features/trips/view/widgets/pack/pack_weather.dart` (oggi `onTap` solo se `forecastDays` non è vuoto) e `trip_weather_screen.dart`.
- **Verifica:** i test del meteo (`node --test _shared/clima/test/*.test.ts`) e uno screenshot.

### C2. Regole dei viaggi caldi al mare nel generatore (lavoro sul banco)
- **Decise da Davide il 3 nov** (memoria `decisioni-prodotto-bench.md`):
  - viaggio caldo (sopra 24°) con mare o immersioni: mutande senza il "+1";
  - calzini: calcolo attuale (giorni + 1) meno il 30%, per esempio 10 → 7, **non** dimezzati;
  - pantaloni lunghi sopra 24°: se non sono leggeri (lino o segnati leggeri) sono capi da sera, quantità uguale o un po' minore dei capi della sera.
- **Dove:**
  - nel banco Python `/srv/claude/workspaces/AI-checklist-test-script`: essenziali in `essenzialiPerViaggio`, quantità dei pantaloni con `WEARS_BEFORE_WASH` e `caldoUnCapoAlGiorno`;
  - poi il porting in TS (`_shared/valigia/quantita.ts`, `costanti.ts` generato da `esporta_costanti.py`);
  - poi si rigenerano gli oracoli e il confronto deve risultare identico.
- **Controllo overfitting:** punteggio complessivo sul v4 sigillato, senza guardare le singole asserzioni.

### C3. Errori della scansione (visti nell'armadio tipico)
- **"Costume"** → Essentials/Other invece di Swimwear.
- **"Muta sub"** → Not Clothing invece di Wetsuit.
- **"Tuta sci"** → Full Body/Other invece di Ski Suit.
- **"Pile leggero"** → Outerwear/Casual Jacket invece di Fleece.
- **"Calzini"** → calore 3 invece di 1, mentre la scala dice calzini corti = 1.
- **Come:** sono nel prompt e nel tassonomia di `supabase/functions/_shared/capi/scheda.ts` (scala del calore, elenco dei tipi) e nella funzione `item-metadata`. Si fa un piccolo test con questi 5 nomi sull'oracolo della scheda, si corregge il prompt o i tipi attivi, e si rifà la prova sugli stessi nomi.

### C4. Piccole cose dei kit
- **La X della riga del kit in valigia non è a filo del bordo destro:** `lib/features/trips/view/widgets/slots/kit_suggestion_row.dart`, parametro `flushEnd` di `DsIconButton`.
- **Riallineare `catalogo.json` nel banco:** il catalogo dell'app ora ha il dominio `transport` e gli alias.

### C5. Verifica su DEV dei kit da due telefoni
Lo stesso oggetto messo nello stesso kit da due telefoni, poi sincronizzare: deve restare una riga sola. L'upsert su `(kit_id, item_id)` non è mai stato provato sul server vero.

### C6. Punti grandi
- **Blocco 4 di Leo:** gli oggetti della casa a griglia, con le icone. Va fatto prima un brainstorming con mockup.
- **Prova di fluidità:**
  - un test `integration_test` in modalità profile con `traceAction` sui flussi con animazioni (foglio dei posti, riga del kit, attesa);
  - lo lancia Davide sul telefono, e si confrontano prima e dopo.
  - Serve anche il test su dispositivo: il VPS non ha KVM. Strade: una sessione Claude Code sul computer di Davide, oppure un tunnel adb.
- **Profilo personale:**
  - abitudini fisse;
  - quanto piena la valigia;
  - scostamento per i freddolosi;
  - registro delle modifiche dell'utente, con il consenso.
  - Da progettare da zero (memoria `idea-profilo-personale.md`).
- **Dogana delle Serate:** la compila Davide, poi le risposte diventano asserzioni del banco (memoria `dogana-serate-artifact.md`).

---

## D. Come si lavora

- **Modo leggero:** un agente per gruppo di task, revisione con sonnet, nuova revisione con haiku solo sui punti Important, revisione finale con opus sui lavori grandi. Prompt corti, report brevi.
- **Regole d'ambiente degli agenti:** `scratchpad/ds-piani/ambiente.md`.
  - Flutter 3.38.5: `source /srv/claude/workspaces/.strumenti/flutter338.sh`.
  - Deno: `/srv/claude/workspaces/.strumenti/node_modules/deno/deno`.
  - ffmpeg (per i video): `/srv/claude/workspaces/.strumenti/ffmpeg/node_modules/ffmpeg-static/ffmpeg`.
- **Interfaccia:** solo design system, tema, `AppMotion`, `AppOpacity` e stringhe tradotte (it-IT ed en-US, c'è un test di parità). Widget piccoli a una responsabilità.
- **Git:** mai push forzati né cancellazione di rami remoti. Le PR le apre Davide dai link di confronto (non c'è `gh`), e unisce con merge normale.
- **Supabase:** DEV e PROD sono separati. Migrazioni e deploy prima su DEV, e li fa sempre Davide.
- **Limite settimanale:** quando un agente si ferma per il limite, la cartella resta com'è. Si riprende con `SendMessage` allo stesso agente, oppure con un agente nuovo che legge questo file.
