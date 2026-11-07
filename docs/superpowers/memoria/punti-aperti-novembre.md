---
name: punti-aperti-novembre
description: "Punti aperti dopo blocco 2 e Rapid Fire da un posto (2 nov 2026): spazi/kit, blocchi 3-4 di Leo, Dogana, misura fluidità, test su emulatore/telefono"
metadata:
  node_type: memory
  type: project
  originSessionId: a389a2f8-d273-43c6-b669-b6e7c79291e2
  modified: 2026-11-02T10:30:54.874Z
---

Dopo `feat/prima-valigia` e `feat/rapid-fire-posto` (2 novembre 2026) restano aperti:
- Spazi e kit logici [[punto-aperto-spazi-kit]].
- Blocco 3 di Leo: il "wow" dell'AI, cioè il ridisegno dell'attesa "Preparo la valigia" (fatto solo il bordo animato).
- Blocco 4 di Leo: oggetti a griglia con icone.
- Dogana delle Serate da compilare da Davide [[dogana-serate-artifact]].
- **Fluidità:** prova automatica di Flutter in modalità profile (`integration_test` + `traceAction`, tempi dei fotogrammi) sul flusso dei posti, lanciata da Davide su telefono vero; poi estenderla ad altri flussi.
- **Test su dispositivo:** il VPS non ha KVM, quindi niente emulatore. Opzioni: una sessione Claude Code sul computer di Davide (emulatore e telefono via USB), oppure un tunnel SSH inverso verso l'adb del suo computer. L'emulatore va bene per flussi e resa (blur, shader), non per i numeri assoluti di fluidità.

**Why:** Davide vuole un'app fluida e teme che le animazioni nuove la rallentino; vuole verificarla davvero.
**How to apply:** proporre questi punti quando si sceglie il prossimo lavoro; per la fluidità, confronti prima/dopo sullo stesso dispositivo.
