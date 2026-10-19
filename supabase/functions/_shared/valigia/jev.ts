// Jev (TypeSafe AI) nel generatore: profilo dei capi, voto viaggio x scarpa,
// voto viaggio x vestito (veto) e classificazione del viaggio. Porting di
// jev_profilo_capi.py, jev_voti_viaggio.py, jev_classifica_viaggio.py e
// jev_live.py del bench. Il modello giudica, il codice decide: le risposte
// entrano nel matcher come penalita', mai come scelta.
import type { Capo } from "./capo.ts";
import { get } from "./slots.ts";
import { stripChars } from "./inject.ts";
import { o, ps, vero } from "./py.ts";

type Record_ = Record<string, any>;

export const ENDPOINT = "https://api.typesafe.ai/v1/systemone";
export const MODELLO = "jev-latest";

/** Domande del profilo per categoria: atomiche, una cosa per domanda. */
export const DOMANDE_PROFILO: Record<string, [string[], string]> = {
  elegante: [["Upper Body", "Lower Body", "Outerwear", "Shoes"],
    "Is this item elegant enough to wear to a dinner at a nice restaurant or to a business meeting?"],
  da_giorno: [["Upper Body", "Lower Body", "Shoes"],
    "Is this item a good choice for a full day of casual sightseeing, when you walk a lot and may sweat?"],
  caldo_torrido: [["Upper Body", "Lower Body", "Outerwear", "Shoes"],
    "Is this item comfortable to wear in hot weather, around 30 degrees Celsius?"],
  cammino: [["Shoes"], "Are these shoes comfortable for walking several hours a day, in a city or on easy trails?"],
  spalle: [["Upper Body"], "Does this item cover the shoulders and the upper arms?"],
  ginocchia: [["Lower Body"], "Does this item cover the knees?"],
};

export const DOMANDA_SCARPE = "Would these shoes be a good main pair to wear for most of the "
  + "walking on this trip, given its places, season, weather and activities?";
export const DOMANDA_CAPI = "Would this item be a sensible thing to pack and wear on this trip, "
  + "given its places, season, weather and activities?";
export const CATEGORIE_CAPI = ["Upper Body", "Lower Body", "Outerwear"];

const noul = (instructions: string) => ({ type: "noul", instructions });
export const DOMANDE_CLASSI: Record<string, Record_> = {
  culto: noul("Will the traveler visit places of worship (churches, mosques, temples) "
    + "where covered shoulders and knees are expected?"),
  sera_elegante: noul("Will there be evenings at nice restaurants or events that call for smart clothes?"),
  lavoro_formale: noul("Does the trip include business meetings that require formal attire?"),
  acqua: noul("Will the traveler swim or bathe (sea, lake, pool, spa, hot springs)?"),
  kway: noul("Would a light windproof or rain jacket be useful on this trip, because of rain or wind?"),
  vento: noul("Is the destination windy enough that a windproof layer is useful even on dry days?"),
  pioggia_forte: noul("Is heavy or frequent rain likely, so that a truly waterproof "
    + "jacket is needed rather than a light one?"),
  sole: noul("Will the traveler spend long hours outdoors under strong sun, so that "
    + "a hat or sunglasses are needed?"),
  riverbero: noul("Will there be snow, glaciers or high altitude where sunglasses are essential against glare?"),
  freddo_capospalla: noul("Will it be cold enough that a warm coat or down jacket is needed?"),
  sudore: {
    type: "choice", instructions: "How much will the traveler sweat on a typical day of this trip?",
    criteria: {
      low: "little: cool weather, relaxed city days",
      medium: "some: mild weather or a mix of walking and rest",
      high: "a lot: hot and humid weather, or hiking and sport",
    },
  },
  terreno: {
    type: "choice", instructions: "On what kind of ground will the traveler walk most?",
    criteria: {
      city: "city pavements and museums",
      easy_trails: "parks, beaches and easy trails",
      mountain: "rough mountain or hiking trails",
      snow: "snow and ice",
    },
  },
};

const MESI = ["January", "February", "March", "April", "May", "June", "July",
  "August", "September", "October", "November", "December"];

/** Lo 'state' per Jev: solo i dati del capo, nessun dato dell'utente. */
export function scheda(g: Capo): Record_ {
  return {
    name: g.name, category: g.category, subCategory: g.sub_category,
    color: g.base_color, pattern: g.pattern, coverage: g.coverage,
    fit: g.fit, warmth_1_to_5: g.warmth, formality: g.formality,
    activityTags: g.activity_tags, waterResistance_0_to_2: g.water_resistance,
  };
}

const clima = (m: Record_) => ({
  average_low_C: get(m, "temp_min_media"),
  average_high_C: get(m, "temp_max_media"),
  rainy_days: get(m, "giorni_di_pioggia"),
  max_wind_kmh: get(m, "vento_max_kmh"),
});

/** Il viaggio come lo vede Jev: solo dati del viaggio, niente dell'utente. */
export function statoViaggio(sc: Record_, geo: Record_ | null, meteo: Record_ | null): Record_ {
  geo = o(geo, {}) as Record_;
  const mese = vero(get(sc, "data_inizio")) ? MESI[Number(String(sc.data_inizio).slice(5, 7)) - 1] : null;
  const luogo = (a: unknown, b: unknown) => stripChars(`${ps(a)}, ${ps(b)}`, ", ");
  const tappe = vero(get(geo, "per_tappa"))
    ? (geo.per_tappa as Record_[]).map((t) => ({
      place: luogo(t.destinazione, get(get(t, "geo", {}) as Record_, "paese", "")),
      days: get(t, "giorni"), activities: o(get(t, "attivita"), []),
      climate: clima(o(get(t, "meteo"), {}) as Record_),
    }))
    : [{
      place: luogo(get(sc, "destinazione", ""), get(sc, "paese", "")),
      days: get(sc, "giorni"), activities: o(get(sc, "attivita"), []),
      climate: clima(o(meteo, {}) as Record_),
    }];
  return { month: mese, total_days: get(sc, "giorni"), legs: tappe,
    accommodation: get(sc, "alloggio"), luggage: get(sc, "bagaglio") };
}

// ── Chiamate ────────────────────────────────────────────────────────────────

/** Risposta di Jev: per domanda {type, noul} oppure {type, choice, probabilities}. */
export interface RispostaJev { model?: string; answers: Record<string, Record_> }
export type ChiediJev = (stato: Record_, domande: Record<string, Record_>) => Promise<RispostaJev>;

/** I profili gia' calcolati, per capo, con la scheda da cui vengono. */
export interface ProfiloNoto { scheda: string; risposte: Record<string, number | null> }

export interface DatiJev {
  profili_capi?: Record<string, Record<string, number | null>>;
  voti_scarpe?: Record<string, number>;
  scarti_capi?: Record<string, number>;
  classi_viaggio?: Record_;
  /** Profili nuovi da salvare: {id del capo: profilo}. */
  profili_nuovi: Record<string, ProfiloNoto>;
  /** Cosa non ha risposto (Jev e' un aiuto: la valigia si fa lo stesso). */
  errori: string[];
}

/** Esegue f su tutti gli elementi, al massimo `n` alla volta. */
async function aGruppi<T>(xs: T[], n: number, f: (x: T) => Promise<void>): Promise<void> {
  let i = 0;
  await Promise.all(Array.from({ length: Math.min(n, xs.length) }, async () => {
    while (i < xs.length) await f(xs[i++]);
  }));
}

/** I dati di Jev che il matcher usa, chiedendo solo cio' che manca: il profilo
 *  di un capo vale finche' la sua scheda non cambia. */
export async function datiJev(sc: Record_, geo: Record_ | null, meteo: Record_ | null, items: Capo[],
  chiedi: ChiediJev, profiliNoti: Record<string, ProfiloNoto> = {}, contemporanee = 8): Promise<DatiJev> {
  const out: DatiJev = { profili_nuovi: {}, errori: [] };
  const conDati = items.filter((g) => g.has_metadata);
  const stato = statoViaggio(sc, geo, meteo);

  // 1. Profilo di ogni capo (non dipende dal viaggio): una chiamata per capo.
  const profili: Record<string, Record<string, number | null>> = {};
  const daChiedere: [Capo, string, Record<string, Record_>][] = [];
  for (const g of conDati) {
    const nomi = Object.keys(DOMANDE_PROFILO).filter((k) => DOMANDE_PROFILO[k][0].includes(g.category));
    if (!nomi.length) continue;
    const s = JSON.stringify(scheda(g));
    const noto = profiliNoti[g.id];
    if (noto && noto.scheda === s) { profili[g.id] = noto.risposte; continue; }
    daChiedere.push([g, s, Object.fromEntries(nomi.map((k) => [k, noul(DOMANDE_PROFILO[k][1])]))]);
  }
  const profiliFatti = aGruppi(daChiedere, contemporanee, async ([g, s, domande]) => {
    try {
      const d = await chiedi(scheda(g), domande);
      const risposte = Object.fromEntries(Object.entries(d.answers).map(([q, v]) => [q, v?.noul ?? null]));
      profili[g.id] = risposte;
      out.profili_nuovi[g.id] = { scheda: s, risposte };
    } catch (e) {
      out.errori.push(`profilo ${g.id}: ${(e as Error).message}`);
    }
  });

  // 2. Voto viaggio x capo: una chiamata per le scarpe, una per i vestiti.
  const voti = async (categorie: string[], domanda: string, chiaveCapo: string, cosa: string) => {
    const capi = conDati.filter((g) => categorie.includes(g.category));
    if (!capi.length) return null;
    try {
      const d = await chiedi(stato, Object.fromEntries(capi.map((g) =>
        [g.id, { type: "noul", instructions: { question: domanda, [chiaveCapo]: scheda(g) } }])));
      const v: Record<string, number> = {};
      for (const g of capi) {
        const p = d.answers[g.id]?.noul;
        if (p != null) v[g.id] = p;
      }
      return Object.keys(v).length ? v : null;
    } catch (e) {
      out.errori.push(`${cosa}: ${(e as Error).message}`);
      return null;
    }
  };

  // 3. Classificazione del viaggio.
  const classi = (async () => {
    try {
      const d = await chiedi(stato, DOMANDE_CLASSI);
      return Object.fromEntries(Object.entries(d.answers).map(([q, v]) => [q, v.type === "noul"
        ? v.noul ?? null : { scelta: v.choice ?? null, probabilita: v.probabilities ?? null }]));
    } catch (e) {
      out.errori.push(`classi: ${(e as Error).message}`);
      return null;
    }
  })();

  const [scarpe, capi, cl] = await Promise.all([
    voti(["Shoes"], DOMANDA_SCARPE, "shoes", "voti scarpe"),
    voti(CATEGORIE_CAPI, DOMANDA_CAPI, "item", "voti capi"),
    classi, profiliFatti,
  ]);
  // stesso ordine dell'armadio, come nel bench
  const ordinati: Record<string, Record<string, number | null>> = {};
  for (const g of conDati) if (g.id in profili) ordinati[g.id] = profili[g.id];
  if (Object.keys(ordinati).length) out.profili_capi = ordinati;
  if (scarpe) out.voti_scarpe = scarpe;
  if (capi) out.scarti_capi = capi;
  if (cl && Object.keys(cl).length) out.classi_viaggio = cl;
  return out;
}

/** La chiamata vera a Jev (la chiave resta lato server). */
export function jevHttp(chiave: string, fetchFn: typeof fetch = fetch, timeoutMs = 60000): ChiediJev {
  return async (stato, domande) => {
    const r = await fetchFn(ENDPOINT, {
      method: "POST",
      headers: { Authorization: `Bearer ${chiave}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model: MODELLO, state: stato, questions: domande }),
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (r.status !== 200) throw new Error(`Jev ${r.status}: ${(await r.text()).slice(0, 200)}`);
    return await r.json();
  };
}
