import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

// Input validation thresholds — allineati al client (`limit: 15`, query
// realistiche di città/via ben sotto i 100 caratteri).
const MAX_TEXT_LENGTH = 100;
const MAX_LIMIT = 15;

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "GET") {
    return errorResponse(405, "Method not allowed");
  }

  // 1. Verify JWT esplicitamente (defense in depth: il gateway lo verifica
  //    già, ma vogliamo lo `user.id` per il rate-limit per-utente).
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return errorResponse(401, "Missing authorization");

  const {
    data: { user },
    error: authError,
  } = await supabaseAdmin.auth.getUser(
    authHeader.startsWith("Bearer ") ? authHeader.slice(7) : authHeader,
  );
  if (authError || !user) return errorResponse(401, "Invalid token");

  // 2. Input validation
  const apiKey = Deno.env.get("GEOAPIFY_KEY");
  if (!apiKey) {
    return errorResponse(500, "GEOAPIFY_KEY not configured");
  }

  const url = new URL(req.url);
  const text = url.searchParams.get("text");
  const lang = url.searchParams.get("lang") ?? "en";
  const limitParam = url.searchParams.get("limit") ?? "15";
  const bias = url.searchParams.get("bias") ?? "countrycode:none";

  if (!text) {
    return errorResponse(400, "Missing 'text' parameter");
  }
  if (text.length > MAX_TEXT_LENGTH) {
    return errorResponse(
      400,
      `'text' too long (max ${MAX_TEXT_LENGTH} characters)`,
    );
  }
  const limit = parseInt(limitParam, 10);
  if (!Number.isFinite(limit) || limit <= 0 || limit > MAX_LIMIT) {
    return errorResponse(
      400,
      `'limit' must be a positive integer up to ${MAX_LIMIT}`,
    );
  }
  // `lang` sanity: codice ISO-639 ~2 char. Più di 8 char è certamente abuso.
  if (lang.length > 8) {
    return errorResponse(400, "'lang' too long");
  }

  // 3. Atomic rate-limit check (TOCTOU-safe via SQL function).
  //    Default: 100 richieste / 60 minuti — vedi increment_geocode_count.
  const p_now = new Date().toISOString();
  const { data: allowed, error: rpcError } = await supabaseAdmin.rpc(
    "increment_geocode_count",
    { p_user_id: user.id, p_now },
  );
  if (rpcError) {
    console.error(
      "[geocode-proxy] increment_geocode_count RPC error:",
      rpcError.message,
      rpcError.code,
    );
    return errorResponse(500, "Rate-limit check failed");
  }
  if (!allowed) {
    return errorResponse(429, "Geocode rate limit reached");
  }

  // 4. Forward to Geoapify. Nessuna compensating transaction sul counter:
  //    il fail di Geoapify per noi è equivalente al successo dal punto di
  //    vista del rate-limit (l'utente ha comunque consumato uno slot),
  //    perché altrimenti spammare query malformate diventerebbe gratis.
  const geoapifyUrl = new URL(
    "https://api.geoapify.com/v1/geocode/autocomplete",
  );
  geoapifyUrl.searchParams.set("text", text);
  geoapifyUrl.searchParams.set("apiKey", apiKey);
  geoapifyUrl.searchParams.set("lang", lang);
  geoapifyUrl.searchParams.set("limit", limit.toString());
  geoapifyUrl.searchParams.set("bias", bias);

  try {
    const response = await fetch(geoapifyUrl.toString());
    const data = await response.text();
    return new Response(data, {
      status: response.status,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("[geocode-proxy] Geoapify fetch failed:", error);
    return errorResponse(502, "Geoapify upstream error");
  }
});
