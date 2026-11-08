---
name: analytics-domande
description: "Domande a cui analytics (Amplitude + Telegram Analytics) e Sentry devono rispondere, approvate da Davide l'8 nov 2026; documento completo nel repo"
metadata:
  node_type: memory
  type: project
  originSessionId: f3f7d31d-c11d-4ff7-9f5e-9216c06b0c19
  modified: 2026-11-08T10:25:54.023Z
---

8 nov 2026: rifacimento dei log analytics/Sentry dopo valigia AI e redesign. Documento completo con stato dei log, 19 domande e quelle scartate: `docs/superpowers/analytics-domande.md` nel repo PackLog, ramo locale `feat/analytics-domande` (NON pushare finché non c'è il codice, decisione di Davide) (worktree `/srv/claude/workspaces/PackLog-logs`, da origin/develop #108).

Approvate da Davide (tutte le "tenere"). Nucleo: 1 arrivano alla prima valigia, 4 si fidano della valigia (modifiche rispetto alla proposta), 5 fallimenti e durata della generazione, 9 qualità dello scan (scartati, rinominati, collegati), 12 crediti finiti (429), 17 errori silenziosi in Sentry + SentryNavigatorObserver. Più: tempo alla prima valigia, capi nell'armadio alla generazione, avvisi "cosa manca", uso in partenza, scan vs manuale, secondo viaggio (numero d'ordine), sync. **Codici promo da tenere SUBITO: decisione di Davide, "se lo rimandiamo me lo scordo".**

Scartate: utenti attivi al giorno/settimana (app di viaggi, si torna a ogni viaggio), schermate più viste, destinazioni (eventualmente solo tipo di viaggio di Jev), costo AI lato app (sta sul server), capi senza metadati come evento (query DB).

**Why:** con 2 utenti le percentuali non dicono niente; servono allarmi sugli errori, storia per utente, e il percorso principale già strumentato per il lancio.
**Catalogo eventi approvato (8 nov, seconda parte):** nel doc, sezione "Catalogo degli eventi". Nuovi: ai_suitcase_finished (esito, durata, armadio, contesto viaggio), ai_suitcase_changed (dal TripNotifier: tolti/aggiunti/quantità per sottocategoria), ai_warning_dismissed, ai_slot_removed, ai_item_reason_opened, ai_scan_doubt_resolved (Jev vs GPT), ai_limit_reached, promo_code_redeemed. Contesto viaggio su entrambi gli eventi valigia (idea di Davide): attività, alloggi, lavatrice, bagaglio, mezzi, fasce di temperatura (soglia 21 = scelta dubbia), giorni di pioggia; mai la destinazione. Davide: spostare SUBITO tutti i ~30 logEvent diretti nel livello tipato; raccogliere tutto ora, al massimo poi si spegne. Avvisi Telegram: Davide li imposta a mano nel pannello tgram, oggi solo su login_completed.
**How to apply:** prossimo passo è il piano di implementazione dal catalogo; ogni evento nuovo passa da CoreAnalyticsService, mai dati personali o testo dell'utente. Vedi [[produzione-generatore]], [[idea-ui-aggiunta-capi]].
