-- Modifiche alla valigia proposta (spec del 8 novembre 2026, parti 1 e 2).
-- Un evento per ogni cosa che l'utente cambia alla proposta prima della
-- partenza. Nessun nome scritto dall'utente: solo la scheda dell'oggetto
-- (o tipo e livello di un posto) e il contesto del viaggio.
-- `id` e' generato sul telefono (UUID): un invio ripetuto non crea doppioni.
-- `trip_id` senza chiave esterna: il viaggio puo' essere cancellato dopo, la
-- riga resta; sparisce con l'account (ON DELETE CASCADE su user_id).
-- DA APPLICARE A MANO (Davide): non lo applica l'agente.

CREATE TABLE IF NOT EXISTS public.valigia_modifiche (
  id                  uuid        PRIMARY KEY,
  user_id             uuid        NOT NULL DEFAULT auth.uid()
                                  REFERENCES auth.users(id) ON DELETE CASCADE,
  trip_id             uuid        NOT NULL,
  -- SHA-256 esadecimale di "<viaggio>:<oggetto>" (o "<viaggio>:slot:<posto>"):
  -- stabile per lo stesso oggetto nello stesso viaggio, non risale al nome.
  chiave_oggetto      text        NOT NULL,
  creato_il           timestamptz NOT NULL,
  azione              text        NOT NULL CHECK (azione IN (
                        'aggiunto', 'tolto', 'copie',
                        'suggerimento_tolto', 'posto_riempito', 'da_comprare')),
  origine             text        NOT NULL CHECK (origine IN (
                        'proposta', 'posto', 'kit', 'utente')),
  copie_prima         integer,
  copie_dopo          integer,
  scheda              jsonb       NOT NULL DEFAULT '{}'::jsonb,
  contesto            jsonb       NOT NULL DEFAULT '{}'::jsonb,
  versione_generatore text,
  -- ConsentService.analyticsEnabled nel momento dell'evento: l'analisi
  -- d'insieme usa solo le righe con true.
  analisi_consentita  boolean     NOT NULL
);

CREATE INDEX IF NOT EXISTS valigia_modifiche_user_id_idx
  ON public.valigia_modifiche (user_id);
CREATE INDEX IF NOT EXISTS valigia_modifiche_creato_il_idx
  ON public.valigia_modifiche (creato_il);

-- ── RLS: solo insert e select sulle proprie righe ───────────────────────────
-- Nessuna policy update/delete: gli utenti non modificano ne' cancellano gli
-- eventi (la cancellazione avviene con l'account, via hard-delete-account).
ALTER TABLE public.valigia_modifiche ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Inserimento dei propri eventi valigia" ON public.valigia_modifiche;
CREATE POLICY "Inserimento dei propri eventi valigia"
  ON public.valigia_modifiche AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Lettura dei propri eventi valigia" ON public.valigia_modifiche;
CREATE POLICY "Lettura dei propri eventi valigia"
  ON public.valigia_modifiche AS PERMISSIVE FOR SELECT TO authenticated
  USING (user_id = auth.uid());
