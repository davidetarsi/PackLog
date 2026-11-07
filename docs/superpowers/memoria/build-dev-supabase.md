---
name: build-dev-supabase
description: "Dal 3 nov 2026 app dev -> Supabase DEV, app prod -> Supabase PROD (prima erano lo stesso progetto): migrazioni e deploy prima su DEV, poi su PROD"
metadata:
  type: reference
---

La build dev (`.github/workflows/build_dev.yml`, su push a develop) usa `lib/main_dev.dart`, flavor dev, e passa a Flutter `--dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }}` e `SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}`. La build prod (`release_prod.yml`, su main) legge gli stessi due segreti di repository, senza `environment:` e senza `vars.`. Quindi non c'e' nel repo un progetto Supabase dev separato: l'APK dev parla con quello che puntano i due segreti, lo stesso di prod, a meno che qualcuno non li abbia impostati diversamente a mano (il repo non lo mostra e non si legge il valore dei segreti).

Differenze che restano: applicationId `.dev` (installazione affiancata), Sentry con environment dev, analytics tgram solo in prod.

**Why:** emerso il 21 ott 2026 chiedendo quale ambiente aggancia la build dev. Conseguenza: i dati di prova della build dev finiscono nel database di produzione, e una migrazione applicata al progetto vale per entrambe.
**How to apply:** se Davide chiede di separare dev e prod, proporre un progetto Supabase dev e segreti dedicati (environment `dev` in GitHub con i propri SUPABASE_URL e SUPABASE_ANON_KEY). Verificare con Davide quale URL c'e' nei segreti, senza chiedergli le chiavi.

**Aggiornamento 3 nov 2026 (Davide):** ora l'app dev è collegata a un progetto Supabase DEV separato, e l'app prod a Supabase PROD. Migrazioni e deploy vanno fatti prima su DEV (per provare la build dev), poi su PROD al rilascio.
