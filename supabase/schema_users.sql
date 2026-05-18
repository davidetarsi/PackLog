-- Users table: mirrors auth.users with GPT usage tracking
-- Execute in Supabase Dashboard → SQL Editor (in this order)

-- 1. Create the users table
CREATE TABLE public.users (
  id                  uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email               text NOT NULL,
  gpt_monthly_count   integer NOT NULL DEFAULT 0,
  gpt_monthly_cap     integer NOT NULL DEFAULT 50,
  gpt_count_reset_at  timestamptz NOT NULL DEFAULT now(),
  created_at          timestamptz NOT NULL DEFAULT now()
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. Enable RLS and add SELECT policy
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_own"
  ON public.users FOR SELECT
  USING (auth.uid() = id);

-- 4. Atomic GPT count increment with lazy monthly reset
CREATE OR REPLACE FUNCTION public.increment_gpt_count(
  p_user_id uuid,
  p_now     timestamptz
)
RETURNS boolean AS $$
DECLARE
  v_reset_needed boolean;
  v_new_count    integer;
BEGIN
  SELECT (
    date_trunc('month', p_now) > date_trunc('month', gpt_count_reset_at)
  )
  INTO v_reset_needed
  FROM public.users
  WHERE id = p_user_id;

  IF v_reset_needed THEN
    UPDATE public.users
    SET
      gpt_monthly_count  = 1,
      gpt_count_reset_at = p_now
    WHERE id = p_user_id
    RETURNING gpt_monthly_count INTO v_new_count;
    RETURN true;
  ELSE
    UPDATE public.users
    SET gpt_monthly_count = gpt_monthly_count + 1
    WHERE id = p_user_id
      AND gpt_monthly_count < gpt_monthly_cap
    RETURNING gpt_monthly_count INTO v_new_count;

    RETURN v_new_count IS NOT NULL;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Rollback decrement (compensating transaction — called by Edge Function on OpenAI error)
CREATE OR REPLACE FUNCTION public.decrement_gpt_count(p_user_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE public.users
  SET gpt_monthly_count = GREATEST(gpt_monthly_count - 1, 0)
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Backfill existing users (run once after creating the table)
-- INSERT INTO public.users (id, email)
-- SELECT id, email FROM auth.users
-- ON CONFLICT (id) DO NOTHING;
