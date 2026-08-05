-- Migration: geocode usage → public.users (2026-07-30)
-- Da eseguire nel Supabase Dashboard → SQL Editor (progetto aluzxhcflmophawoffad)
--
-- Sposta il rate-limit del geocode-proxy dalla tabella dedicata
-- public.geocode_usage a due colonne su public.users (stesso mirroring
-- pattern di gpt_usage_count/cap). Finestra scorrevole mantenuta, ma
-- estesa da 60 minuti a 24 ore (in linea con le doc Geoapify — il free
-- tier resetta a credito giornaliero, non orario) e cap default alzato
-- da 100 a 200 richieste/giorno.
--
-- Companion: supabase/functions/geocode-proxy/index.ts aggiornato per
-- passare esplicitamente p_cap/p_window_minutes invece di affidarsi ai
-- default della funzione SQL.

BEGIN;

-- 1. Nuove colonne su public.users (stesso ON CONFLICT / trigger già
--    esistenti per la riga utente: nessuna modifica a handle_new_user)
ALTER TABLE public.users
  ADD COLUMN geocode_usage_count      integer     NOT NULL DEFAULT 0,
  ADD COLUMN geocode_window_started_at timestamptz NOT NULL DEFAULT now();

-- 2. Increment atomico TOCTOU-safe, finestra scorrevole a 24h
--    Stesso pattern CASE di reset finestra della vecchia RPC su
--    geocode_usage, ma su public.users — quindi UPDATE semplice
--    (la riga utente esiste già, niente INSERT ... ON CONFLICT).
CREATE OR REPLACE FUNCTION public.increment_geocode_count(
  p_user_id        uuid,
  p_now            timestamptz,
  p_cap            integer DEFAULT 200,
  p_window_minutes integer DEFAULT 1440
)
RETURNS boolean AS $$
DECLARE
  v_new_count integer;
BEGIN
  UPDATE public.users
  SET
    geocode_usage_count = CASE
      WHEN geocode_window_started_at < p_now - make_interval(mins => p_window_minutes)
        THEN 1
      ELSE geocode_usage_count + 1
    END,
    geocode_window_started_at = CASE
      WHEN geocode_window_started_at < p_now - make_interval(mins => p_window_minutes)
        THEN p_now
      ELSE geocode_window_started_at
    END
  WHERE id = p_user_id
    AND (
      -- Finestra scaduta: reset incondizionato consentito
      geocode_window_started_at < p_now - make_interval(mins => p_window_minutes)
      -- Stessa finestra: incremento solo se sotto il cap
      OR geocode_usage_count < p_cap
    )
  RETURNING geocode_usage_count INTO v_new_count;

  IF NOT FOUND THEN
    -- UPDATE senza match: cap raggiunto oppure utente inesistente.
    -- Distinguiamo per non mascherare un 429 silenzioso su utenti mancanti.
    IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_user_id) THEN
      RAISE EXCEPTION 'user_not_found: no row in public.users for id %', p_user_id;
    END IF;
    RETURN false;
  END IF;

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- 3. Rimozione della vecchia tabella dedicata (policy + tabella)
DROP POLICY IF EXISTS "geocode_usage_select_own" ON public.geocode_usage;
DROP TABLE IF EXISTS public.geocode_usage;

-- ─────────────────────────────────────────────────────────────────────────────
-- SANITY CHECK
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_columns_exist   boolean;
  v_function_exists boolean;
  v_old_table_gone  boolean;
BEGIN
  SELECT
    EXISTS (SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'users'
              AND column_name = 'geocode_usage_count')
    AND EXISTS (SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'users'
              AND column_name = 'geocode_window_started_at')
  INTO v_columns_exist;

  IF NOT v_columns_exist THEN
    RAISE EXCEPTION 'geocode_usage_count / geocode_window_started_at columns missing on public.users';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'increment_geocode_count'
  ) INTO v_function_exists;

  IF NOT v_function_exists THEN
    RAISE EXCEPTION 'increment_geocode_count function does not exist';
  END IF;

  SELECT NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'geocode_usage'
  ) INTO v_old_table_gone;

  IF NOT v_old_table_gone THEN
    RAISE EXCEPTION 'public.geocode_usage still exists after migration';
  END IF;

  RAISE NOTICE 'Geocode usage → public.users migration OK';
END $$;

COMMIT;
