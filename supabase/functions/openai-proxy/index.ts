import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ── Hard-coded server-side parameters ────────────────────────────────────────
// Il client può cambiare i propri sorgenti — quindi ogni parametro che impatta
// costo / modello / output deve vivere QUI, non nel body. Il proxy accetta dal
// client SOLO l'immagine; tutto il resto è fisso.

const OPENAI_MODEL = "gpt-4o";
const OPENAI_MAX_TOKENS = 1500;
const OPENAI_TEMPERATURE = 0.0;
const OPENAI_IMAGE_DETAIL = "high";

// Limite difensivo sul payload immagine: ~6 MB di base64 ≈ ~4.5 MB di binario.
// `image_picker` lato client comprime già a quality 80 → tipicamente sotto 1 MB.
const MAX_IMAGE_BASE64_LENGTH = 6 * 1024 * 1024;

// Identico al prompt che prima viveva client-side. Spostato qui per impedire
// che un utente lo modifichi e usi il proxy come ChatGPT generico.
const SYSTEM_PROMPT = `
You are a precise fashion item parser. Analyze the image and identify ALL distinct clothing items currently WORN by the PRIMARY person in the foreground.
CRITICAL RULES:
- IGNORE any clothing items in the background (e.g., clothes on beds, chairs, hangers).
- Focus ONLY on the main subject's outfit.
Respond ONLY with a raw JSON array of objects — no markdown, no code fences.
Each object must have EXACTLY these keys:
- "name": string (Short descriptive name in Italian, e.g. "Giacca in pelle", "Jeans slim")
- "category": string (ONE OF: "Upper Body", "Lower Body", "Shoes", "Outerwear", "Accessory")
- "subCategory": string (ONE OF based on category:
  Upper Body → "T-Shirt", "Shirt", "Polo", "Hoodie", "Sweatshirt", "Sweater", "Tank Top", "Crop Top"
  Lower Body → "Jeans", "Shorts", "Trousers", "Leggings", "Skirt", "Sweatpants", "Swimwear"
  Shoes → "Sneakers", "Sandals", "Boots", "Flip-Flops", "Loafers", "Dress Shoes", "Hiking Boots"
  Outerwear → "Coat", "Rain Jacket", "Down Jacket", "Windbreaker", "Blazer"
  Accessory → "Cap/Hat", "Belt", "Bag", "Scarf", "Sunglasses", "Jewelry", "Watch")
- "baseColor": string (Primary color in Italian, e.g. "Nero", "Bianco", "Blu navy")
- "pattern": string (ONE OF: "Solid", "Striped", "Plaid", "Graphic", "Logo", "Floral", "Other")
- "coverage": string (ONE OF: "Short-sleeve", "Long-sleeve", "Sleeveless", "Shorts", "Full-length", "Cropped", "N/A")
- "fit": string (ONE OF: "Skinny", "Regular", "Oversize", "N/A")
- "warmth": integer (1 to 5: 1=canottiera/sandali, 2=t-shirt/sneakers, 3=felpa/jeans, 4=cappotto/stivali, 5=piumino/scarponi)
- "formality": string (ONE OF: "Loungewear", "Casual", "Smart Casual", "Business", "Formal")
- "activityTags": array of 1-3 strings (ONLY from: ["Everyday", "Office", "Beach", "Swimming", "Hiking", "Sport", "Formal", "Lounge"])
`.trim();

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
  if (req.method !== "POST") {
    return errorResponse(405, "Method not allowed");
  }

  // 1. Verify JWT
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return errorResponse(401, "Missing authorization");

  const {
    data: { user },
    error: authError,
  } = await supabaseAdmin.auth.getUser(
    authHeader.startsWith("Bearer ") ? authHeader.slice(7) : authHeader,
  );
  if (authError || !user) return errorResponse(401, "Invalid token");

  console.log("[proxy] user_id:", user.id);

  // 2. Parse + validate body. Accettiamo SOLO `{ image_base64: string }`.
  //    Tutti gli altri campi (model, prompt, max_tokens) sono ignorati per
  //    design: il proxy decide la spesa, non il client.
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return errorResponse(400, "Invalid JSON body");
  }
  if (typeof body !== "object" || body === null) {
    return errorResponse(400, "Body must be a JSON object");
  }
  const imageBase64 = (body as Record<string, unknown>).image_base64;
  if (typeof imageBase64 !== "string" || imageBase64.length === 0) {
    return errorResponse(400, "Missing 'image_base64' string field");
  }
  if (imageBase64.length > MAX_IMAGE_BASE64_LENGTH) {
    return errorResponse(413, "Image too large");
  }

  // 3. Atomic cap check + increment (TOCTOU-safe via SQL function)
  const p_now = new Date().toISOString();
  console.log("[proxy] calling increment_gpt_count, p_now:", p_now);
  const { data: allowed, error: rpcError } = await supabaseAdmin.rpc(
    "increment_gpt_count",
    { p_user_id: user.id, p_now },
  );
  if (rpcError) {
    console.error(
      "[proxy] increment_gpt_count RPC error:",
      rpcError.message,
      rpcError.code,
    );
    return errorResponse(500, "Usage check failed");
  }
  console.log("[proxy] increment_gpt_count returned:", allowed);
  if (!allowed) return errorResponse(429, "Monthly GPT limit reached");

  // 4. Build the OpenAI payload server-side. Il body al client non è mai
  //    inoltrato — solo l'immagine viene riusata.
  const apiKey = Deno.env.get("OPENAI_KEY");
  if (!apiKey) {
    console.error("[proxy] DECREMENT reason: OPENAI_KEY not configured");
    const { error: decrementError } = await supabaseAdmin.rpc(
      "decrement_gpt_count",
      { p_user_id: user.id },
    );
    if (decrementError) {
      console.error(
        "[proxy] COUNTER_ROLLBACK_FAILED:",
        decrementError.message,
      );
    }
    return errorResponse(500, "OPENAI_KEY not configured");
  }

  const openAiBody = JSON.stringify({
    model: OPENAI_MODEL,
    max_tokens: OPENAI_MAX_TOKENS,
    temperature: OPENAI_TEMPERATURE,
    messages: [
      {
        role: "user",
        content: [
          { type: "text", text: SYSTEM_PROMPT },
          {
            type: "image_url",
            image_url: {
              url: `data:image/png;base64,${imageBase64}`,
              detail: OPENAI_IMAGE_DETAIL,
            },
          },
        ],
      },
    ],
  });

  try {
    const response = await fetch(
      "https://api.openai.com/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: openAiBody,
      },
    );

    console.log("[proxy] OpenAI status:", response.status);

    if (!response.ok) {
      const errorText = await response.text();
      console.error(
        "[proxy] DECREMENT reason: OpenAI non-2xx",
        response.status,
        errorText.slice(0, 200),
      );
      const { error: decrementError } = await supabaseAdmin.rpc(
        "decrement_gpt_count",
        { p_user_id: user.id },
      );
      if (decrementError) {
        console.error(
          "[proxy] COUNTER_ROLLBACK_FAILED:",
          decrementError.message,
        );
      }
      // Map OpenAI 429 (API rate limit) to 503 to avoid confusion with the
      // user's monthly cap (our 429)
      const mappedStatus = response.status === 429 ? 503 : response.status;
      return errorResponse(mappedStatus, `OpenAI error: ${errorText}`);
    }

    const data = await response.text();
    console.log("[proxy] success, response length:", data.length);
    return new Response(data, {
      status: response.status,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("[proxy] DECREMENT reason: fetch exception:", error);
    const { error: decrementError } = await supabaseAdmin.rpc(
      "decrement_gpt_count",
      { p_user_id: user.id },
    );
    if (decrementError) {
      console.error("[proxy] COUNTER_ROLLBACK_FAILED:", decrementError.message);
    }
    return errorResponse(500, "Network error communicating with AI provider");
  }
});
