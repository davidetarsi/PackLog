-- Tappe intermedie del viaggio (schema locale 10).
--
-- Nullable e senza default, non `NOT NULL DEFAULT '[]'`: il pull distingue i
-- due casi. `null` significa "questa riga è anteriore allo schema 10, nessuna
-- informazione" e lascia intatte le tappe locali; `[]` significa "l'utente ha
-- rimosso tutte le tappe" e le azzera. Con un default a `[]` ogni riga
-- esistente direbbe la seconda cosa, e un pull cancellerebbe tappe che
-- nessuno ha toccato.
-- Vedi lib/core/sync/sync_serializers.dart.
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS legs jsonb;
