-- ─────────────────────────────────────────────────────────────────────────────
-- updated_at: enforce server-side timestamp via BEFORE trigger
--
-- Stato precedente: il client (Drift/Flutter) costruiva `updated_at` con
-- `DateTime.now().toUtc()` e lo inviava nei payload upsert. `SyncService` lo
-- usava come pivot Last-Write-Wins.
--
-- Rischio: un client malizioso (o uno con clock sballato/timezone errata/
-- data manuale) poteva inviare `updated_at = "2099-01-01"` e vincere SEMPRE
-- i conflitti di sync. RLS isola gli utenti, quindi il blast radius oggi è
-- limitato ai propri dati — ma diventa un buco vero appena aggiungiamo
-- feature di condivisione, e anche oggi crea inconsistenze multi-device per
-- un singolo utente con clock drift.
--
-- Mitigazione: il trigger `BEFORE INSERT OR UPDATE` sovrascrive
-- `NEW.updated_at = NOW()`. Qualsiasi valore inviato dal client viene
-- ignorato. PostgREST restituisce comunque la riga aggiornata via
-- `.upsert(...).select('updated_at')`: il client legge il timestamp
-- ufficiale e aggiorna lo stato locale per i sync successivi (vedi
-- modifiche in `SupabaseRepository.upsertX` + DAO `markXAsSynced`).
--
-- `created_at` resta controllato dal client: non è usato come pivot LWW,
-- e cambiarlo richiederebbe refactor del client senza benefici di sicurezza.
--
-- Esecuzione:
--   psql $SUPABASE_DB_URL -f supabase/schema_updated_at_trigger.sql
-- oppure incolla nel SQL Editor del Dashboard Supabase.
--
-- Idempotente: ri-eseguibile senza effetti collaterali.
-- ─────────────────────────────────────────────────────────────────────────────

BEGIN;

-- ── 1. Funzione condivisa ────────────────────────────────────────────────────
-- Una sola funzione, riusata da tutte le tabelle dati. Il pattern di
-- `SECURITY INVOKER` (default) è corretto: il trigger gira con i privilegi
-- del chiamante — non serve elevare.
CREATE OR REPLACE FUNCTION public.set_updated_at_to_now()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ── 2. Trigger BEFORE INSERT OR UPDATE su ogni tabella dati ─────────────────
-- DROP + CREATE per idempotenza. `BEFORE` permette di mutare NEW prima
-- della scrittura. `FOR EACH ROW` perché PG non supporta trigger statement-
-- level che mutano NEW.

DROP TRIGGER IF EXISTS set_updated_at ON public.houses;
CREATE TRIGGER set_updated_at
  BEFORE INSERT OR UPDATE ON public.houses
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_to_now();

DROP TRIGGER IF EXISTS set_updated_at ON public.items;
CREATE TRIGGER set_updated_at
  BEFORE INSERT OR UPDATE ON public.items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_to_now();

DROP TRIGGER IF EXISTS set_updated_at ON public.spaces;
CREATE TRIGGER set_updated_at
  BEFORE INSERT OR UPDATE ON public.spaces
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_to_now();

DROP TRIGGER IF EXISTS set_updated_at ON public.luggages;
CREATE TRIGGER set_updated_at
  BEFORE INSERT OR UPDATE ON public.luggages
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_to_now();

DROP TRIGGER IF EXISTS set_updated_at ON public.trips;
CREATE TRIGGER set_updated_at
  BEFORE INSERT OR UPDATE ON public.trips
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_to_now();

-- ─────────────────────────────────────────────────────────────────────────────
-- SANITY CHECK
-- Verifica che il trigger sia attivo su tutte e 5 le tabelle dati e che la
-- funzione esista. Rollback se manca qualcosa.
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_trigger_count integer;
  v_function_exists boolean;
BEGIN
  SELECT count(*) INTO v_trigger_count
  FROM pg_trigger t
  JOIN pg_class c     ON c.oid = t.tgrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('houses', 'items', 'spaces', 'luggages', 'trips')
    AND t.tgname  = 'set_updated_at'
    AND NOT t.tgisinternal;

  IF v_trigger_count <> 5 THEN
    RAISE EXCEPTION
      'updated_at trigger sanity FAILED: expected 5 triggers, found %',
      v_trigger_count;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'set_updated_at_to_now'
  ) INTO v_function_exists;

  IF NOT v_function_exists THEN
    RAISE EXCEPTION 'set_updated_at_to_now function does not exist';
  END IF;

  RAISE NOTICE 'updated_at trigger sanity OK: 5 triggers active';
END $$;

COMMIT;
