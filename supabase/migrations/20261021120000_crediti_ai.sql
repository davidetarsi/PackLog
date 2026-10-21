-- Crediti AI: un solo tetto mensile per foto e valigia, crediti extra dai
-- codici promo.
--
-- 1. Tetto mensile: foto (openai-proxy, item-metadata) e valigia (pack-trip)
--    consumano lo stesso contatore, usage_counters kind 'ai', con una finestra
--    di ai_window_days giorni dal primo uso. Prende il posto del tetto a vita
--    users.gpt_usage_count/cap (le colonne restano per le app vecchie, che le
--    leggono nel profilo, ma nessuno le incrementa piu').
-- 2. Crediti extra: ai_credit_grants, una riga per regalo con la sua scadenza.
--    Si usano solo a quota mensile finita, prima quelli che scadono prima.
-- 3. Codici promo: promo_codes (uno per canale: si sa da dove arriva chi lo
--    usa), promo_redemptions (un codice per account, entro
--    promo_redeem_window_days dall'iscrizione).
-- 4. I nomi dei capi (item-metadata dal nome) restano fuori dal tetto AI: hanno
--    il loro limite giornaliero contro gli abusi, item_name_daily_cap (150:
--    ogni oggetto aggiunto a mano chiede la sua scheda, e l'app ne recupera
--    fino a 30 al giorno per quelli rimasti senza), che l'app non mostra.
--
-- Un codice nuovo si aggiunge a mano, per esempio:
--   INSERT INTO public.promo_codes (code, channel, credits, valid_days, max_redemptions)
--   VALUES ('INSTA', 'instagram', 20, 60, 500);
--
-- Nessuna policy RLS sulle tabelle: le leggono e scrivono le RPC qui sotto e
-- il service role delle Edge Functions.

INSERT INTO public.app_config (key, value) VALUES
  ('ai_monthly_cap', '30'),
  ('ai_window_days', '30'),
  ('promo_redeem_window_days', '7'),
  ('item_name_daily_cap', '150')
ON CONFLICT (key) DO NOTHING;

-- pack-trip non ha piu' un tetto suo: consuma i crediti AI.
DELETE FROM public.app_config WHERE key = 'pack_trip_daily_cap';

CREATE TABLE IF NOT EXISTS public.promo_codes (
  code            text        PRIMARY KEY CHECK (code = upper(code) AND code ~ '^[A-Z0-9_-]{3,32}$'),
  channel         text        NOT NULL,
  credits         integer     NOT NULL CHECK (credits > 0),
  valid_days      integer     NOT NULL CHECK (valid_days > 0),
  max_redemptions integer     CHECK (max_redemptions > 0),
  redemptions     integer     NOT NULL DEFAULT 0,
  expires_at      timestamptz,
  active          boolean     NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.promo_codes ENABLE ROW LEVEL SECURITY;

-- La chiave primaria su user_id fa "un codice per account".
CREATE TABLE IF NOT EXISTS public.promo_redemptions (
  user_id     uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  code        text        NOT NULL REFERENCES public.promo_codes(code),
  redeemed_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS promo_redemptions_code_idx ON public.promo_redemptions (code);
ALTER TABLE public.promo_redemptions ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.ai_credit_grants (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  credits    integer     NOT NULL CHECK (credits > 0),
  used       integer     NOT NULL DEFAULT 0 CHECK (used >= 0 AND used <= credits),
  reason     text        NOT NULL,
  code       text,
  granted_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL
);
CREATE INDEX IF NOT EXISTS ai_credit_grants_user_idx ON public.ai_credit_grants (user_id, expires_at);
ALTER TABLE public.ai_credit_grants ENABLE ROW LEVEL SECURITY;

-- Un intero positivo da app_config, o il predefinito.
CREATE OR REPLACE FUNCTION public.app_config_int(p_key text, p_default integer)
RETURNS integer AS $$
  SELECT COALESCE(
    (SELECT value::integer FROM public.app_config
      WHERE key = p_key AND value ~ '^[0-9]+$' AND value::integer > 0),
    p_default);
$$ LANGUAGE sql STABLE
SET search_path = public, pg_temp;

-- Un credito AI: prima la quota mensile, poi i crediti extra che scadono prima.
-- Restituisce da dove e' stato preso ({"source": "monthly"} oppure
-- {"source": "bonus", "grant_id": ...}), da ripassare a refund_ai_credit se la
-- chiamata al modello fallisce; null se non ne restano.
CREATE OR REPLACE FUNCTION public.consume_ai_credit(p_user_id uuid, p_now timestamptz)
RETURNS jsonb AS $$
DECLARE
  v_grant uuid;
BEGIN
  IF public.increment_usage(p_user_id, 'ai', p_now,
       public.app_config_int('ai_monthly_cap', 30),
       public.app_config_int('ai_window_days', 30) * 24 * 60) THEN
    RETURN jsonb_build_object('source', 'monthly');
  END IF;

  UPDATE public.ai_credit_grants g
  SET used = g.used + 1
  WHERE g.id = (
    SELECT id FROM public.ai_credit_grants
    WHERE user_id = p_user_id AND used < credits AND expires_at > p_now
    ORDER BY expires_at, granted_at
    LIMIT 1
    FOR UPDATE
  )
  RETURNING g.id INTO v_grant;

  IF v_grant IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN jsonb_build_object('source', 'bonus', 'grant_id', v_grant);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Rollback compensativo: ridà il credito preso da consume_ai_credit.
CREATE OR REPLACE FUNCTION public.refund_ai_credit(p_user_id uuid, p_consumo jsonb)
RETURNS void AS $$
BEGIN
  IF p_consumo->>'source' = 'monthly' THEN
    UPDATE public.usage_counters
    SET count = GREATEST(count - 1, 0)
    WHERE user_id = p_user_id AND kind = 'ai';
  ELSIF p_consumo->>'source' = 'bonus' THEN
    UPDATE public.ai_credit_grants
    SET used = GREATEST(used - 1, 0)
    WHERE id = (p_consumo->>'grant_id')::uuid AND user_id = p_user_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.consume_ai_credit(uuid, timestamptz) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.refund_ai_credit(uuid, jsonb) FROM PUBLIC, anon, authenticated;

-- Per il profilo dell'app: quota del mese, crediti extra, codice promo.
-- Solo la riga di chi chiama (auth.uid()).
CREATE OR REPLACE FUNCTION public.get_ai_usage()
RETURNS jsonb AS $$
DECLARE
  v_uid     uuid := auth.uid();
  v_now     timestamptz := now();
  v_days    integer := public.app_config_int('ai_window_days', 30);
  v_count   integer;
  v_start   timestamptz;
  v_bonus   integer;
  v_bonus_exp timestamptz;
  v_code    text;
  v_created timestamptz;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT count, window_started_at INTO v_count, v_start
  FROM public.usage_counters WHERE user_id = v_uid AND kind = 'ai';
  IF v_start IS NULL OR v_start < v_now - make_interval(days => v_days) THEN
    v_count := 0;
    v_start := NULL;
  END IF;

  SELECT COALESCE(sum(credits - used), 0), min(expires_at)
  INTO v_bonus, v_bonus_exp
  FROM public.ai_credit_grants
  WHERE user_id = v_uid AND used < credits AND expires_at > v_now;

  SELECT code INTO v_code FROM public.promo_redemptions WHERE user_id = v_uid;
  SELECT created_at INTO v_created FROM public.users WHERE id = v_uid;

  RETURN jsonb_build_object(
    'monthly_used', v_count,
    'monthly_cap', public.app_config_int('ai_monthly_cap', 30),
    'resets_at', v_start + make_interval(days => v_days),
    'bonus_available', v_bonus,
    'bonus_expires_at', v_bonus_exp,
    'promo_code', v_code,
    'can_redeem_promo', v_code IS NULL AND v_created IS NOT NULL
      AND v_created > v_now - make_interval(days => public.app_config_int('promo_redeem_window_days', 7))
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp;

-- Un codice promo: un solo codice per account, entro i primi giorni
-- dall'iscrizione. Gli errori tornano nel JSON ({"ok": false, "error": ...}:
-- invalid_code, expired, exhausted, already_redeemed, too_late), non come
-- eccezioni, cosi' l'app li mostra senza interpretare messaggi di Postgres.
CREATE OR REPLACE FUNCTION public.redeem_promo_code(p_code text)
RETURNS jsonb AS $$
DECLARE
  v_uid     uuid := auth.uid();
  v_now     timestamptz := now();
  v_code    text := upper(btrim(COALESCE(p_code, '')));
  v_created timestamptz;
  v_promo   public.promo_codes%ROWTYPE;
  v_expires timestamptz;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT created_at INTO v_created FROM public.users WHERE id = v_uid;
  IF v_created IS NULL
     OR v_created < v_now - make_interval(days => public.app_config_int('promo_redeem_window_days', 7)) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'too_late');
  END IF;
  IF EXISTS (SELECT 1 FROM public.promo_redemptions WHERE user_id = v_uid) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'already_redeemed');
  END IF;

  SELECT * INTO v_promo FROM public.promo_codes WHERE code = v_code AND active FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_code');
  END IF;
  IF v_promo.expires_at IS NOT NULL AND v_promo.expires_at <= v_now THEN
    RETURN jsonb_build_object('ok', false, 'error', 'expired');
  END IF;
  IF v_promo.max_redemptions IS NOT NULL AND v_promo.redemptions >= v_promo.max_redemptions THEN
    RETURN jsonb_build_object('ok', false, 'error', 'exhausted');
  END IF;

  INSERT INTO public.promo_redemptions (user_id, code, redeemed_at)
  VALUES (v_uid, v_code, v_now)
  ON CONFLICT (user_id) DO NOTHING;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'already_redeemed');
  END IF;

  UPDATE public.promo_codes SET redemptions = redemptions + 1 WHERE code = v_code;

  v_expires := v_now + make_interval(days => v_promo.valid_days);
  INSERT INTO public.ai_credit_grants (user_id, credits, reason, code, granted_at, expires_at)
  VALUES (v_uid, v_promo.credits, 'promo', v_code, v_now, v_expires);

  RETURN jsonb_build_object('ok', true, 'credits', v_promo.credits, 'expires_at', v_expires);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.get_ai_usage() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_ai_usage() TO authenticated;
REVOKE ALL ON FUNCTION public.redeem_promo_code(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.redeem_promo_code(text) TO authenticated;
REVOKE ALL ON FUNCTION public.app_config_int(text, integer) FROM PUBLIC, anon, authenticated;
