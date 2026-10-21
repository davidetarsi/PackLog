// openai-proxy: lo scan delle foto per le app gia' installate (quelle nuove
// chiamano item-metadata). Da togliere quando non riceve piu' chiamate. Il nome resta per compatibilita': il modello
// ora e' Claude Haiku 5.5, ma la risposta ha ancora la busta di OpenAI
// ({ choices: [{ message: { content } }] }), che e' quella che l'app legge.
// Ogni foto consuma un credito AI (quota mensile + crediti extra).
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import { claudeHttp } from "../_shared/claude.ts";
import { bloccoImmagine } from "../_shared/immagine.ts";
import { consumaCreditoAi, restituisciCreditoAi } from "../_shared/servizi.ts";

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

// Il ragionamento di Claude Haiku 5.5 rientra in max_tokens (con gpt-4o-mini
// erano 1500).
const MAX_TOKENS = 4000;

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

  // 3. Un credito AI, atomico lato SQL (quota mensile, poi crediti extra).
  const consumo = await consumaCreditoAi(supabaseAdmin, user.id);
  if (consumo instanceof Response) return consumo;
  if (!consumo) return errorResponse(429, "AI usage limit reached");

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    console.error("[proxy] REFUND reason: ANTHROPIC_API_KEY not configured");
    await restituisciCreditoAi(supabaseAdmin, user.id, consumo);
    return errorResponse(500, "ANTHROPIC_API_KEY not configured");
  }

  // 4. Il messaggio si costruisce qui: dal client arriva solo l'immagine.
  try {
    const { testo } = await claudeHttp(apiKey)(
      [bloccoImmagine(imageBase64), { type: "text", text: SYSTEM_PROMPT }],
      MAX_TOKENS,
    );
    console.log("[proxy] success, response length:", testo.length);
    return new Response(
      JSON.stringify({ choices: [{ message: { role: "assistant", content: testo } }] }),
      { status: 200, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("[proxy] REFUND reason: model error:", (error as Error).message);
    await restituisciCreditoAi(supabaseAdmin, user.id, consumo);
    // Il 429 di Anthropic diventa 503, per non confonderlo col tetto
    // dell'utente (il nostro 429).
    const status = (error as { status?: number }).status;
    return errorResponse(status === 429 ? 503 : 502, "AI upstream error");
  }
});
