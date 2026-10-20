// item-metadata: la scheda dei capi per l'app, dal nome (aggiunta a mano) o da
// una foto (scan). GPT riempie la scheda, il codice la pulisce (valori ammessi,
// categoria dalla sottocategoria), Jev controlla i campi che l'utente vede.
// Porting di scheda_capo.py del bench (oracolo in _shared/capi/test).
//
// POST { name: "pantaloni da trekking decathlon" }  oppure  { image_base64 }
//   -> { items: [{ metadata, app_category, dubbi }], note_tecniche }
// metadata: da salvare in items.ai_metadata (con waterResistance e bulk);
// app_category: items.category (vestiti, varie, toiletries, elettronica);
// dubbi: etichette da chiedere ("?"), [] = niente da chiedere.
//
// Sostituisce openai-proxy, che resta finche' l'app non passa a questa funzione:
// la foto consuma lo stesso tetto (users.gpt_usage_cap).
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import { openaiScheda, RispostaIlleggibile, schedaDaNome, schedeDaFoto } from "../_shared/capi/analisi.ts";
import { pulisciNome } from "../_shared/capi/scheda.ts";
import { jevHttp } from "../_shared/valigia/jev.ts";
import { consumaUso, corpo, CORS_HEADERS, errore, json, tetto, utente } from "../_shared/servizi.ts";

// Un nome costa circa due decimi di millesimo di dollaro (GPT + Jev): il tetto
// difende dagli abusi. Predefinito: riga 'item_name_daily_cap' di public.app_config.
const TETTO_NOMI_GIORNALIERO = 200;
// ~6 MB di base64 (~4,5 MB di immagine), come openai-proxy.
const MAX_IMMAGINE_BASE64 = 6 * 1024 * 1024;

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!supabaseUrl || !serviceKey) {
  throw new Error("Missing required env vars: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}
const db = createClient(supabaseUrl, serviceKey);

/** Errore di OpenAI -> risposta: il 429 di OpenAI diventa 503, per non
 *  confonderlo col tetto dell'utente (429). */
function erroreModello(e: unknown, tipo: string): Response {
  console.error(`[item-metadata] ${tipo}:`, (e as Error).message);
  if (e instanceof RispostaIlleggibile) return errore(502, "Unreadable AI response");
  const status = (e as { status?: number }).status;
  return errore(status === 429 ? 503 : 502, "AI upstream error");
}

async function restituisciUsoGpt(userId: string) {
  const { error } = await db.rpc("decrement_gpt_usage", { p_user_id: userId });
  if (error) console.error("[item-metadata] COUNTER_ROLLBACK_FAILED:", error.message);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return errore(405, "Method not allowed");

  const u = await utente(db, req);
  if (u instanceof Response) return u;
  const b = await corpo(req, MAX_IMMAGINE_BASE64 + 1024);
  if (b instanceof Response) return b;

  const chiaveOpenai = Deno.env.get("OPENAI_KEY");
  if (!chiaveOpenai) return errore(500, "OPENAI_KEY not configured");
  const chiaveJev = Deno.env.get("TYPESAFE_API_KEY");
  const servizi = { gpt: openaiScheda(chiaveOpenai), jev: chiaveJev ? jevHttp(chiaveJev) : null };

  const conNome = "name" in b, conFoto = "image_base64" in b;
  if (conNome === conFoto) return errore(400, "Send exactly one of 'name' or 'image_base64'");

  if (conNome) {
    if (typeof b.name !== "string" || !pulisciNome(b.name)) return errore(400, "'name' must be a non-empty string");
    const ok = await consumaUso(db, u.id, "item-name",
      await tetto(db, "item_name_daily_cap", TETTO_NOMI_GIORNALIERO), 60 * 24);
    if (ok instanceof Response) return ok;
    if (!ok) return errore(429, "Item name rate limit reached");
    try {
      const r = await schedaDaNome(b.name, servizi);
      for (const n of r.note_tecniche) console.warn("[item-metadata]", n);
      return json(200, r);
    } catch (e) {
      return erroreModello(e, "name");
    }
  }

  const immagine = b.image_base64;
  if (typeof immagine !== "string" || !immagine.length) return errore(400, "'image_base64' must be a non-empty string");
  if (immagine.length > MAX_IMMAGINE_BASE64) return errore(413, "Image too large");
  // Lo stesso tetto a vita di openai-proxy (atomico, lato SQL).
  const { data: permesso, error } = await db.rpc("increment_gpt_usage", { p_user_id: u.id });
  if (error) {
    console.error("[item-metadata] increment_gpt_usage RPC error:", error.message, error.code);
    return errore(500, "Usage check failed");
  }
  if (!permesso) return errore(429, "GPT usage limit reached");
  try {
    const r = await schedeDaFoto(immagine, servizi);
    for (const n of r.note_tecniche) console.warn("[item-metadata]", n);
    return json(200, r);
  } catch (e) {
    await restituisciUsoGpt(u.id);
    return erroreModello(e, "image");
  }
});
