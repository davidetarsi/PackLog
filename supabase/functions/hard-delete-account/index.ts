import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Initialized outside handler for reuse in warm invocations
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!supabaseUrl || !serviceKey) {
  throw new Error(
    "Missing required env vars: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY",
  );
}
const supabaseAdmin = createClient(supabaseUrl, serviceKey);

function errorResponse(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

/**
 * GDPR Article 17 — Right to Erasure
 *
 * Cancella HARD (DELETE fisico, non soft-delete) tutti i dati dell'utente
 * autenticato e l'account stesso. Effetto irreversibile.
 *
 * Differenza con la soft-delete normale:
 *   - Soft-delete (`isDeleted = true`): viaggia via sync e viene purgata
 *     dopo `tombstone_retention_days` (default 15g) → troppo lento per GDPR.
 *   - Hard-delete (questo endpoint): DELETE immediato + cancellazione
 *     `auth.users` → cascade su tutto via FK. Tempo di completamento: secondi.
 *
 * Sicurezza:
 *   - JWT verificato esplicitamente (oltre al gateway). Lo `user.id` per
 *     la cancellazione viene dal JWT decoded server-side, MAI da body o
 *     params: un client malizioso non può cancellare account altrui.
 *   - `SERVICE_ROLE_KEY` necessaria solo perché DELETE su `auth.users`
 *     richiede privilegi admin; le 5 tabelle dati sarebbero accessibili
 *     anche al ruolo `authenticated` via RLS, ma usiamo service_role per
 *     uniformità e per registrare un audit chiaro.
 *
 * Returns: { deleted: { houses, items, spaces, luggages, trips, users } }
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return errorResponse(405, "Method not allowed");
  }

  // 1. Verify JWT esplicitamente
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return errorResponse(401, "Missing authorization");

  const {
    data: { user },
    error: authError,
  } = await supabaseAdmin.auth.getUser(
    authHeader.startsWith("Bearer ") ? authHeader.slice(7) : authHeader,
  );
  if (authError || !user) return errorResponse(401, "Invalid token");

  const userId = user.id;
  console.log("[hard-delete] starting deletion for user_id:", userId);

  // 2. DELETE su tabelle dati. Ordine reverse-FK: figli prima dei padri.
  //    items dipende da houses+spaces; spaces+luggages+trips dipendono da
  //    houses. Quindi: items → spaces → luggages → trips → houses.
  //    Per ogni tabella usiamo `.select('id', { head: true, count: 'exact' })`
  //    DOPO la delete per ottenere la conta (utile per audit/debug).
  //
  //    Nota: usiamo service_role → RLS bypassata. Affidiamo l'isolamento
  //    user_id al filtro `.eq('user_id', userId)`, NON a RLS. Questo è
  //    intenzionale: con RLS attiva e service_role bypass, dobbiamo
  //    duplicare il check per evitare wipe accidentali cross-tenant.
  const deleted: Record<string, number> = {};

  for (const table of ["items", "spaces", "luggages", "trips", "houses"]) {
    try {
      const { count, error } = await supabaseAdmin
        .from(table)
        .delete({ count: "exact" })
        .eq("user_id", userId);
      if (error) {
        console.error(`[hard-delete] DELETE ${table} failed:`, error.message);
        return errorResponse(500, `Failed to delete ${table}: ${error.message}`);
      }
      deleted[table] = count ?? 0;
    } catch (e) {
      console.error(`[hard-delete] DELETE ${table} exception:`, e);
      return errorResponse(500, `Failed to delete ${table}`);
    }
  }

  // `users` ha PRIMARY KEY uguale a user_id, quindi tecnicamente verrebbe
  // cancellata da CASCADE ON DELETE quando cancelliamo auth.users. La
  // cancelliamo prima esplicitamente per l'audit (vogliamo sapere quante
  // righe c'erano). Cancellare questa riga porta via anche i contatori di
  // usage GPT e geocode, che vivono come colonne su public.users (la vecchia
  // tabella dedicata public.geocode_usage non esiste più — vedi
  // migration_2026-07-30_geocode_users.sql).
  try {
    const { count, error } = await supabaseAdmin
      .from("users")
      .delete({ count: "exact" })
      .eq("id", userId);
    if (error) {
      console.error("[hard-delete] DELETE users failed:", error.message);
    }
    deleted["users"] = count ?? 0;
  } catch (e) {
    console.error("[hard-delete] DELETE users exception:", e);
  }

  // 3. Cancella l'account auth. Da qui in poi qualsiasi JWT esistente
  //    diventa invalido (i refresh successivi falliranno con
  //    "User not found"). Idempotente: se l'account è già stato cancellato,
  //    Supabase ritorna errore — lo logghiamo ma non blocchiamo la response.
  const { error: deleteAuthError } = await supabaseAdmin.auth.admin.deleteUser(
    userId,
  );
  if (deleteAuthError) {
    console.error(
      "[hard-delete] deleteUser failed:",
      deleteAuthError.message,
    );
    return errorResponse(
      500,
      `Auth account deletion failed: ${deleteAuthError.message}`,
    );
  }

  console.log("[hard-delete] success for user_id:", userId, "counts:", deleted);
  return new Response(JSON.stringify({ deleted }), {
    status: 200,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
});
