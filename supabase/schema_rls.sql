-- ─────────────────────────────────────────────────────────────────────────────
-- Row Level Security policies — Stuff Tracker 2 / PackLog
--
-- Versiona lo stato di RLS per le 5 tabelle dati (houses, items, spaces,
-- luggages, trips) più la tabella users e app_config.
--
-- Stato di partenza (verificato su prod via pg_class + pg_policies):
--   - RLS abilitata su tutte e 7 le tabelle public
--   - 5 tabelle dati: policy ALL "Accesso totale ai propri dati per X"
--     con qual = (auth.uid() = user_id) e roles = {public}
--   - users: policy SELECT "users_select_own" con qual = (auth.uid() = id)
--   - app_config: policy SELECT per authenticated con qual = true
--
-- Modifiche apportate da questo file:
--   - Sostituisce roles `public` → `authenticated` su tutte le policy delle
--     5 tabelle dati. Hardening difensivo: oggi `auth.uid() = user_id`
--     filtra comunque gli anon (auth.uid() è NULL senza JWT) ma dichiarare
--     esplicitamente `TO authenticated` rende l'intento chiaro e resta
--     sicuro anche se domani Supabase cambia il comportamento di auth.uid().
--   - Nomi delle policy mantenuti uguali ("Accesso totale ai propri dati
--     per X") per non rompere riferimenti/log esistenti.
--   - Sanity check finale: verifica che RLS sia attiva e che esistano
--     esattamente 5 policy ALL sulle 5 tabelle dati.
--
-- Tabelle senza policy ALL: SCELTA INTENZIONALE
--   - `users` ha solo policy SELECT perché INSERT/UPDATE sono fatte solo
--     dalle funzioni SECURITY DEFINER `handle_new_user`,
--     `increment_gpt_usage`, `decrement_gpt_usage`. DELETE è gestita via
--     `ON DELETE CASCADE` da `auth.users`. Nessun path client può scrivere.
--   - `app_config` espone configurazione globale (es. tombstone_retention_days)
--     a tutti gli autenticati; nessun client deve poter scrivere.
--
-- Tabelle assenti: `trip_item_entries` e `trip_luggage_entries` esistono solo
-- localmente. Il sync li serializza dentro il payload JSONB del trip parent
-- (`items: [...]`, `luggage_ids: [...]`), quindi non ci sono tabelle remote
-- dedicate da proteggere — la RLS del trip parent copre tutto.
--
-- Esecuzione:
--   psql $SUPABASE_DB_URL -f supabase/schema_rls.sql
-- oppure incolla nel SQL Editor del Dashboard Supabase.
--
-- Idempotente: ri-eseguibile senza effetti collaterali.
-- ─────────────────────────────────────────────────────────────────────────────

BEGIN;

-- Sicurezza: RLS resta attiva (idempotente — già attiva su tutte e 5 le tabelle).
ALTER TABLE public.houses   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.items    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spaces   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.luggages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips    ENABLE ROW LEVEL SECURITY;

-- ── HOUSES ────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Accesso totale ai propri dati per Houses" ON public.houses;
CREATE POLICY "Accesso totale ai propri dati per Houses"
  ON public.houses
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING      (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ── ITEMS ─────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Accesso totale ai propri dati per Items" ON public.items;
CREATE POLICY "Accesso totale ai propri dati per Items"
  ON public.items
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING      (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ── SPACES ────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Accesso totale ai propri dati per Spaces" ON public.spaces;
CREATE POLICY "Accesso totale ai propri dati per Spaces"
  ON public.spaces
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING      (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ── LUGGAGES ──────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Accesso totale ai propri dati per Luggages" ON public.luggages;
CREATE POLICY "Accesso totale ai propri dati per Luggages"
  ON public.luggages
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING      (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ── TRIPS ─────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Accesso totale ai propri dati per Trips" ON public.trips;
CREATE POLICY "Accesso totale ai propri dati per Trips"
  ON public.trips
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING      (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- SANITY CHECK
-- Solleva un'eccezione che annulla la transazione se lo stato finale non
-- corrisponde alle 5 policy attese (una per ognuna delle 5 tabelle dati,
-- tutte ALL, tutte TO authenticated, tutte qual = with_check).
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_policy_count integer;
  v_rls_off_count integer;
  v_wrong_role_count integer;
BEGIN
  -- 1) Esattamente 5 policy ALL sulle 5 tabelle dati
  SELECT count(*) INTO v_policy_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename  IN ('houses', 'items', 'spaces', 'luggages', 'trips')
    AND cmd        = 'ALL';

  IF v_policy_count <> 5 THEN
    RAISE EXCEPTION
      'RLS sanity check FAILED: expected 5 ALL policies on data tables, found %',
      v_policy_count;
  END IF;

  -- 2) RLS attiva su tutte e 5 le tabelle
  SELECT count(*) INTO v_rls_off_count
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('houses', 'items', 'spaces', 'luggages', 'trips')
    AND c.relrowsecurity = false;

  IF v_rls_off_count > 0 THEN
    RAISE EXCEPTION
      'RLS sanity check FAILED: % data tables still have RLS disabled',
      v_rls_off_count;
  END IF;

  -- 3) Tutte le policy nuove devono essere TO authenticated, non public
  SELECT count(*) INTO v_wrong_role_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename  IN ('houses', 'items', 'spaces', 'luggages', 'trips')
    AND cmd        = 'ALL'
    AND NOT (roles = '{authenticated}');

  IF v_wrong_role_count > 0 THEN
    RAISE EXCEPTION
      'RLS sanity check FAILED: % data-table ALL policies are not TO authenticated',
      v_wrong_role_count;
  END IF;

  RAISE NOTICE 'RLS sanity check OK: 5 policies, RLS attiva, TO authenticated';
END $$;

COMMIT;

-- ─────────────────────────────────────────────────────────────────────────────
-- Riferimento manuale (esegui dopo la migration per ispezione visiva):
--
-- SELECT relname, relrowsecurity
-- FROM   pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
-- WHERE  n.nspname = 'public' AND c.relkind = 'r'
-- ORDER  BY relname;
--
-- SELECT tablename, policyname, roles, cmd, qual, with_check
-- FROM   pg_policies
-- WHERE  schemaname = 'public'
-- ORDER  BY tablename, cmd;
-- ─────────────────────────────────────────────────────────────────────────────
