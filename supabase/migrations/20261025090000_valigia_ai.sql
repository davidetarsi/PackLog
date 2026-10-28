-- Valigia con AI (schema locale 12): risposte del foglio e valigia proposta.
-- Nullable e senza default, come legs: null vuol dire "riga senza dati", e il
-- pull non cancella quello che il telefono ha. Applicare prima di distribuire
-- il client con schema 12.
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS ai_packing_setup jsonb;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS ai_packing_result jsonb;
