-- Users table: mirrors auth.users with GPT usage tracking (lifetime cap, no reset)
-- Execute in Supabase Dashboard → SQL Editor (in this order)

-- 1. Create the users table
CREATE TABLE public.users (
  id               uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email            text NOT NULL,
  gpt_usage_count  integer NOT NULL DEFAULT 0,
  gpt_usage_cap    integer NOT NULL DEFAULT 30,
  created_at       timestamptz NOT NULL DEFAULT now()
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
