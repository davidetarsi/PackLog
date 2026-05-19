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
  throw new Error("Missing required env vars: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
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
  if (req.method !== "POST") {
    return errorResponse(405, "Method not allowed");
  }

  // 1. Verify JWT
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return errorResponse(401, "Missing authorization");

  const {
    data: { user },
    error: authError,
  } = await supabaseAdmin.auth.getUser(authHeader.startsWith("Bearer ") ? authHeader.slice(7) : authHeader);
  if (authError || !user) return errorResponse(401, "Invalid token");

  // 2. Atomic cap check + increment (TOCTOU-safe via SQL function)
  const { data: allowed, error: rpcError } = await supabaseAdmin.rpc(
    "increment_gpt_count",
    { p_user_id: user.id, p_now: new Date().toISOString() },
  );
  if (rpcError) {
    console.error("increment_gpt_count failed", rpcError.message);
    return errorResponse(500, "Usage check failed");
  }
  if (!allowed) return errorResponse(429, "Monthly GPT limit reached");

  // 3. Forward to OpenAI with compensating transaction on error
  const apiKey = Deno.env.get("OPENAI_KEY");
  if (!apiKey) {
    const { error: decrementError } = await supabaseAdmin.rpc("decrement_gpt_count", { p_user_id: user.id });
    if (decrementError) console.error("COUNTER_ROLLBACK_FAILED", { userId: user.id, error: decrementError.message });
    return errorResponse(500, "OPENAI_KEY not configured");
  }

  try {
    const body = await req.text();
    const response = await fetch(
      "https://api.openai.com/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body,
      },
    );

    if (!response.ok) {
      const { error: decrementError } = await supabaseAdmin.rpc("decrement_gpt_count", { p_user_id: user.id });
      if (decrementError) console.error("COUNTER_ROLLBACK_FAILED", { userId: user.id, error: decrementError.message });
      const errorText = await response.text();
      // Map OpenAI 429 (API rate limit) to 503 to avoid confusion with the user's monthly cap (our 429)
      const mappedStatus = response.status === 429 ? 503 : response.status;
      return errorResponse(mappedStatus, `OpenAI error: ${errorText}`);
    }

    const data = await response.text();
    return new Response(data, {
      status: response.status,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("OpenAI fetch failed", error);
    const { error: decrementError } = await supabaseAdmin.rpc("decrement_gpt_count", { p_user_id: user.id });
    if (decrementError) console.error("COUNTER_ROLLBACK_FAILED", { userId: user.id, error: decrementError.message });
    return errorResponse(500, "Network error communicating with AI provider");
  }
});
