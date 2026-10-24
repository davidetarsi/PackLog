// pack-trip: la valigia di un viaggio dall'armadio di una casa dell'utente.
// Porting del generatore del bench (AI-checklist-test-script, verificato con
// gli oracoli in _shared/*/test): una chiamata a Claude Haiku 5.5, Jev in parallelo
// (profilo dei capi, voti, classificazione del viaggio), il meteo del viaggio,
// poi il codice sceglie i capi e spiega perche'.
//
// POST { house_id, trip: { data_inizio, giorni, destinazione: {nome, paese, lat,
//   lon} | tappe: [{nome, paese, lat, lon, giorni, attivita, alloggio, lavatrice}],
//   attivita, bagaglio, alloggio, lavatrice } }
//   -> { valigia, motivi, perche, geo, meteo, note_tecniche, capi, avvisi }
// Alloggio e lavatrice stanno per tappa (alloggio testo, lavatrice booleano); il
// viaggio li ricava dalle tappe, o usa i propri se mandati (formato vecchio).
// valigia: ideali, ripieghi, essenziali, mancanti, ...; motivi: un motivo per
// capo; perche: la scheda "Perche' queste scelte"; note_tecniche: cio' che non ha
// risposto (Jev e' un aiuto, la valigia si fa lo stesso); capi e avvisi: l'uscita
// per l'app (uscita.ts), con il tetto sulle copie che l'utente ha in armadio.
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import { climaViaggio } from "../_shared/clima/meteo.ts";
import { claudeHttp } from "../_shared/claude.ts";
import { conRiprova, generaValigia, MAX_TOKENS_VALIGIA, scenarioDaApp } from "../_shared/valigia/genera.ts";
import { IngressoNonValido, validaViaggio } from "../_shared/valigia/ingresso.ts";
import { jevHttp, MODELLO as MODELLO_JEV, type ProfiloNoto } from "../_shared/valigia/jev.ts";
import { uscitaApp } from "../_shared/valigia/uscita.ts";
import type { RigaArmadio } from "../_shared/valigia/capo.ts";
import {
  consumaCreditoAi, corpo, CORS_HEADERS, errore, json, restituisciCreditoAi, serviziMeteo, utente,
} from "../_shared/servizi.ts";

// Una valigia consuma un credito AI, come una foto: quota mensile
// (ai_monthly_cap di public.app_config), poi i crediti extra dei codici promo.
const MAX_CAPI = 400;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
if (!supabaseUrl || !serviceKey) {
  throw new Error("Missing required env vars: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}
const db = createClient(supabaseUrl, serviceKey);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return errore(405, "Method not allowed");

  const u = await utente(db, req);
  if (u instanceof Response) return u;
  const b = await corpo(req);
  if (b instanceof Response) return b;

  const chiaveClaude = Deno.env.get("ANTHROPIC_API_KEY");
  if (!chiaveClaude) return errore(500, "ANTHROPIC_API_KEY not configured");
  const chiaveJev = Deno.env.get("TYPESAFE_API_KEY");

  if (typeof b.house_id !== "string" || !UUID.test(b.house_id)) return errore(400, "'house_id' non valido");
  let viaggio;
  try {
    viaggio = validaViaggio(b.trip, new Date().toISOString().slice(0, 10));
  } catch (e) {
    if (e instanceof IngressoNonValido) return errore(400, e.message);
    throw e;
  }

  // L'armadio: i capi della casa scelta, dell'utente, non cancellati. L'ordine
  // conta (a parita' di punteggio vince il primo, come nel bench): fisso.
  const { data: righe, error: errCapi } = await db.from("items")
    .select("id, name, category, house_id, ai_metadata, quantity")
    .eq("user_id", u.id).eq("house_id", b.house_id).eq("is_deleted", false)
    .order("created_at").order("id").limit(MAX_CAPI + 1);
  if (errCapi) {
    console.error("[pack-trip] items:", errCapi.message);
    return errore(500, "Wardrobe read failed");
  }
  if (!righe?.length) return errore(422, "Wardrobe is empty");
  if (righe.length > MAX_CAPI) return errore(422, `Wardrobe too large (max ${MAX_CAPI} items)`);
  // Quante copie ha l'utente di ogni capo: il tetto dell'uscita per l'app.
  const salvate = new Map<string, number | null>(
    righe.map((r: Record<string, any>) => [String(r.id), r.quantity ?? null]),
  );

  const consumo = await consumaCreditoAi(db, u.id);
  if (consumo instanceof Response) return consumo;
  if (!consumo) return errore(429, "AI usage limit reached");

  // I profili Jev gia' calcolati: valgono finche' la scheda del capo non cambia.
  const profiliNoti: Record<string, ProfiloNoto> = {};
  if (chiaveJev) {
    const { data, error } = await db.from("item_jev_profiles").select("item_id, card, answers")
      .eq("user_id", u.id).in("item_id", righe.map((r: RigaArmadio) => r.id));
    if (error) console.error("[pack-trip] profiles read:", error.message);
    for (const p of data ?? []) profiliNoti[p.item_id] = { scheda: p.card, risposte: p.answers };
  }

  const claude = claudeHttp(chiaveClaude);
  // Tutto quello che succede dopo il consumo, fino alla risposta, sta nel try: se
  // qualcosa salta, il credito si restituisce e la risposta e' un errore, non una valigia.
  let risposta: Response;
  try {
    const r = await generaValigia(scenarioDaApp(viaggio), righe as RigaArmadio[], {
      clima: () => climaViaggio(viaggio.data_inizio, viaggio.giorni, viaggio.destinazione ?? null,
        viaggio.tappe ?? null, serviziMeteo(db, Deno.env.get("OPEN_METEO_API_KEY") || undefined)),
      modello: conRiprova((prompt) => claude(prompt, MAX_TOKENS_VALIGIA)),
      jev: chiaveJev ? jevHttp(chiaveJev) : null,
      profiliNoti,
    });

    const nuovi = Object.entries(r.jev.profili_nuovi).map(([id, p]) => ({
      item_id: id, user_id: u.id, card: p.scheda, answers: p.risposte, model: MODELLO_JEV,
      updated_at: new Date().toISOString(),
    }));
    if (nuovi.length) {
      const { error } = await db.from("item_jev_profiles").upsert(nuovi);
      if (error) console.error("[pack-trip] profiles write:", error.message);
    }
    for (const e of r.jev.errori) console.warn("[pack-trip] jev:", e);

    const { raw: _raw, ...valigia } = r.valigia;
    risposta = json(200, {
      valigia, motivi: r.motivi, perche: r.perche, geo: r.geo, meteo: r.meteo,
      note_tecniche: r.jev.errori,
      ...uscitaApp(r.valigia, r.motivi as { capi: Record<string, any>[]; essenziali: Record<string, any>[] }, salvate),
    });
  } catch (e) {
    console.error("[pack-trip]", (e as Error).message);
    await restituisciCreditoAi(db, u.id, consumo);
    return errore(502, "Packing upstream error");
  }
  return risposta;
});
