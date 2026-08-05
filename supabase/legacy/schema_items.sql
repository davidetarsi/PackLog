-- Items table: schema Supabase (speculare alla tabella Drift locale)
-- Esegui in Supabase Dashboard → SQL Editor

-- Versione iniziale (corrisponde a schemaVersion 6+ nel DB locale)
-- CREATE TABLE public.items (
--   id               text        PRIMARY KEY,
--   user_id          uuid        REFERENCES auth.users(id) ON DELETE CASCADE,
--   house_id         text        NOT NULL,
--   name             text        NOT NULL,
--   category         text        NOT NULL,
--   description      text,
--   quantity         integer,
--   space_id         text,
--   created_at       timestamptz NOT NULL,
--   updated_at       timestamptz NOT NULL,
--   is_deleted       boolean     NOT NULL DEFAULT false,
--   last_synced_at   timestamptz,
--   sync_status      integer     NOT NULL DEFAULT 1,
--   sync_retry_count integer     NOT NULL DEFAULT 0,
--   last_sync_error  text,
--   sentry_trace_id  text,
--   next_sync_attempt_at timestamptz
-- );

-- ─────────────────────────────────────────────────────────────────────────────
-- Migration: schemaVersion 8 → 9 (2026-05-20)
-- Aggiunge metadati AI generati da GPT-4o Vision.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.items ADD COLUMN IF NOT EXISTS ai_metadata TEXT;
