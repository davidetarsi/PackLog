// item-metadata: la scheda dei capi per l'app, dal nome (aggiunta a mano) o da
// una foto (scan). Claude Haiku 5.5 riempie la scheda, il codice la pulisce
// (valori ammessi, categoria dalla sottocategoria), Jev controlla i campi che
// l'utente vede.
// Porting di scheda_capo.py del bench (oracolo in _shared/capi/test).
//
// POST { name: "pantaloni da trekking decathlon" }  oppure  { image_base64 }
//   -> { items: [{ metadata, app_category, dubbi }], note_tecniche }
// metadata: da salvare in items.ai_metadata (con waterResistance e bulk);
// app_category: items.category (vestiti, varie, toiletries, elettronica);
// dubbi: etichette da chiedere ("?"), [] = niente da chiedere.
//
// Sostituisce openai-proxy, che resta finche' l'app non passa a questa funzione.
// La foto consuma un credito AI (quota mensile + crediti extra, come la valigia);
// il nome no: costa pochissimo e ha solo un limite giornaliero contro gli abusi,
// che l'app non mostra.
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import { RispostaIlleggibile, schedaDaNome, schedeDaFoto } from "../_shared/capi/analisi.ts";
import { pulisciNome } from "../_shared/capi/scheda.ts";
import { claudeHttp, type Contenuto } from "../_shared/claude.ts";
import { jevHttp } from "../_shared/valigia/jev.ts";
import {
  consumaCreditoAi, consumaUso, corpo, CORS_HEADERS, errore, json, restituisciCreditoAi, tetto, utente,
} from "../_shared/servizi.ts";

// Un nome costa circa due decimi di millesimo di dollaro (Claude + Jev): il
// tetto difende dagli abusi. Predefinito: riga 'item_name_daily_cap' di public.app_config.
const TETTO_NOMI_GIORNALIERO = 50;
// ~6 MB di base64 (~4,5 MB di immagine), come openai-proxy.
const MAX_IMMAGINE_BASE64 = 6 * 1024 * 1024;

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!supabaseUrl || !serviceKey) {
  throw new Error("Missing required env vars: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}
const db = createClient(supabaseUrl, serviceKey);

/** Errore del modello -> risposta: il 429 di Anthropic diventa 503, per non
 *  confonderlo col tetto dell'utente (429). */
function erroreModello(e: unknown, tipo: string): Response {
  console.error(`[item-metadata] ${tipo}:`, (e as Error).message);
  if (e instanceof RispostaIlleggibile) return errore(502, "Unreadable AI response");
  const status = (e as { status?: number }).status;
  return errore(status === 429 ? 503 : 502, "AI upstream error");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return errore(405, "Method not allowed");

  const u = await utente(db, req);
  if (u instanceof Response) return u;
  const b = await corpo(req, MAX_IMMAGINE_BASE64 + 1024);
  if (b instanceof Response) return b;

  const chiaveClaude = Deno.env.get("ANTHROPIC_API_KEY");
  if (!chiaveClaude) return errore(500, "ANTHROPIC_API_KEY not configured");
  const chiaveJev = Deno.env.get("TYPESAFE_API_KEY");
  const claude = claudeHttp(chiaveClaude);
  const servizi = {
    modello: async (contenuto: unknown, maxTokens: number) => (await claude(contenuto as Contenuto, maxTokens)).testo,
    jev: chiaveJev ? jevHttp(chiaveJev) : null,
  };

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
  const consumo = await consumaCreditoAi(db, u.id);
  if (consumo instanceof Response) return consumo;
  if (!consumo) return errore(429, "AI usage limit reached");
  try {
    const r = await schedeDaFoto(immagine, servizi);
    for (const n of r.note_tecniche) console.warn("[item-metadata]", n);
    return json(200, r);
  } catch (e) {
    await restituisciCreditoAi(db, u.id, consumo);
    return erroreModello(e, "image");
  }
});
