-- Users table: mirrors auth.users with GPT + geocode usage tracking
-- Execute in Supabase Dashboard → SQL Editor (in this order)

-- 1. Create the users table
CREATE TABLE public.users (
  id               uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email            text NOT NULL,
  gpt_usage_count  integer NOT NULL DEFAULT 0,
  gpt_usage_cap    integer NOT NULL DEFAULT 30,
  created_at       timestamptz NOT NULL DEFAULT now(),
  -- Registro del consenso (GDPR art. 7). Nullable: la riga nasce dal trigger
  -- al signup, mentre il consenso viene prestato prima del login e riversato
  -- qui dal client subito dopo. Vedi migration_2026-07-30_consent.sql.
  consent_given_at       timestamptz,
  consent_policy_version text,
  -- Rate-limit del geocode-proxy (Geoapify): finestra scorrevole 24h, cap
  -- default 200/giorno. Vedi migration_2026-07-30_geocode_users.sql.
  geocode_usage_count       integer     NOT NULL DEFAULT 0,
  geocode_window_started_at timestamptz NOT NULL DEFAULT now()
);

-- 2. Create trigger function and trigger (auto-creates a row on new signup)
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

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. Enable RLS and add SELECT policy
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_own"
  ON public.users FOR SELECT
  USING (auth.uid() = id);

-- 4. Atomic GPT usage increment — lifetime cap, NO reset logic
CREATE OR REPLACE FUNCTION public.increment_gpt_usage(p_user_id uuid)
RETURNS boolean AS $$
DECLARE
  v_new_count integer;
BEGIN
  -- Single atomic UPDATE: increment + cap check with no TOCTOU window
  UPDATE public.users
  SET gpt_usage_count = gpt_usage_count + 1
  WHERE id = p_user_id
    AND gpt_usage_count < gpt_usage_cap
  RETURNING gpt_usage_count INTO v_new_count;

  IF NOT FOUND THEN
    -- UPDATE matched no row: either cap reached OR user doesn't exist
    IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = p_user_id) THEN
      RAISE EXCEPTION 'user_not_found: no row in public.users for id %', p_user_id;
    END IF;
    RETURN false;
  END IF;

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- 5. Rollback decrement (compensating transaction — called by Edge Function on OpenAI error)
CREATE OR REPLACE FUNCTION public.decrement_gpt_usage(p_user_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE public.users
  SET gpt_usage_count = GREATEST(gpt_usage_count - 1, 0)
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- 6. Backfill existing users (run once after creating the table)
INSERT INTO public.users (id, email)
SELECT id, email FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- 7. Registrazione del consenso (GDPR art. 7)
--
-- RPC SECURITY DEFINER e NON una policy UPDATE su public.users: la tabella
-- contiene anche `gpt_usage_count` e `gpt_usage_cap`, quindi una UPDATE
-- generica lascerebbe a un client la possibilità di azzerarsi il contatore
-- GPT o alzarsi il tetto. Questa scrive solo le colonne del consenso, e solo
-- sulla riga di chi chiama.
--
-- "First write wins": il flush del client è idempotente e può ripetersi su
-- più avvii senza spostare la data in avanti.
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

REVOKE ALL ON FUNCTION public.record_consent(timestamptz, text) FROM public;
GRANT EXECUTE ON FUNCTION public.record_consent(timestamptz, text) TO authenticated;

-- 8. Rate-limit del geocode-proxy (Geoapify autocomplete) — finestra
-- scorrevole 24h, cap default 200 richieste/utente/giorno. Nessuna policy
-- INSERT/UPDATE client-side sulle due colonne geocode_*: stesso discorso
-- del punto 7, tutte le mutazioni passano da questa RPC SECURITY DEFINER.
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
