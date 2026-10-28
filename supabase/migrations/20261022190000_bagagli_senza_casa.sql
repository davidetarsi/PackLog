-- Applicare prima di distribuire il client con schema locale v11.
-- Mantiene ID, eventuali case legacy e collegamenti JSONB dei viaggi.
BEGIN;

ALTER TABLE public.luggages ALTER COLUMN house_id DROP NOT NULL;
ALTER TABLE public.luggages DROP CONSTRAINT IF EXISTS luggages_house_id_fkey;
ALTER TABLE public.luggages
  ADD CONSTRAINT luggages_house_id_fkey
  FOREIGN KEY (house_id) REFERENCES public.houses(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.luggages.house_id IS
  'Casa legacy opzionale. Il bagaglio appartiene all''utente e resta disponibile senza casa.';

COMMIT;
