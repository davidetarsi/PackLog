-- Kit: gruppi logici di oggetti della casa che entrano in valigia sciolti
-- (spec del 2 novembre 2026, parte B). Due tabelle sincronizzate come `spaces`,
-- il mezzo del viaggio e il dominio `transport` del catalogo.
-- DA APPLICARE A MANO (Davide): non lo applica l'agente.

-- ── KITS ────────────────────────────────────────────────────────────────────
-- learned: {"yes": {"trekking": 2}, "no": ["mare"]} (chiavi: id di attivita' o mezzo).
CREATE TABLE IF NOT EXISTS public.kits (
  id          uuid        PRIMARY KEY,
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  house_id    uuid        NOT NULL REFERENCES public.houses(id) ON DELETE CASCADE,
  name        text        NOT NULL CHECK (char_length(name) BETWEEN 1 AND 60),
  activities  text[]      NOT NULL DEFAULT '{}',
  transports  text[]      NOT NULL DEFAULT '{}',
  learned     jsonb       NOT NULL DEFAULT '{}'::jsonb,
  is_deleted  boolean     NOT NULL DEFAULT false,
  sync_status text        NOT NULL DEFAULT 'synced',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- ── KIT_ITEMS ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.kit_items (
  id          uuid        PRIMARY KEY,
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kit_id      uuid        NOT NULL REFERENCES public.kits(id) ON DELETE CASCADE,
  item_id     uuid        NOT NULL REFERENCES public.items(id) ON DELETE CASCADE,
  copies      integer     NOT NULL DEFAULT 1 CHECK (copies >= 1),
  is_deleted  boolean     NOT NULL DEFAULT false,
  sync_status text        NOT NULL DEFAULT 'synced',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (kit_id, item_id)
);

CREATE INDEX IF NOT EXISTS kits_house_id_idx      ON public.kits (house_id);
CREATE INDEX IF NOT EXISTS kit_items_kit_id_idx   ON public.kit_items (kit_id);
CREATE INDEX IF NOT EXISTS kit_items_item_id_idx  ON public.kit_items (item_id);

-- ── RLS: come spaces ────────────────────────────────────────────────────────
ALTER TABLE public.kits      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kit_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Accesso totale ai propri dati per Kits" ON public.kits;
CREATE POLICY "Accesso totale ai propri dati per Kits"
  ON public.kits AS PERMISSIVE FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Accesso totale ai propri dati per Kit items" ON public.kit_items;
CREATE POLICY "Accesso totale ai propri dati per Kit items"
  ON public.kit_items AS PERMISSIVE FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── updated_at lato server (vedi la baseline) ───────────────────────────────
DROP TRIGGER IF EXISTS set_updated_at ON public.kits;
CREATE TRIGGER set_updated_at
  BEFORE INSERT OR UPDATE ON public.kits
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_to_now();

DROP TRIGGER IF EXISTS set_updated_at ON public.kit_items;
CREATE TRIGGER set_updated_at
  BEFORE INSERT OR UPDATE ON public.kit_items
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_to_now();

-- ── Mezzo del viaggio ───────────────────────────────────────────────────────
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS transports text[];

-- ── Catalogo ────────────────────────────────────────────────────────────────
-- Mezzi del viaggio: nuovo dominio 'transport' del catalogo, con i sinonimi (data.alias)
-- che servono a riconoscere un'attivita' o un mezzo dal nome di un kit.
-- Le righe di activity prendono solo l'alias: significato, id e testi del
-- generatore restano quelli di sempre (regola 3 del catalogo).

INSERT INTO public.catalog_entries (domain, id, sort, active, label_it, label_en, data) VALUES
  ('transport', 'plane', 10, true, 'Aereo', 'Plane', '{"alias":["aereo","volo","flight","plane","airplane"]}'::jsonb),
  ('transport', 'train', 20, true, 'Treno', 'Train', '{"alias":["treno","train","rail"]}'::jsonb),
  ('transport', 'car', 30, true, 'Auto', 'Car', '{"alias":["auto","macchina","automobile","car","road trip"]}'::jsonb),
  ('transport', 'ship', 40, true, 'Nave', 'Ship', '{"alias":["nave","traghetto","crociera","ship","ferry","cruise"]}'::jsonb),
  ('transport', 'bus', 50, true, 'Bus', 'Bus', '{"alias":["bus","pullman","autobus","coach"]}'::jsonb)
ON CONFLICT (domain, id) DO NOTHING;

UPDATE public.catalog_entries SET data = data || jsonb_build_object('alias', '["citta","città","musei","museo","city","museums","sightseeing"]'::jsonb)
  WHERE domain = 'activity' AND id = 'city';
UPDATE public.catalog_entries SET data = data || jsonb_build_object('alias', '["passeggiata","passeggiate","natura","walk","walks","nature"]'::jsonb)
  WHERE domain = 'activity' AND id = 'walks';
UPDATE public.catalog_entries SET data = data || jsonb_build_object('alias', '["trekking","montagna","hiking","escursion","mountain"]'::jsonb)
  WHERE domain = 'activity' AND id = 'trekking';
UPDATE public.catalog_entries SET data = data || jsonb_build_object('alias', '["cammino","camino","pellegrinaggio","pilgrimage"]'::jsonb)
  WHERE domain = 'activity' AND id = 'cammino';
UPDATE public.catalog_entries SET data = data || jsonb_build_object('alias', '["mare","spiaggia","beach","sea"]'::jsonb)
  WHERE domain = 'activity' AND id = 'sea';
UPDATE public.catalog_entries SET data = data || jsonb_build_object('alias', '["immersioni","immersione","snorkeling","sub","diving"]'::jsonb)
  WHERE domain = 'activity' AND id = 'diving';
UPDATE public.catalog_entries SET data = data || jsonb_build_object('alias', '["sci","ski","neve","snow","settimana bianca"]'::jsonb)
  WHERE domain = 'activity' AND id = 'ski';
UPDATE public.catalog_entries SET data = data || jsonb_build_object('alias', '["campeggio","tenda","camping","tent"]'::jsonb)
  WHERE domain = 'activity' AND id = 'camping';
UPDATE public.catalog_entries SET data = data || jsonb_build_object('alias', '["lavoro","riunioni","work","business"]'::jsonb)
  WHERE domain = 'activity' AND id = 'work';
UPDATE public.catalog_entries SET data = data || jsonb_build_object('alias', '["cene","cena","serate","serata","dinner","evening"]'::jsonb)
  WHERE domain = 'activity' AND id = 'evenings';
UPDATE public.catalog_entries SET data = data || jsonb_build_object('alias', '["matrimonio","matrimoni","cerimonia","cerimonie","wedding","ceremony"]'::jsonb)
  WHERE domain = 'activity' AND id = 'wedding';
UPDATE public.catalog_entries SET data = data || jsonb_build_object('alias', '["culto","chiesa","chiese","worship","church"]'::jsonb)
  WHERE domain = 'activity' AND id = 'worship';
UPDATE public.catalog_entries SET data = data || jsonb_build_object('alias', '["terme","spa","benessere","wellness"]'::jsonb)
  WHERE domain = 'activity' AND id = 'spa';
