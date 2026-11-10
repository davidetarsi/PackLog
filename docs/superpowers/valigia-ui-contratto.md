# Valigia: contratto UI e verifiche

> **SUPERATO IL 6 NOVEMBRE 2026.** Le sezioni sottostanti documentano il primo tentativo locale, precedente allo stop di Davide. Non usarle come specifica corrente: includono decisioni successivamente rifiutate, in particolare il selettore Rivedi/Checklist e il titolo ripetuto Dal tuo inventario. Il riferimento aggiornato è `docs/superpowers/plans/2026-11-06-valigia-pagine-e-foglio.md`, sezione Design concordato. Conservare le evidenze tecniche di scroll e salvataggi, non le vecchie scelte visive.

Aggiornato il 6 novembre 2026. Fonte: decisioni di Davide in questa conversazione e verifica del codice. Leggere questo documento prima di modificare il dettaglio viaggio e le card della valigia.

## Vincoli confermati

- Riutilizzare StickyCtaScaffold, ProposedSlotsCard, ProposedSlotRow, ItemsCard e i componenti del design system. Colori, spaziature, icone e dimensioni dai token esistenti.
- Una riga modificabile conserva un segnale di apertura anche quando compare la X. La X non sostituisce la freccia e non apre la modifica.
- I suggerimenti spiegano sia il rapporto con l'inventario (capi adatti o copie mancanti), sia che toccare una riga permette di modificarla.
- Il gruppo degli oggetti presi dall'inventario deve essere riconoscibile: intestazione Dal tuo inventario e trattamento neutro, distinto dal gradiente PackLog.
- Togliere dalla valigia non cancella l'oggetto dall'inventario. Gli oggetti nei viaggi sono snapshot: nessuna mutazione implicita dell'oggetto sorgente.
- Ogni ultima riga deve poter scorrere completamente sopra la CTA fissa, anche a320x640 e con testo ingrandito.
- Conservare i messaggi completi degli importanti e il recupero del bottom sheet gia integrato. Non ripristinare la vecchia riga espansa.
- Non modificare in questo lavoro prompt, generatore, cataloghi, metadati o quantita.

## Problemi accertati

- ProposedSlotRow mostra X oppure freccia: l'aggiunta della rimozione ha eliminato il segnale di apertura.
- Il nuovo testo della card spiega l'inventario ma ha perso l'invito a toccare la riga.
- ItemsCard non ha un'intestazione che chiarisca la provenienza degli oggetti.
- TripDetail leggeva ctaReservedHeight sopra StickyCtaScaffold: il valore era zero. Due test a320x640 e390x844 riproducono la copertura dell ultima riga; Builder sotto lo scope la risolve. Una terza prova con testo160% copre anche gli overflow delle etichette.

## Checkbox: scelta confermata il 6 novembre

Davide ha scelto di mantenere le checkbox solo nella checklist finale. La stessa schermata distingue esplicitamente Rivedi valigia e Checklist, con AppPillTab esistente. Non si cambia automaticamente modalita quando scompare l'ultimo importante.

- Revisione: scintilla, freccia e X sulle proposte; X sugli oggetti dell'inventario, senza checkbox. La rimozione riguarda soltanto il viaggio ed e annullabile.
- Checklist: checkbox per segnare gia messo fisicamente in valigia, senza X di rimozione sulle righe. I suggerimenti restano apribili dal corpo e dalla freccia.
- Il passaggio fra modalita non cambia TripItem.isChecked, AiSlot.checked, quantita o inventario. Nessun nuovo dato persistito per lo stato di vista.
- I viaggi senza risultato AI mantengono il comportamento preesistente; non si cambia la preparazione manuale.

## Salvataggi della stessa pagina

Rimozioni, Annulla, modifiche dei posti, riempimento, spunte e azioni sui kit condividono runSuitcaseMutation della schermata. L operazione legge il viaggio corrente quando acquisisce il turno di salvataggio: non riutilizzare snapshot calcolati prima di un altro salvataggio. Anche i comandi Salvati, Duplica ed Elimina attendono il turno. Non spostare questa logica in un secondo provider della stessa entita.

Tre test con Future controllate riproducono e proteggono Annulla seguito da una nuova X, X di un oggetto insieme a X di una proposta, e rimozione seguita dall aggiunta di un kit. Il piano del kit va ricalcolato sui dati correnti prima di applicarlo, usando il planner esistente. L undo ripristina il solo elemento rimosso su dati correnti, mantenendo ordine, quantita e spunta. Rimozione e ripristino aggiornano updatedAt per la sincronizzazione LWW.

## Punti rinviati da preservare

- Revisione UX del contenuto del bottom sheet di modifica delle proposte: Davide lo vuole controllare dopo.
- Qualita PR107: una assertion storica Annapurna peggiora; v2/v3m/holdout30 non hanno ancora uno scoring equivalente verificato. Nessuna certificazione generale di non regressione.
- Collaudi device Rapid Fire, flusso proposte e sincronizzazione kit da due telefoni restano distinti dai test widget.
- Scansione foto: sperimentazione su capi distesi/piegati e istruzioni da allineare; nessuna promessa di scansione completa di un armadio.

## Verifiche prima di chiudere

1. Riga suggerita: corpo cliccabile, freccia visibile e X separata; nessun tap incrociato.
2. Testo esplicito di modifica, in IT e EN.
3. Provenienza inventario visibile nel gruppo, senza alterare dati o quantita.
4. Ultima riga interamente sopra la CTA a fine scroll e ancora cliccabile; CTA ferma durante lo scroll.
5. Verificare lo stato con importanti aperti e senza importanti, con e senza AI, e con testo grande.
6. Togliere un elemento riguarda solo il viaggio; recupero con Annulla se aggiunto al comportamento.
7. Nessuna nuova struttura visiva parallela per risolvere il problema; ogni scelta ancora in sospeso resta scritta qui.
