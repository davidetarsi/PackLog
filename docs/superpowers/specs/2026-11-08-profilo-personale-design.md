# Profilo personale e modifiche alla valigia — design

Data: 8 novembre 2026. Decisioni di Davide in chat, sessione del 7-8 novembre.

## Perché

Il generatore della valigia è stato tarato sul banco, e il banco è stato scritto da Davide: le regole "giuste" lo sono soprattutto per lui. Davide non ha mai dovuto correggere una valigia proposta. Il profilo serve a far sì che PackLog vada bene anche a persone diverse da lui, senza trasformarsi in un pannello di regolazioni.

Gli esempi di Davide si dividono in tre posti diversi:

1. **Differenze che cambiano le regole del generatore.** Chi soffre il freddo o il caldo; chi carica troppo (quest'ultimo si gestisce senza impostazioni, vedi sotto).
2. **Differenze che arrivano dall'armadio.** Jeans stretti o cargo, scarpe piatte o da corsa, giacca pesante o strati, cotone o merino. Il generatore sceglie fra i capi che l'utente ha: non servono impostazioni. Quando un capo adatto manca, ci pensa il generatore dei suggerimenti.
3. **Promemoria per chi dimentica le cose** (Leo). Sono i kit, non il profilo: lavoro a parte, vedi "Fuori da questo design".

## Obiettivi

- Rassicurare chi tende a portare troppo, senza cambiare la valigia proposta.
- Cominciare subito a raccogliere le modifiche che le persone fanno alla proposta, per capire le loro abitudini (per la singola persona) e dove il generatore sbaglia (per tutti).
- Definire per intero la scelta "freddo / caldo", da approvare quando Davide lo deciderà.

## Non obiettivi

- Nessuna impostazione "quanto piena la valigia" (essenziale / media / abbondante): il generatore propone la valigia dell'utente medio e basta.
- Nessun campo per sesso o stile nel profilo: resta la regola dell'armadio del 25 ottobre (gonna, vestito, cravatta fra i mancanti solo se l'armadio ne ha già uno; altrimenti l'alternativa). Se non bastasse, lo diranno i dati delle modifiche.
- Nessun uso delle modifiche nel generatore, per ora: prima si raccolgono e si guardano.

## Anti-obiettivi

- Un profilo che chiede molte cose al primo avvio.
- Raccogliere più del necessario: niente nomi dei capi scritti dall'utente, niente foto.
- Dati personali che restano dopo l'eliminazione dell'account.

## Parte 1 — La frase rassicurante

- **Testo it:** "Con questa valigia hai il necessario per questo viaggio. Se vuoi portare altro, aggiungilo dalla ricerca."
- **Testo en:** "This suitcase has what you need for this trip. If you want to bring more, add it from search."
- Forma impersonale, valida per tutti (richiesta di Davide).
- **Dove:** una riga piccola, grigia (`onSurfaceVariant`, `bodySmall` o `bodyMedium`), sotto il titolo della valigia AI e sopra le righe "Cosa manca / Perché queste scelte" (`AiPackRows` in `pack_suitcase_screen.dart`).
- **Quando:** sempre, finché il viaggio non è partito; solo per le valigie generate da PackLog.
- Solo app, niente server. Stringhe nuove in it-IT ed en-US.

## Parte 2 — La raccolta delle modifiche

### Cosa si registra

Solo le modifiche alla **proposta**, **prima della partenza** (decisione di Davide). Non si registra niente durante il viaggio, compreso lo spuntare "messo in valigia".

Un evento per azione, non lo stato finale (la differenza netta si calcola dopo, e così si vede anche "aggiunto e poi tolto"):

| azione | quando |
|---|---|
| `aggiunto` | l'utente aggiunge un oggetto alla valigia proposta (ricerca, Rapid Fire, kit a mano) |
| `tolto` | l'utente toglie un oggetto proposto o uno suo |
| `copie` | cambia le copie di un oggetto (prima → dopo) |
| `suggerimento_tolto` | toglie un suggerimento o un importante con la X ("non utile") |
| `posto_riempito` | riempie un posto con un capo suo |
| `da_comprare` | segna un posto "da comprare" |

### Cosa si salva di ogni evento

- id utente, id viaggio, id tappa se c'è, momento, azione, copie prima/dopo;
- **origine:** proposta di PackLog (capo dell'armadio scelto dal generatore, posto importante, suggerimento, kit aggiunto da solo) oppure aggiunta dell'utente;
- **scheda del capo:** categoria, sottocategoria, calore, impermeabilità, formalità, tag di attività (da `ai_metadata`); per i posti, il tipo del posto. **Mai il nome scritto dall'utente.**
- **contesto del viaggio:** giorni, temperature medie min/max della tappa, giorni di pioggia, attività, alloggio, lavatrice, mezzi;
- **versione del generatore** che ha fatto la proposta;
- **`analisi_consentita`:** il valore dell'interruttore "Statistiche d'uso" in quel momento.

### Consenso e privacy

- **Per la singola persona:** la raccolta è parte del servizio ("PackLog impara dalle tue modifiche per farti valigie migliori"). È sempre attiva, va dichiarata nella privacy policy e nella scheda "Sicurezza dei dati" del Play Store (attività nell'app, raccolta, collegata all'utente, non condivisa), e si cancella con l'account.
- **Per l'analisi di tutti insieme:** solo le righe con `analisi_consentita = true`, lette senza id utente.
- Il codice utente è uno pseudonimo, non un dato anonimo: le righe sono dati personali.

### Dove

- Tabella Supabase nuova (nome a scelta del costruttore, per esempio `valigia_modifiche`), con RLS: ogni utente inserisce e legge solo le proprie righe; nessun aggiornamento né cancellazione dall'app. Davide legge dalla dashboard.
- **Migrazione:** la applica Davide, prima su DEV.
- **`hard-delete-account`:** aggiungere la tabella all'elenco delle tabelle cancellate per `user_id`.
- **App:** l'app funziona anche offline. Gli eventi si salvano nel database locale e si mandano con la sincronizzazione esistente, come i kit. *(Scelta mia: un invio diretto perderebbe gli eventi fatti senza rete.)*

### Verifica

- Test unitari: ogni azione della tabella produce un evento con origine e scheda giuste; nessun evento dopo la partenza; nessun nome scritto dall'utente nel payload.
- Test di sincronizzazione: gli eventi offline arrivano dopo il ritorno della rete, senza doppioni.
- Test di `hard-delete-account`: le righe spariscono.

### Scelte mie dopo la lettura del revisore (da controllare)

- **Origine dell'oggetto:** si ricava al momento dell'evento confrontando l'oggetto con la proposta salvata nel viaggio (`aiResult`: capi scelti, posti, kit aggiunti). Niente colonna nuova sulle righe degli oggetti.
- **Versione del generatore:** `pack-trip` aggiunge alla risposta una costante di versione, salvata con la proposta. Arriva con il prossimo deploy di `pack-trip`; fino ad allora il campo è vuoto.
- **Partenza:** la data e ora di partenza del viaggio (`departureDateTime`), nell'ora del telefono. Dopo quel momento non si registra niente.
- **Solo valigie generate da PackLog:** senza una proposta non c'è niente da confrontare, quindi nei viaggi fatti a mano non si registra.
- **Interruttore delle statistiche:** `analisi_consentita` prende il valore del momento e non si aggiorna dopo. La privacy policy e il testo sotto l'interruttore vanno aggiornati per dire che vale anche per l'analisi delle modifiche (testi da far approvare a Davide).
- **Eliminazione dell'account:** la coda locale degli eventi si svuota insieme agli altri dati locali (`wipeAllUserData`), così niente arriva dopo la cancellazione sul server.

## Parte 3 — Freddo e caldo (definita, da approvare)

Davide deciderà se farla subito o dopo aver visto i dati delle modifiche.

- **Dove:** profilo, sezione nuova "La tua valigia", con tre voci: Soffro il freddo / Nella media / Soffro il caldo. Di base "Nella media".
- **Cosa fa:** il generatore tratta le temperature del viaggio come più basse di N gradi per chi soffre il freddo, più alte di N per chi soffre il caldo. Un solo spostamento applicato a tutte le soglie (capi estivi, maniche lunghe, pile, un capo leggero al giorno sopra i 24°), **compresi gli importanti del freddo vero** (giacca per fasce di minima, cappello caldo e sciarpa a ≤5°): decisione di Davide.
- **N:** da misurare sul banco; ipotesi 3°.
- **Ordine di lavoro:** banco (parametro nuovo, "Nella media" = 888/888 identici, campione di valigie con freddo e caldo da guardare con Davide) → porting TS → campo sull'utente in Supabase (migrazione, Davide) → l'app lo manda a `pack-trip` → deploy di `pack-trip` (Davide).
- La sezione "About" del profilo oggi è in inglese anche in italiano: da tradurre insieme a questo lavoro (o prima, come correzione piccola).

## Fuori da questo design

- **Kit più chiari** per chi dimentica le cose: prima si guarda come appaiono oggi in app, poi un design a parte.
- **Usare le modifiche nel generatore:** dopo aver raccolto e guardato i dati.

## Ordine proposto

1. Parte 1, la frase (piccola, solo app).
2. Parte 2, la raccolta delle modifiche (migrazione, app, `hard-delete-account`, testi della privacy).
3. Parte 3, quando Davide la approva.

## Lasciato al costruttore

- Nome della tabella e delle colonne, forma esatta del payload.
- Dove agganciare gli eventi nel codice della valigia (azioni esistenti in `slot_actions.dart` / `slot_edits.dart`, aggiunta e rimozione degli oggetti del viaggio).
- Stile esatto della riga rassicurante, purché con componenti e token del design system.
