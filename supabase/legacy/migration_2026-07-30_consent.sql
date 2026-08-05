-- Consent registry (GDPR art. 7: il titolare deve poter DIMOSTRARE il consenso)
-- Execute in Supabase Dashboard → SQL Editor
--
-- Contesto: il consenso viene prestato sulla schermata di login, quindi PRIMA
-- che esista una sessione autenticata e prima che il trigger
-- `on_auth_user_created` crei la riga in public.users. Il client lo registra
-- localmente (shared_preferences) e lo riversa qui al primo login riuscito,
-- conservando il timestamp ORIGINALE del momento in cui la casella è stata
-- spuntata — non quello della scrittura remota, che sarebbe un falso.

-- 1. Colonne del consenso
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS consent_given_at        timestamptz,
  ADD COLUMN IF NOT EXISTS consent_policy_version  text;

COMMENT ON COLUMN public.users.consent_given_at IS
  'Istante in cui l''utente ha spuntato la casella di consenso sul client '
  '(t0), non l''istante della scrittura su questa tabella.';
COMMENT ON COLUMN public.users.consent_policy_version IS
  'Versione di Privacy Policy / Termini accettata, per sapere COSA è stato '
  'accettato quando i documenti cambiano.';

-- 2. RPC di registrazione
--
-- Deliberatamente una RPC SECURITY DEFINER e NON una policy UPDATE su
-- public.users: la stessa tabella contiene `gpt_usage_count` e
-- `gpt_usage_cap`, quindi una UPDATE generica consentirebbe a un client
-- malevolo di azzerarsi il contatore GPT o alzarsi il tetto. Questa funzione
-- scrive esclusivamente le due colonne del consenso, e solo sulla riga di
-- chi chiama. Stesso pattern di `increment_gpt_usage`.
--
-- Idempotente e "first write wins": una volta registrato, il consenso non
-- viene sovrascritto da chiamate successive (il flush del client può
-- ripetersi su più avvii senza spostare la data in avanti). Per aggiornare
-- il consenso a una nuova versione della policy serve prima azzerare
-- consent_given_at.
CREATE OR REPLACE FUNCTION public.record_consent(
  p_given_at       timestamptz,
  p_policy_version text
)
RETURNS void AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- Rifiuta timestamp nel futuro: il client potrebbe avere l'orologio
  -- sballato, e una data futura renderebbe il registro non difendibile.
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

-- 3. Permessi: solo utenti autenticati possono invocarla
REVOKE ALL ON FUNCTION public.record_consent(timestamptz, text) FROM public;
GRANT EXECUTE ON FUNCTION public.record_consent(timestamptz, text) TO authenticated;
