// trip-weather: il clima di un viaggio, per tappa e unito. Lo usa pack-trip
// per il generatore e l'app per i viaggi creati a mano (clima per tappa).
//
// POST { trip: { data_inizio: "AAAA-MM-GG", giorni, destinazione: {nome, paese,
//   lat, lon} } } oppure { trip: { data_inizio, tappe: [{nome, paese, lat, lon,
//   giorni}] } }  ->  { geo, meteo }
// meteo: previsione entro 14 giorni dalla fine del viaggio, normali climatiche
// (cinque anni di archivio ERA5) oltre; nei viaggi a tappe meteo._per_tappa e
// geo.per_tappa[i].meteo danno il dettaglio di ogni tappa.
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import { climaViaggio } from "../_shared/clima/meteo.ts";
import { IngressoNonValido, validaViaggio } from "../_shared/valigia/ingresso.ts";
import { consumaUso, corpo, CORS_HEADERS, errore, json, serviziMeteo, utente } from "../_shared/servizi.ts";

// Ogni viaggio nuovo costa a Open-Meteo da 2 a ~50 richieste (5 anni x tappe):
// tetto per utente, le risposte gia' in cache non lo consumano meno.
const TETTO_GIORNALIERO = 100;

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

  let viaggio;
  try {
    viaggio = validaViaggio(b.trip, new Date().toISOString().slice(0, 10), false);
  } catch (e) {
    if (e instanceof IngressoNonValido) return errore(400, e.message);
    throw e;
  }

  const ok = await consumaUso(db, u.id, "trip-weather", TETTO_GIORNALIERO, 60 * 24);
  if (ok instanceof Response) return ok;
  if (!ok) return errore(429, "Weather rate limit reached");

  try {
    const r = await climaViaggio(viaggio.data_inizio, viaggio.giorni, viaggio.destinazione ?? null,
      viaggio.tappe ?? null, serviziMeteo(db, Deno.env.get("OPEN_METEO_API_KEY") || undefined));
    return json(200, r);
  } catch (e) {
    console.error("[trip-weather]", (e as Error).message);
    return errore(502, "Weather upstream error");
  }
});
