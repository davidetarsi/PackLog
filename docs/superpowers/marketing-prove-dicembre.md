# Marketing: prove di dicembre 2026

Brainstorming con Davide del 9-11 novembre 2026. Niente di questo è implementato nell'app.

## Decisioni

- **Lingua:** contenuti in inglese (non esclude gli italiani). Solo Android: niente App Store per ora.
- **Risorse:** zero budget; 5-10 ore a settimana, fino a 15-20 se serve.
- **Scopo:** 20-50 persone che fanno una valigia per un viaggio vero. È una beta: contano le conversazioni più dei numeri.
- **Misure:** attivazione = valigia AI nella prima sessione; ritorno = seconda valigia entro 60 giorni; giorni tra installazione e partenza.
- **Nessuno scopo commerciale per ora:** i crediti gratis hanno solo un tetto. Open-Meteo gratuito va bene finché non si vende niente.

## Una prova sola

| | |
|---|---|
| A chi | chi ha un viaggio non abituale entro 1-2 settimane, con Android (Europa e internazionale) |
| Frase | "Tell it where and when you're going. Get a packing list made for that weather and those plans." |
| Dove | reclutamento a mano + un solo formato di contenuto (video breve o pagine "packing list for [meta] in [mese]") |
| Momento | viaggi di Natale e Capodanno: da inizio a metà dicembre |

La prova "tra due case" (fuorisede, coppie a distanza, studenti all'estero) è parcheggiata finché il generatore non considera la casa di arrivo.

## Da fare prima di partire

- [ ] **Davide:** scheda del Play Store in inglese, con scritto "Android beta"; rifare le slide prima del login (scaletta già pronta).
- [ ] **Davide:** modulo pubblico da una domanda "Notify me for iPhone", linkato da contenuti e scheda. La riga nel questionario in app la vedono solo utenti Android.
- [ ] **Davide:** controllare sulla dashboard di Amplitude che gli eventi arrivino dalla versione rilasciata (dal codice non si vede se la chiave di produzione è impostata).
- [ ] Testi della privacy (foto e AI).
- [ ] Decidere il formato del contenuto e scrivere i primi pezzi.

## Controlli fatti l'11 novembre

**Uso misto (app in inglese, capi scritti in italiano):** va bene.
- Aggiunta per nome: 12 nomi italiani provati su DEV in tutte e due le lingue; 10 identici. "golf verde" in inglese diventa una polo (con il "?" sul tipo); "smoking" in inglese non viene riconosciuto come capo.
- Valigia: la lingua cambia solo i testi (motivi, perché, avvisi, nomi dei posti), non la scelta dei capi. Verificato nel codice, non con una valigia dal vivo.
- Non provata dal vivo: una valigia intera in inglese con capi dai nomi inglesi.

**Misure dall'analytics:** si leggono tutte con gli eventi che ci sono.
- Attivazione: `first_suitcase_generated` (una volta per dispositivo, con `from_first_run`) nella prima sessione.
- Ritorno: `trip_created` con `trip_number` = 2, oppure `ai_suitcase_finished` con esito `ok` su un secondo `trip_id`. Il "Rigenera" usa lo stesso `trip_id`: non va contato come ritorno.
- Giorni alla partenza: `days_to_departure` su `trip_created` con `is_first_trip`.
- Limiti: conta solo chi ha accettato la privacy e non ha spento l'analytics dal profilo; la valigia fatta a mano non entra nell'attivazione.

## Modifiche al prodotto segnate (non ora)

- Generatore: considerare l'armadio della casa di arrivo ("Ce l'hai già a [casa]", visibile e annullabile). Oggi `pack-trip` riceve solo la casa di partenza.
- Onboarding: domanda "Hai già un viaggio in programma?".
- Più avanti: valigia per più persone, pesi per l'attrezzatura, notifica al rientro.
