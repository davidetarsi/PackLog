-- Migration: lifetime GPT cap (2026-07-23)
-- Da eseguire nel Supabase Dashboard → SQL Editor (progetto aluzxhcflmophawoffad)
-- Sostituisce il cap mensile (lazy reset) con un cap cumulativo lifetime = 30.
-- Companion del commit 341df6b (client Flutter già migrato a gpt_usage_*).

BEGIN;

-- 1. Rename colonne (il client develop legge già gpt_usage_count / gpt_usage_cap)
ALTER TABLE public.users RENAME COLUMN gpt_monthly_count TO gpt_usage_count;
ALTER TABLE public.users RENAME COLUMN gpt_monthly_cap TO gpt_usage_cap;

-- 2. Nuovo default + backfill: cap lifetime 30 per tutti
ALTER TABLE public.users ALTER COLUMN gpt_usage_cap SET DEFAULT 30;
UPDATE public.users SET gpt_usage_cap = 30;

-- 3. La colonna del reset mensile non serve più
ALTER TABLE public.users DROP COLUMN gpt_count_reset_at;

-- 4. Drop delle vecchie funzioni (la firma cambia: via il p_now)
DROP FUNCTION IF EXISTS public.increment_gpt_count(uuid, timestamptz);
DROP FUNCTION IF EXISTS public.decrement_gpt_count(uuid);

-- 5. Increment atomico TOCTOU-safe, SENZA logica di reset
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

-- 6. Rollback compensativo (chiamato dalla Edge Function su errore OpenAI)
CREATE OR REPLACE FUNCTION public.decrement_gpt_usage(p_user_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE public.users
  SET gpt_usage_count = GREATEST(gpt_usage_count - 1, 0)
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- 7. Pin search_path on the pre-existing handle_new_user trigger function
-- (this function predates this migration; missed in the original pass — see final review finding)
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

COMMIT;
