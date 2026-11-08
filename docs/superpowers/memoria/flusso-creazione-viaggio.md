---
name: flusso-creazione-viaggio
description: Decisioni di Davide dell'8 nov sul flusso di creazione del viaggio (P1 AI senza salvare, P2 due bottoni); P3-P4 aperti
metadata:
  type: project
---
Flusso di creazione del viaggio, decisioni dell'8 novembre 2026 (artifact screenshot https://claude.ai/artifact/EH3YMTDSAsJVtX64JZQmKa).

- P1: "Prepara la valigia con AI" apre il foglio sopra il passo 1 senza salvare niente. Viaggio e valigia si salvano insieme solo quando arriva il risultato. Errore: niente salvato, credito non scalato. Niente "Annulla" nell'attesa; uscire = continua in background con avviso "Valigia pronta · Apri". Testo dell'attesa scelto da Davide: "Resta qui mentre prepariamo la valigia: non chiudere PackLog e non aprire altre app."
- P2: due bottoni soli nel passo 1: "Prepara la valigia con AI" (arancione) e "Scegli tu cosa portare" (contorno, salva e apre la pagina a mano). Niente "più tardi": creare il viaggio e iniziare la lista sono lo stesso momento (come fa Davide su Google Keep). Davide non vuole "Prepara a mano" come parola, né tre bottoni.
- P3: il dettaglio è la valigia (AI e a mano uguali, "Aggiungi oggetti"); la pagina valigia serve solo ad aggiungere.
- P4: Rigenera e avviso "Hai cambiato il viaggio" aprono il foglio sopra il dettaglio; date intere in Modifica.
- Riusa (solo dalla cartolina dei passati) = passo 1 precompilato, niente salvato; AI sostituisce gli oggetti copiati.
- Unificare i componenti doppi (fascia bottoni, righe/liste oggetti, bagagli).
- Design: docs/superpowers/specs/2026-11-08-flusso-viaggio-design.md (ramo WIP), revisionato; prossimo passo il piano. Prova usa e getta: ramo locale spike/flusso-viaggio (non unire).

**Why:** il flusso deve essere pulito, senza stati a metà né pagine che si confondono.
**How to apply:** usare questi testi e questa struttura nel design del nuovo flusso; vedi [[design-valigia-ai]], [[profilo-modifiche-valigia]].
