-- Generatore di valigie (Edge Functions pack-trip e trip-weather).
--
-- 1. weather_cache: il meteo per luogo arrotondato e periodo. Le normali
--    climatiche non cambiano mai; le previsioni valgono il giorno in cui sono
--    state chieste (campo `_giorno` dentro `data`). La chiave e' quella del
--    bench: lat|lon arrotondate a 0,1 | mm-gg inizio | mm-gg fine | durata |
--    fonte | versione del calcolo.
-- 2. item_jev_profiles: il profilo Jev di ogni capo (elegante, da giorno,
--    caldo torrido, ...), calcolato una volta e rifatto solo quando la scheda
--    del capo (`card`) cambia.
-- 3. usage_counters + increment_usage: tetto d'uso per utente e per funzione,
--    finestra scorrevole, come increment_geocode_count ma per piu' funzioni.
--    I tetti sono una scelta di prodotto: le Edge Functions li leggono da
--    public.app_config (pack_trip_daily_cap, trip_weather_daily_cap), con un
--    predefinito nel codice (30 e 100) se la riga manca.
--
-- Nessuna policy RLS: le tabelle le legge e scrive solo il service role delle
-- Edge Functions (rls_auto_enable le protegge comunque).

CREATE TABLE IF NOT EXISTS public.weather_cache (
  key        text        PRIMARY KEY,
  data       jsonb       NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.weather_cache ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.item_jev_profiles (
  item_id    uuid        PRIMARY KEY REFERENCES public.items(id) ON DELETE CASCADE,
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  card       text        NOT NULL,
  answers    jsonb       NOT NULL,
  model      text,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS item_jev_profiles_user_id_idx ON public.item_jev_profiles (user_id);
ALTER TABLE public.item_jev_profiles ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.usage_counters (
  user_id           uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind              text        NOT NULL,
  count             integer     NOT NULL DEFAULT 0,
  window_started_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, kind)
);
ALTER TABLE public.usage_counters ENABLE ROW LEVEL SECURITY;

-- Atomico (una sola istruzione): niente TOCTOU fra lettura e incremento.
CREATE OR REPLACE FUNCTION public.increment_usage(
  p_user_id        uuid,
  p_kind           text,
  p_now            timestamptz,
  p_cap            integer,
  p_window_minutes integer
)
RETURNS boolean AS $$
DECLARE
  v_count integer;
BEGIN
  INSERT INTO public.usage_counters AS u (user_id, kind, count, window_started_at)
  VALUES (p_user_id, p_kind, 1, p_now)
  ON CONFLICT (user_id, kind) DO UPDATE
  SET
    count = CASE
      WHEN u.window_started_at < p_now - make_interval(mins => p_window_minutes) THEN 1
      ELSE u.count + 1
    END,
    window_started_at = CASE
      WHEN u.window_started_at < p_now - make_interval(mins => p_window_minutes) THEN p_now
      ELSE u.window_started_at
    END
  WHERE u.window_started_at < p_now - make_interval(mins => p_window_minutes)
     OR u.count < p_cap
  RETURNING u.count INTO v_count;

  RETURN FOUND AND v_count <= p_cap;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Come le altre RPC di usage: solo il service role (vedi baseline, 7bis).
REVOKE ALL ON FUNCTION public.increment_usage(uuid, text, timestamptz, integer, integer)
  FROM PUBLIC, anon, authenticated;

INSERT INTO public.app_config (key, value) VALUES
  ('pack_trip_daily_cap', '30'),
  ('trip_weather_daily_cap', '100')
ON CONFLICT (key) DO NOTHING;
