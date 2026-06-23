-- ─────────────────────────────────────────────────────────────────────────────
-- Geocode usage tracking — Stuff Tracker 2 / PackLog
--
-- Tabella + RPC per rate-limit per-utente delle chiamate al proxy Geoapify
-- (`supabase/functions/geocode-proxy`). Stesso pattern usato per GPT:
-- atomico via single UPDATE con WHERE che combina reset finestra + cap check.
--
-- Cap default: 100 richieste / 60 minuti per utente.
-- L'utente non può modificare o resettare il proprio contatore: tutte le
-- mutazioni passano dalle funzioni SECURITY DEFINER. Policy RLS espone
-- solo lettura del proprio counter (utile per debug/UI).
--
-- Esecuzione:
--   psql $SUPABASE_DB_URL -f supabase/schema_geocode_usage.sql
-- oppure incolla nel SQL Editor del Dashboard Supabase.
--
-- Idempotente: ri-eseguibile senza effetti collaterali.
-- ─────────────────────────────────────────────────────────────────────────────

BEGIN;

-- ── 1. Tabella ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.geocode_usage (
  user_id           uuid        PRIMARY KEY
                                REFERENCES auth.users(id) ON DELETE CASCADE,
  request_count     integer     NOT NULL DEFAULT 0,
  window_started_at timestamptz NOT NULL DEFAULT now()
);

-- ── 2. RLS: solo SELECT del proprio counter ─────────────────────────────────
ALTER TABLE public.geocode_usage ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "geocode_usage_select_own" ON public.geocode_usage;
CREATE POLICY "geocode_usage_select_own"
  ON public.geocode_usage
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Nessuna policy INSERT/UPDATE/DELETE: il client NON deve poter scrivere
-- direttamente. Tutte le mutazioni passano per `increment_geocode_count`
-- (SECURITY DEFINER) che bypassa RLS in modo controllato.

-- ── 3. RPC atomic: increment + reset finestra + cap check ──────────────────
-- Restituisce `true` se la richiesta è ammessa (e ha incrementato il
-- contatore), `false` se il cap nella finestra corrente è già raggiunto.
--
-- Pattern: INSERT ... ON CONFLICT DO UPDATE con WHERE clause condizionale.
-- Se la WHERE non matcha (cap raggiunto e finestra non scaduta) l'UPDATE
-- non avviene e `RETURNING` ritorna NULL → NOT FOUND → return false.
-- Tutto atomico, niente TOCTOU window.
CREATE OR REPLACE FUNCTION public.increment_geocode_count(
  p_user_id         uuid,
  p_now             timestamptz,
  p_cap             integer DEFAULT 100,
  p_window_minutes  integer DEFAULT 60
)
RETURNS boolean AS $$
DECLARE
  v_new_count integer;
BEGIN
  INSERT INTO public.geocode_usage (user_id, request_count, window_started_at)
  VALUES (p_user_id, 1, p_now)
  ON CONFLICT (user_id) DO UPDATE
  SET
    request_count = CASE
      WHEN public.geocode_usage.window_started_at
           < p_now - make_interval(mins => p_window_minutes)
        THEN 1
      ELSE public.geocode_usage.request_count + 1
    END,
    window_started_at = CASE
      WHEN public.geocode_usage.window_started_at
           < p_now - make_interval(mins => p_window_minutes)
        THEN p_now
      ELSE public.geocode_usage.window_started_at
    END
  WHERE
    -- Finestra scaduta: reset incondizionato consentito
    public.geocode_usage.window_started_at
      < p_now - make_interval(mins => p_window_minutes)
    -- Stessa finestra: incremento solo se sotto il cap
    OR public.geocode_usage.request_count < p_cap
  RETURNING request_count INTO v_new_count;

  IF NOT FOUND THEN
    -- ON CONFLICT DO UPDATE non ha matchato la WHERE → cap raggiunto
    RETURN false;
  END IF;

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─────────────────────────────────────────────────────────────────────────────
-- SANITY CHECK
-- Verifica che la tabella esista con la PK attesa, RLS sia attiva con la
-- sola policy SELECT-own, e la funzione esista. Solleva eccezione (→ rollback)
-- se qualcosa non corrisponde.
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_table_exists       boolean;
  v_rls_enabled        boolean;
  v_policy_count       integer;
  v_function_exists    boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'geocode_usage'
  ) INTO v_table_exists;

  IF NOT v_table_exists THEN
    RAISE EXCEPTION 'geocode_usage table does not exist after migration';
  END IF;

  SELECT c.relrowsecurity INTO v_rls_enabled
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relname = 'geocode_usage';

  IF NOT v_rls_enabled THEN
    RAISE EXCEPTION 'RLS is not enabled on geocode_usage';
  END IF;

  SELECT count(*) INTO v_policy_count
  FROM pg_policies
  WHERE schemaname = 'public' AND tablename = 'geocode_usage';

  IF v_policy_count <> 1 THEN
    RAISE EXCEPTION
      'geocode_usage must have exactly 1 policy (SELECT own), found %',
      v_policy_count;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'increment_geocode_count'
  ) INTO v_function_exists;

  IF NOT v_function_exists THEN
    RAISE EXCEPTION 'increment_geocode_count function does not exist';
  END IF;

  RAISE NOTICE 'Geocode usage sanity check OK';
END $$;

COMMIT;
