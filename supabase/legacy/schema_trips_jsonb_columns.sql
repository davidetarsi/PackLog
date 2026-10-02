-- Aggiunge le colonne JSONB mancanti alla tabella trips.
--
-- L'app serializza items e luggage_ids nel payload del viaggio:
--   items      → snapshot immutabile degli item checklist (id, name, category,
--                quantity, origin_house_id, is_checked)
--   luggage_ids → array degli id dei bagagli associati al viaggio
--
-- Senza queste colonne Supabase risponde PGRST204 ("column not found in schema
-- cache") e il push fallisce con retry loop infinito.
--
-- Eseguire una sola volta sul progetto Supabase (SQL Editor o CLI migration).

ALTER TABLE public.trips
  ADD COLUMN IF NOT EXISTS items       JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS luggage_ids JSONB NOT NULL DEFAULT '[]'::jsonb;
