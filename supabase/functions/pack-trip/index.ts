// pack-trip: la valigia di un viaggio dall'armadio di una casa dell'utente.
// Porting del generatore del bench (AI-checklist-test-script, verificato con
// gli oracoli in _shared/*/test): una chiamata a Claude Haiku 5.5, Jev in parallelo
// (profilo dei capi, voti, classificazione del viaggio), il meteo del viaggio,
// poi il codice sceglie i capi e spiega perche'.
//
// POST { house_id, lang?, posti?, trip: { data_inizio, giorni, destinazione: {nome, paese, lat,
//   lon} | tappe: [{nome, paese, lat, lon, giorni, attivita, alloggio, lavatrice}],
//   attivita, bagaglio, alloggio, lavatrice } }
// lang: "it" | "en", la lingua dei testi per l'utente (motivi, perche, avvisi);
// senza, italiano come le versioni vecchie dell'app. Il prompt resta in italiano.
// posti: true = l'app sa mostrare i posti (valigia fatta di soli posti anche con
// l'armadio vuoto). Senza, un armadio vuoto e' 422 "Wardrobe is empty" prima del
// credito AI, come per le versioni vecchie, che ignorano i posti.
//   -> { valigia, motivi, perche, geo, meteo, note_tecniche, capi, avvisi, posti, informazioni, kit? }
// kit (facoltativo, app nuova): corpo `kit: [{ id, attivita, mezzi, oggetti: [{ item_id, copie }] }]` e
// `trip.mezzi` (id del dominio transport); la risposta ha `kit: { aggiunti: [{ kit_id, item_id, copie }],
// suggeriti: [{ kit_id, presi, totale, mancanti: [{ item_id, copie }] }] }` e i posti gia' ridotti (kit.ts).
// Senza `kit` nel corpo la risposta e' quella di sempre, senza il campo.
// Alloggio e lavatrice stanno per tappa (alloggio, lavatrice booleano); il
// viaggio li ricava dalle tappe, o usa i propri se mandati (formato vecchio).
// Attivita' e alloggio arrivano come id del catalogo (app nuova: "city",
// "friends", ...) oppure come testi gia' tradotti (app vecchia): li traduce
// il catalogo (_shared/catalogo) prima della validazione. Un id disattivato
// nel catalogo si traduce comunque: il viaggio vecchio tiene il suo significato.
// valigia: ideali, ripieghi, essenziali, mancanti, ...; motivi: un motivo per
// capo; perche: la scheda "Perche' queste scelte"; note_tecniche: cio' che non ha
// risposto (Jev e' un aiuto, la valigia si fa lo stesso); capi e avvisi: l'uscita
// per l'app (uscita.ts), con il tetto sulle copie che l'utente ha in armadio.
// posti: cio' che alla valigia manca (posti.ts): importanti (dipendono dal viaggio) e utili,
// con nome, copie e motivo; con `posti: true` l'armadio puo' essere anche vuoto, allora la valigia e' tutta posti.
// informazioni: cio' che l'utente deve sapere ma non e' un oggetto (bagaglio pieno, lavanderia).
import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "@supabase/supabase-js";
import { climaViaggio } from "../_shared/clima/meteo.ts";
import { claudeHttp } from "../_shared/claude.ts";
import { conRiprova, generaValigia, MAX_TOKENS_VALIGIA, scenarioDaApp } from "../_shared/valigia/genera.ts";
import { armadioVuotoAmmesso, attivitaGrezze, IngressoNonValido, validaKit, validaMezzi, validaViaggio } from "../_shared/valigia/ingresso.ts";
import { jevHttp, MODELLO as MODELLO_JEV, type ProfiloNoto } from "../_shared/valigia/jev.ts";
import { kitDelViaggio, riempiPostiConKit } from "../_shared/valigia/kit.ts";
import { postiApp } from "../_shared/valigia/posti.ts";
import { campoVersione } from "../_shared/valigia/costanti_app.ts";
import { uscitaApp } from "../_shared/valigia/uscita.ts";
import { caricaArmadio, type RigaArmadio } from "../_shared/valigia/capo.ts";
import { applicaCatalogo } from "../_shared/catalogo/applica.ts";
import { leggiCatalogo, traduciViaggio } from "../_shared/catalogo/catalogo.ts";
import { linguaDa } from "../_shared/lingua.ts";
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
  const lingua = linguaDa(b.lang);
  if (!lingua) return errore(400, "'lang' must be 'it' or 'en'");
  // Il catalogo di questa richiesta: tipi, usi e colori dell'armadio, e i testi
  // di attivita' e alloggi vengono da lui (spec del 31 ottobre, § 6.4).
  const catalogo = await leggiCatalogo(db);
  applicaCatalogo(catalogo);
  let viaggio, kit, mezzi: string[];
  try {
    viaggio = validaViaggio(traduciViaggio(b.trip, catalogo), new Date().toISOString().slice(0, 10));
    // I kit (app nuova): solo se il corpo li ha. Mezzi e attivita' restano id del catalogo.
    kit = validaKit(b.kit);
    mezzi = validaMezzi((b.trip as Record<string, unknown> | null)?.mezzi);
  } catch (e) {
    if (e instanceof IngressoNonValido) return errore(400, e.message);
    throw e;
  }

  // L'armadio: i capi della casa scelta, dell'utente, non cancellati. L'ordine
  // conta (a parita' di punteggio vince il primo, come nel bench): fisso.
  const { data: righeDb, error: errCapi } = await db.from("items")
    .select("id, name, category, house_id, ai_metadata, quantity")
    .eq("user_id", u.id).eq("house_id", b.house_id).eq("is_deleted", false)
    .order("created_at").order("id").limit(MAX_CAPI + 1);
  if (errCapi) {
    console.error("[pack-trip] items:", errCapi.message);
    return errore(500, "Wardrobe read failed");
  }
  const righe = righeDb ?? [];
  // Armadio vuoto: ammesso solo per l'app che chiede i posti (la valigia e' fatta
  // di soli posti, posti.ts); le versioni vecchie li ignorano, quindi 422 prima del credito.
  if (!righe.length && !armadioVuotoAmmesso(b)) return errore(422, "Wardrobe is empty");
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
  if (chiaveJev && righe.length) {
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
      lingua,
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
    const motiviApp = r.motivi as { capi: Record<string, any>[]; essenziali: Record<string, any>[] };
    const armadioApp = caricaArmadio(righe as RigaArmadio[]);
    const uscita = uscitaApp(r.valigia, motiviApp, salvate, {
      meteo: r.meteo as Record<string, any> | null, viaggio: viaggio as Record<string, any>,
      armadio: armadioApp.flatMap((g) => [g.sub_fine, g.sub_category]),
      lingua,
    });
    const postiGen = postiApp(r.valigia, motiviApp, salvate, {
      meteo: r.meteo as Record<string, any> | null, viaggio: viaggio as Record<string, any>,
      armadio: armadioApp, lingua, fabbisogni: r.fabbisogni,
    });
    // Passo dei kit (dopo il generatore, prima dei posti): senza `kit` nel corpo non cambia nulla.
    let soloKit: Record<string, unknown> = {};
    let posti = postiGen.posti;
    if (kit) {
      const esito = kitDelViaggio(kit, uscita.capi, {
        attivita: attivitaGrezze(b.trip), mezzi,
      }, new Set(righe.map((x: Record<string, any>) => String(x.id))));
      posti = riempiPostiConKit(postiGen.posti, esito.aggiunti, armadioApp, uscita.capi);
      soloKit = { kit: esito };
    }
    risposta = json(200, {
      valigia, motivi: r.motivi, perche: r.perche, geo: r.geo, meteo: r.meteo,
      note_tecniche: r.jev.errori,
      ...uscita,
      ...postiGen,
      posti,
      ...soloKit,
      ...campoVersione(),
    });
  } catch (e) {
    console.error("[pack-trip]", (e as Error).message);
    await restituisciCreditoAi(db, u.id, consumo);
    return errore(502, "Packing upstream error");
  }
  return risposta;
});
