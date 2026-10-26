-- Tetto ai tentativi dei codici promo: al massimo promo_attempts_daily_cap
-- codici provati per utente in 24 ore (predefinito 10). Oltre il tetto la RPC
-- risponde {"ok": false, "error": "too_many_attempts"}; le versioni dell'app
-- che non conoscono il codice lo mostrano come "Codice non valido".
-- Il contatore e' quello delle Edge Functions (usage_counters, kind
-- 'promo-attempt'). Nessuna colonna nuova: si applica quando si vuole.
BEGIN;

INSERT INTO public.app_config (key, value) VALUES
  ('promo_attempts_daily_cap', '10')
ON CONFLICT (key) DO NOTHING;

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

  -- Ogni codice provato conta, giusto o sbagliato: senza tetto i codici si
  -- indovinerebbero per tentativi nei giorni dell'iscrizione.
  IF NOT public.increment_usage(v_uid, 'promo-attempt', v_now,
       public.app_config_int('promo_attempts_daily_cap', 10), 60 * 24) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'too_many_attempts');
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

REVOKE ALL ON FUNCTION public.redeem_promo_code(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.redeem_promo_code(text) TO authenticated;

COMMIT;
