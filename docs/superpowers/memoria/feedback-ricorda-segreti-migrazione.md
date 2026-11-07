---
name: feedback-ricorda-segreti-migrazione
description: "Ripetere SEMPRE a Davide, a fine lavoro sulle Edge Functions, che deve impostare i segreti e applicare la migrazione"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 4d2d5da0-8b74-44a7-8ed5-d60b1d862ad3
  modified: 2026-10-20T15:24:34.128Z
---

Davide (20 ott 2026): "Ricordati sempre di ripetermi che devo fare i segreti e la migrazione dell'edge function."

Da fare da parte sua, finche' non dice che e' fatto:
- `supabase secrets set TYPESAFE_API_KEY=...` (Jev; senza, valigie e schede senza Jev) e `OPEN_METEO_API_KEY` (piano commerciale Open-Meteo, da scegliere). OPENAI_KEY c'e' gia'.
- applicare la migrazione `supabase/migrations/20261020090000_generatore_valigie.sql` (weather_cache, item_jev_profiles, usage_counters + increment_usage): serve a pack-trip, trip-weather e item-metadata.
- facoltativo: riga `item_name_daily_cap` in public.app_config (senza, item-metadata usa 200).

**Why:** sono azioni sue (credenziali e progetto Supabase) che Claude non puo' fare, e senza le funzioni non vanno in produzione.
**How to apply:** chiudere ogni risposta che tocca le Edge Functions, le PR o il rilascio con questo promemoria, breve. Vedi [[produzione-generatore]].
