-- ═════════════════════════════════════════════════════════════════════════════
-- Stuff Tracker 2 / PackLog — Supabase database bootstrap (schema completo)
--
-- Script UNICO e IDEMPOTENTE per creare da zero il DB remoto (es. il progetto
-- prod). Consolida tutti i file schema_*.sql / migration_*.sql precedenti
-- (ora storici — vedi in fondo) nello stato FINALE attuale, verificato
-- riga per riga contro il progetto dev (aluzxhcflmophawoffad) via
--   supabase db query --linked
-- (nessun Docker/psql necessario in locale, solo Management API).
--
-- Esecuzione: incolla nel SQL Editor del Dashboard Supabase del progetto
-- VUOTO su cui vuoi bootstrappare, oppure:
--   supabase db query -f supabase/database_schema.sql --linked
-- (dopo aver fatto `supabase link --project-ref <nuovo-ref>`).
--
-- Ordine di creazione (rispetta le FK):
--   estensioni → app_config → public.users (+ trigger su auth.users) →
--   houses → spaces → luggages → items → trips → RPC → cron → event trigger
--
-- Per un DB che ha già le tabelle (es. l'attuale dev) questo script è
-- ri-eseguibile senza effetti collaterali (CREATE ... IF NOT EXISTS,
-- CREATE OR REPLACE, DROP ... IF EXISTS + CREATE) — non droppa né svuota
-- tabelle esistenti.
--
-- Storico dei singoli file consolidati qui (mantenuti nel repo solo come
-- riferimento git-blame, non più da eseguire singolarmente):
--   schema_users.sql, schema_items.sql, schema_rls.sql,
--   schema_trips_jsonb_columns.sql, schema_updated_at_trigger.sql,
--   migration_2026-07-23_gpt_lifetime_cap.sql, migration_2026-07-30_consent.sql,
--   migration_2026-07-30_geocode_users.sql
-- ═════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. Estensioni
-- ─────────────────────────────────────────────────────────────────────────────
-- Schemi espliciti per rispecchiare ESATTAMENTE il progetto dev (verificato
-- via pg_extension JOIN pg_namespace): pg_cron in pg_catalog, gli altri in
-- `extensions`. `IF NOT EXISTS` rende il tutto no-op se già presenti.
--
-- pg_cron: necessaria per lo scheduled job di purge dei tombstone (§8).
-- Se questa riga fallisce per privilegi su un progetto nuovo, abilita
-- l'estensione da Dashboard → Database → Extensions → pg_cron e ri-esegui
-- lo script (il resto è idempotente).
--
-- pgcrypto / uuid-ossp: già pre-installate su ogni progetto Supabase,
-- dichiarate qui solo per rendere lo script davvero standalone.
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron     WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS pgcrypto    WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. app_config — configurazione globale letta da tutti gli autenticati
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.app_config (
  key   text PRIMARY KEY,
  value text NOT NULL
);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read app_config" ON public.app_config;
CREATE POLICY "Authenticated users can read app_config"
  ON public.app_config
  FOR SELECT
  TO authenticated
  USING (true);

-- Seed: retention di default per il purge dei tombstone (§8.5)
INSERT INTO public.app_config (key, value)
VALUES ('tombstone_retention_days', '15')
ON CONFLICT (key) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. public.users — mirror di auth.users + usage tracking (GPT, geocode) +
--    registro consenso GDPR
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id               uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email            text NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),

  -- Usage AI (GPT-4o Vision) — cap lifetime, nessun reset a finestra.
  gpt_usage_count  integer NOT NULL DEFAULT 0,
  gpt_usage_cap    integer NOT NULL DEFAULT 30,

  -- Registro del consenso (GDPR art. 7). Nullable: la riga nasce dal trigger
  -- al signup, il consenso viene prestato prima del login sulla schermata
  -- di login e riversato qui dal client subito dopo il primo accesso.
  consent_given_at       timestamptz,
  consent_policy_version text,

  -- Rate-limit del geocode-proxy (Geoapify autocomplete) — finestra
  -- scorrevole 24h, cap default 200/utente/giorno (vedi §7.3).
  geocode_usage_count       integer     NOT NULL DEFAULT 0,
  geocode_window_started_at timestamptz NOT NULL DEFAULT now()
);

-- Trigger: crea automaticamente la riga public.users al signup.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_select_own" ON public.users;
CREATE POLICY "users_select_own"
  ON public.users FOR SELECT
  USING (auth.uid() = id);

-- Backfill: utenti auth.users pre-esistenti senza riga public.users
-- (no-op su un DB nuovo, dove auth.users è vuota).
INSERT INTO public.users (id, email)
SELECT id, email FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Le 5 tabelle dati — speculari alle tabelle Drift locali (vedi
--    lib/core/database/tables/). user_id → auth.users direttamente (non
--    public.users): le 5 tabelle e public.users sono entrambe ancorate ad
--    auth.users in modo indipendente, non l'una attraverso l'altra.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── HOUSES ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.houses (
  id                     uuid        PRIMARY KEY,
  user_id                uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name                   text        NOT NULL,
  description            text,
  location_place_id      text,
  location_display_name  text,
  location_name          text,
  location_city          text,
  location_state         text,
  location_country       text,
  location_type          text,
  location_lat           real,
  location_lon           real,
  icon_name              text        NOT NULL DEFAULT 'home',
  is_primary             boolean     NOT NULL DEFAULT false,
  is_deleted             boolean     NOT NULL DEFAULT false,
  sync_status            text        NOT NULL DEFAULT 'synced',
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now()
);

-- ── SPACES ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.spaces (
  id          uuid        PRIMARY KEY,
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  house_id    uuid        NOT NULL REFERENCES public.houses(id) ON DELETE CASCADE,
  name        text        NOT NULL,
  icon_name   text,
  is_deleted  boolean     NOT NULL DEFAULT false,
  sync_status text        NOT NULL DEFAULT 'synced',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- ── LUGGAGES ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.luggages (
  id            uuid        PRIMARY KEY,
  user_id       uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  house_id      uuid        NOT NULL REFERENCES public.houses(id) ON DELETE CASCADE,
  name          text        NOT NULL,
  size_type     text        NOT NULL,
  volume_liters integer,
  is_deleted    boolean     NOT NULL DEFAULT false,
  sync_status   text        NOT NULL DEFAULT 'synced',
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- ── ITEMS ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.items (
  id           uuid        PRIMARY KEY,
  user_id      uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  house_id     uuid        NOT NULL REFERENCES public.houses(id),
  space_id     uuid        REFERENCES public.spaces(id) ON DELETE SET NULL,
  name         text        NOT NULL,
  category     text        NOT NULL,
  description  text,
  quantity     integer,
  -- Metadati AI generati da GPT-4o Vision (schemaVersion 8 → 9, 2026-05-20)
  ai_metadata  jsonb,
  is_deleted   boolean     NOT NULL DEFAULT false,
  sync_status  text        NOT NULL DEFAULT 'synced',
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

-- ── TRIPS ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.trips (
  id                     uuid        PRIMARY KEY,
  user_id                uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name                   text        NOT NULL,
  description            text,
  departure_date_time    timestamptz,
  return_date_time       timestamptz,
  destination_house_id   uuid        REFERENCES public.houses(id) ON DELETE SET NULL,
  location_place_id      text,
  location_display_name  text,
  location_name          text,
  location_city          text,
  location_state         text,
  location_country       text,
  location_type          text,
  location_lat           real,
  location_lon           real,
  primary_vibe           text,
  extra_events           jsonb       DEFAULT '[]'::jsonb,
  avg_temperature        integer,
  weather_tags           jsonb       DEFAULT '[]'::jsonb,
  is_saved               boolean     NOT NULL DEFAULT false,
  is_deleted             boolean     NOT NULL DEFAULT false,
  sync_status            text        NOT NULL DEFAULT 'synced',
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  -- Snapshot immutabile della checklist + bagagli associati (vedi
  -- ARCHITECTURE.md "Trip items + luggages: serializzati nel payload del trip")
  items                  jsonb       NOT NULL DEFAULT '[]'::jsonb,
  luggage_ids            jsonb       NOT NULL DEFAULT '[]'::jsonb
);

-- ── RLS: enable + policy "Accesso totale ai propri dati" su tutte e 5 ───────
ALTER TABLE public.houses   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spaces   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.luggages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.items    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips    ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Accesso totale ai propri dati per Houses" ON public.houses;
CREATE POLICY "Accesso totale ai propri dati per Houses"
  ON public.houses AS PERMISSIVE FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Accesso totale ai propri dati per Spaces" ON public.spaces;
CREATE POLICY "Accesso totale ai propri dati per Spaces"
  ON public.spaces AS PERMISSIVE FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Accesso totale ai propri dati per Luggages" ON public.luggages;
CREATE POLICY "Accesso totale ai propri dati per Luggages"
  ON public.luggages AS PERMISSIVE FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Accesso totale ai propri dati per Items" ON public.items;
CREATE POLICY "Accesso totale ai propri dati per Items"
  ON public.items AS PERMISSIVE FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Accesso totale ai propri dati per Trips" ON public.trips;
CREATE POLICY "Accesso totale ai propri dati per Trips"
  ON public.trips AS PERMISSIVE FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. updated_at: enforce server-side timestamp via BEFORE trigger
--
-- Senza questo, un client con clock sballato/manomesso potrebbe inviare
-- updated_at nel futuro e vincere sempre i conflitti di sync LWW (Last-
-- Write-Wins). Il trigger sovrascrive NEW.updated_at con NOW() lato server,
-- qualsiasi valore inviato dal client viene ignorato. created_at resta
-- controllato dal client (non è pivot LWW).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at_to_now()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_updated_at ON public.houses;
CREATE TRIGGER set_updated_at
  BEFORE INSERT OR UPDATE ON public.houses
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_to_now();

DROP TRIGGER IF EXISTS set_updated_at ON public.spaces;
CREATE TRIGGER set_updated_at
  BEFORE INSERT OR UPDATE ON public.spaces
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_to_now();

DROP TRIGGER IF EXISTS set_updated_at ON public.luggages;
CREATE TRIGGER set_updated_at
  BEFORE INSERT OR UPDATE ON public.luggages
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_to_now();

DROP TRIGGER IF EXISTS set_updated_at ON public.items;
CREATE TRIGGER set_updated_at
  BEFORE INSERT OR UPDATE ON public.items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_to_now();

DROP TRIGGER IF EXISTS set_updated_at ON public.trips;
CREATE TRIGGER set_updated_at
  BEFORE INSERT OR UPDATE ON public.trips
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_to_now();

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. RPC — GPT usage (lifetime cap, no reset)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.increment_gpt_usage(p_user_id uuid)
RETURNS boolean AS $$
DECLARE
  v_new_count integer;
BEGIN
  UPDATE public.users
  SET gpt_usage_count = gpt_usage_count + 1
  WHERE id = p_user_id
    AND gpt_usage_count < gpt_usage_cap
  RETURNING gpt_usage_count INTO v_new_count;

  IF NOT FOUND THEN
    IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_user_id) THEN
      RAISE EXCEPTION 'user_not_found: no row in public.users for id %', p_user_id;
    END IF;
    RETURN false;
  END IF;

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Rollback compensativo (chiamato dalla Edge Function `openai-proxy` su errore OpenAI)
CREATE OR REPLACE FUNCTION public.decrement_gpt_usage(p_user_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE public.users
  SET gpt_usage_count = GREATEST(gpt_usage_count - 1, 0)
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. RPC — Registrazione del consenso (GDPR art. 7)
--
-- RPC SECURITY DEFINER e NON una policy UPDATE su public.users: la tabella
-- contiene anche gpt_usage_count/cap e geocode_usage_count, quindi una
-- UPDATE generica lascerebbe a un client la possibilità di alterarsi i
-- contatori. Questa scrive solo le colonne del consenso, e solo sulla riga
-- di chi chiama (auth.uid()). "First write wins": idempotente su più flush.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.record_consent(
  p_given_at       timestamptz,
  p_policy_version text
)
RETURNS void AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF p_given_at > now() THEN
    RAISE EXCEPTION 'consent_timestamp_in_future';
  END IF;

  UPDATE public.users
  SET consent_given_at       = p_given_at,
      consent_policy_version = p_policy_version
  WHERE id = auth.uid()
    AND consent_given_at IS NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. RPC — Geocode usage (Geoapify autocomplete), finestra scorrevole 24h
-- ─────────────────────────────────────────────────────────────────────────────
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
      geocode_window_started_at < p_now - make_interval(mins => p_window_minutes)
      OR geocode_usage_count < p_cap
    )
  RETURNING geocode_usage_count INTO v_new_count;

  IF NOT FOUND THEN
    IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_user_id) THEN
      RAISE EXCEPTION 'user_not_found: no row in public.users for id %', p_user_id;
    END IF;
    RETURN false;
  END IF;

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7bis. GRANT hardening sulle RPC di usage
--
-- SICUREZZA — trovato durante la consolidazione di questo file (verificato
-- via has_function_privilege sul progetto dev): increment_gpt_usage,
-- decrement_gpt_usage e increment_geocode_count risultavano eseguibili dal
-- ruolo `anon`. Tutte e tre accettano `p_user_id` come parametro esplicito
-- SENZA verificare auth.uid() = p_user_id — un client anonimo (solo anon
-- key, nessun login) poteva quindi chiamarle direttamente via
-- `supabase.rpc(...)` per ESAURIRE o AZZERARE il contatore di QUALSIASI
-- utente a piacere, bypassando completamente le Edge Function proxy.
-- record_consent era già protetta correttamente (REVOKE + GRANT TO
-- authenticated in schema_users.sql) — usata come modello qui.
--
-- Le Edge Function (openai-proxy, geocode-proxy) chiamano queste RPC con la
-- SERVICE ROLE KEY, il cui ruolo DB (service_role) ha privilegi impliciti
-- che ignorano i GRANT/REVOKE qui sotto — restringere a `authenticated`
-- (o revocare del tutto) non rompe quindi il flusso esistente.
REVOKE ALL ON FUNCTION public.increment_gpt_usage(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.decrement_gpt_usage(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.increment_geocode_count(uuid, timestamptz, integer, integer)
  FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.record_consent(timestamptz, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_consent(timestamptz, text) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. Purge dei tombstone soft-deleted (retention da app_config)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.purge_expired_tombstones()
RETURNS void AS $$
DECLARE
  retention_days int;
  cutoff timestamptz;
BEGIN
  SELECT COALESCE(value::int, 15) INTO retention_days
    FROM public.app_config WHERE key = 'tombstone_retention_days';
  IF retention_days IS NULL THEN retention_days := 15; END IF;
  cutoff := now() - (retention_days || ' days')::interval;

  DELETE FROM public.items  WHERE is_deleted = true AND updated_at < cutoff;
  DELETE FROM public.trips  WHERE is_deleted = true AND updated_at < cutoff;
  DELETE FROM public.houses WHERE is_deleted = true AND updated_at < cutoff;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE ALL ON FUNCTION public.purge_expired_tombstones() FROM PUBLIC, anon, authenticated;

-- Scheduling: ogni giorno alle 3:00 UTC. `cron.schedule` con un nome di job
-- è idempotente (aggiorna il job esistente invece di duplicarlo).
SELECT cron.schedule(
  'purge-expired-tombstones',
  '0 3 * * *',
  $$SELECT public.purge_expired_tombstones()$$
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. Difesa in profondità: auto-enable RLS su ogni nuova tabella pubblica
--
-- Event trigger DDL: se in futuro qualcuno crea una tabella in `public`
-- (dashboard, migration, script) senza pensare a RLS, questo la abilita
-- automaticamente. Fail-safe: eventuali errori vengono loggati, mai propagati
-- (non deve mai bloccare una CREATE TABLE legittima).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.rls_auto_enable()
RETURNS event_trigger AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog;

DROP EVENT TRIGGER IF EXISTS ensure_rls;
CREATE EVENT TRIGGER ensure_rls
  ON ddl_command_end
  WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
  EXECUTE FUNCTION public.rls_auto_enable();

-- ─────────────────────────────────────────────────────────────────────────────
-- SANITY CHECK
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_missing_tables   text[];
  v_rls_off          text[];
  v_policy_count     integer;
  v_missing_functions text[];
  v_cron_exists      boolean;
BEGIN
  SELECT array_agg(t) INTO v_missing_tables
  FROM unnest(ARRAY['app_config','users','houses','spaces','luggages','items','trips']) t
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = t
  );
  IF v_missing_tables IS NOT NULL THEN
    RAISE EXCEPTION 'Missing tables after bootstrap: %', v_missing_tables;
  END IF;

  SELECT array_agg(c.relname) INTO v_rls_off
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('app_config','users','houses','spaces','luggages','items','trips')
    AND c.relrowsecurity = false;
  IF v_rls_off IS NOT NULL THEN
    RAISE EXCEPTION 'RLS disabled on: %', v_rls_off;
  END IF;

  SELECT count(*) INTO v_policy_count
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename IN ('houses','items','spaces','luggages','trips')
    AND cmd = 'ALL';
  IF v_policy_count <> 5 THEN
    RAISE EXCEPTION 'Expected 5 ALL policies on data tables, found %', v_policy_count;
  END IF;

  SELECT array_agg(f) INTO v_missing_functions
  FROM unnest(ARRAY[
    'handle_new_user','set_updated_at_to_now','increment_gpt_usage',
    'decrement_gpt_usage','record_consent','increment_geocode_count',
    'purge_expired_tombstones','rls_auto_enable'
  ]) f
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = f
  );
  IF v_missing_functions IS NOT NULL THEN
    RAISE EXCEPTION 'Missing functions after bootstrap: %', v_missing_functions;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'purge-expired-tombstones'
  ) INTO v_cron_exists;
  IF NOT v_cron_exists THEN
    RAISE EXCEPTION 'purge-expired-tombstones cron job not scheduled';
  END IF;

  RAISE NOTICE 'database_schema.sql bootstrap OK: tables, RLS, policies, functions, cron all present';
END $$;

COMMIT;
