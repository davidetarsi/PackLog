// Il clima del viaggio: previsione entro due settimane, normali climatiche
// (archivio ERA5, cinque anni) oltre. Porting di weather, _derive,
// _correggi_quota, _cache_key, fonte_meteo e geo_meteo_multitappa del bench
// (packlog_checklist_bench_48.py). TypeScript puro: la rete, la cache e
// l'attesa arrivano da fuori, cosi' il test gira senza Open-Meteo.
import { ANNI_STORICI, FORECAST_HORIZON_DAYS, GRADIENTE_TERMICO, SCARTO_QUOTA_RILEVANTE, VERSIONE_METEO }
  from "../valigia/costanti.ts";
import { round2 } from "../valigia/slots.ts";
import { ordina, pf, pySum } from "../valigia/py.ts";

type Record_ = Record<string, any>;

export const FORECAST_ENDPOINT = "https://api.open-meteo.com/v1/forecast";
export const ARCHIVE_ENDPOINT = "https://archive-api.open-meteo.com/v1/archive";
export const ELEVATION_ENDPOINT = "https://api.open-meteo.com/v1/elevation";

const r1 = (x: number) => round2(x, 1);
const max = (xs: number[]) => xs.reduce((a, b) => (b > a ? b : a));
const min = (xs: number[]) => xs.reduce((a, b) => (b < a ? b : a));
const pieni = (xs: unknown) => ((xs as (number | null)[] | undefined) ?? []).filter((v) => v != null) as number[];

// ── Date di calendario, senza fusi orari ────────────────────────────────────

/** Una data "AAAA-MM-GG" come numero di giorni dal 1970 (UTC). */
export const giorno = (iso: string) => Math.round(Date.parse(iso + "T00:00:00Z") / 86400000);
export const iso = (g: number) => new Date(g * 86400000).toISOString().slice(0, 10);

/** date.replace(year=...) di Python: null sul 29 febbraio di un anno non bisestile. */
function conAnno(isoData: string, anno: number): string | null {
  const [, m, d] = isoData.split("-");
  const s = `${String(anno).padStart(4, "0")}-${m}-${d}`;
  return iso(giorno(s)) === s ? s : null;
}

// ── Metriche derivate ───────────────────────────────────────────────────────

/** Le metriche che cambiano la valigia, dalle serie giornaliere di Open-Meteo. */
export function deriva(daily: Record_, fonte: string): Record_ {
  const tmax = pieni(daily.temperature_2m_max);
  const tmin = pieni(daily.temperature_2m_min);
  const rain = ((daily.precipitation_sum ?? []) as (number | null)[]).map((v) => v || 0);
  const wind = pieni(daily.wind_speed_10m_max);
  const uv = pieni(daily.uv_index_max);
  const n = Math.max(tmax.length, 1);
  // zip() di Python: si ferma alla serie piu' corta
  const escursioni = tmax.slice(0, Math.min(tmax.length, tmin.length)).map((a, i) => a - tmin[i]);
  const media = (xs: number[]) => (xs.length ? r1(pySum(xs) / xs.length) : null);
  return {
    fonte,
    giorni: n,
    temp_max_media: media(tmax),
    temp_min_media: media(tmin),
    temp_min_assoluta: tmin.length ? r1(min(tmin)) : null,
    temp_max_assoluta: tmax.length ? r1(max(tmax)) : null,
    escursione_media: media(escursioni),
    escursione_max: escursioni.length ? r1(max(escursioni)) : null,
    giorni_di_pioggia: rain.filter((v) => v > 1.0).length,
    pioggia_totale_mm: r1(pySum(rain)),
    vento_max_kmh: wind.length ? r1(max(wind)) : null,
    uv_max: uv.length ? r1(max(uv)) : null,
  };
}

/** Riporta le temperature dalla quota della cella meteo (ERA5, ~25 km) a
 *  quella del luogo: per Tenerife la cella sta a 1883 m per via del Teide. */
export function correggiQuota(wx: Record_, quotaReale: number | null | undefined,
  quotaGriglia: number | null | undefined): Record_ {
  if (quotaGriglia != null) wx.quota_griglia_m = quotaGriglia;
  if (quotaReale == null || quotaGriglia == null) return wx;
  const dz = quotaGriglia - quotaReale;
  if (Math.abs(dz) < SCARTO_QUOTA_RILEVANTE) return wx;
  const delta = r1(dz * GRADIENTE_TERMICO);
  for (const campo of ["temp_min_media", "temp_max_media", "temp_min_assoluta", "temp_max_assoluta"]) {
    if (wx[campo] != null) wx[campo] = r1(wx[campo] + delta);
  }
  wx.correzione_quota_c = delta;
  return wx;
}

export function chiaveCache(lat: number, lon: number, inizio: string, fine: string, fonte: string): string {
  return `${pf(r1(lat))}|${pf(r1(lon))}|${inizio.slice(5)}|${fine.slice(5)}|`
    + `${giorno(fine) - giorno(inizio)}|${fonte}|v${VERSIONE_METEO}`;
}

/** Previsione o normali climatiche, decidendo sulla FINE del viaggio (Open-Meteo
 *  pone il limite su end_date, in UTC; un giorno di margine sul fuso). */
export function fonteMeteo(_inizio: string, fine: string, oggi: string): "previsione" | "clima" {
  return giorno(fine) - giorno(oggi) <= FORECAST_HORIZON_DAYS ? "previsione" : "clima";
}

// ── Il meteo di un luogo e di un periodo ────────────────────────────────────

export interface Risposta { status: number; json(): Promise<any> }

export interface Servizi {
  /** GET con i parametri in query; ritenta da solo le cadute di rete. */
  scarica(url: string, params: Record<string, string | number>): Promise<Risposta>;
  leggiCache(chiave: string): Promise<Record_ | null>;
  scriviCache(chiave: string, valore: Record_): Promise<void>;
  /** Oggi in UTC e in ora locale del servizio, "AAAA-MM-GG". */
  oggiUtc(): string;
  oggi(): string;
  /** Attesa dopo un 429 dell'archivio (tentativo 0, 1). */
  attendi(tentativo: number): Promise<void>;
}

const CAMPI_PREVISIONE = [
  "temperature_2m_max", "temperature_2m_min",
  "apparent_temperature_max", "apparent_temperature_min",
  "precipitation_sum", "precipitation_probability_max",
  "wind_speed_10m_max", "uv_index_max",
];
const CAMPI_STORICO = ["temperature_2m_max", "temperature_2m_min", "precipitation_sum", "wind_speed_10m_max"];

/** Previsione entro l'orizzonte utile, normali climatiche oltre. */
export async function meteo(lat: number, lon: number, inizio: string, fine: string,
  quotaReale: number | null, s: Servizi): Promise<Record_> {
  const fonte = fonteMeteo(inizio, fine, s.oggiUtc());
  // Le normali climatiche non cambiano mai; le previsioni valgono un giorno.
  const chiave = chiaveCache(lat, lon, inizio, fine, fonte);
  const hit = await s.leggiCache(chiave);
  if (hit && (fonte === "clima" || hit._giorno === s.oggi())) {
    const { _giorno, ...resto } = hit;
    return { ...resto, da_cache: true };
  }

  if (fonte === "previsione") {
    const resp = await s.scarica(FORECAST_ENDPOINT, {
      latitude: lat, longitude: lon, start_date: inizio, end_date: fine,
      daily: CAMPI_PREVISIONE.join(","), timezone: "auto",
    });
    if (resp.status >= 400) throw new Error(`Open-Meteo previsione: HTTP ${resp.status}`);
    const j = await resp.json();
    const out = correggiQuota(deriva(j.daily ?? {}, "previsione"), quotaReale, j.elevation);
    await s.scriviCache(chiave, { ...out, _giorno: s.oggi() });
    return out;
  }

  // Normali climatiche: solo la finestra di calendario del viaggio, un anno
  // alla volta (cinque richieste piccole invece di una pesante). Le richieste
  // partono insieme; i dati si mettono in fila per anno, come nel bench.
  const ultimoAnno = Number(s.oggi().slice(0, 4)) - 1;     // l'archivio ha qualche giorno di ritardo
  const annoInizio = Number(inizio.slice(0, 4)), annoFine = Number(fine.slice(0, 4));
  const anni: number[] = [];
  for (let a = ultimoAnno - ANNI_STORICI + 1; a <= ultimoAnno; a++) anni.push(a);
  const risposte = await Promise.all(anni.map(async (anno) => {
    const delta = anno - annoInizio;
    const sAnno = conAnno(inizio, annoInizio + delta), eAnno = conAnno(fine, annoFine + delta);
    if (!sAnno || !eAnno) return null;                     // 29 febbraio in un anno non bisestile
    const params = {
      latitude: lat, longitude: lon, start_date: sAnno, end_date: eAnno,
      daily: CAMPI_STORICO.join(","), timezone: "auto",
    };
    let resp: Risposta | null = null;
    for (let t = 0; t < 3; t++) {
      resp = await s.scarica(ARCHIVE_ENDPOINT, params);
      if (resp.status !== 429) break;
      await s.attendi(t);
    }
    return resp && resp.status === 200 ? await resp.json() : null;
  }));

  const accumulato: Record<string, number[]> = Object.fromEntries(CAMPI_STORICO.map((k) => [k, []]));
  let quotaGriglia: number | null = null, n = 0;
  for (const j of risposte) {
    if (!j) continue;
    const daily = j.daily ?? {};
    if (!daily.time?.length) continue;
    if (quotaGriglia == null) quotaGriglia = j.elevation ?? null;
    n++;
    for (const k of CAMPI_STORICO) accumulato[k].push(...pieni(daily[k]));
  }
  if (n === 0) throw new Error("archivio storico non disponibile per questa localita");

  const out = correggiQuota(deriva(accumulato, `storico ${n} anni`), quotaReale, quotaGriglia);
  // I conteggi sono sommati su piu' anni: riportati alla scala del viaggio.
  out.giorni = giorno(fine) - giorno(inizio) + 1;
  out.giorni_di_pioggia = r1(out.giorni_di_pioggia / n);
  out.pioggia_totale_mm = r1(out.pioggia_totale_mm / n);
  out.anni_mediati = n;
  await s.scriviCache(chiave, out);
  return out;
}

/** Quota del luogo in metri (modello digitale del terreno di Open-Meteo). */
export async function quota(lat: number, lon: number, s: Servizi): Promise<number | null> {
  try {
    const r = await s.scarica(ELEVATION_ENDPOINT, { latitude: lat, longitude: lon });
    if (r.status !== 200) return null;
    const v = (await r.json()).elevation?.[0];
    return typeof v === "number" && v < 9000 ? v : null;
  } catch {
    return null;
  }
}

// ── Viaggi a tappe ──────────────────────────────────────────────────────────

/** Una tappa gia' risolta: luogo (nome, paese, coordinate, quota) e meteo. */
export interface TappaRisolta {
  destinazione: string;
  giorni: number;
  attivita: string[];
  geo: Record_;
  meteo: Record_;
}

/** Un solo bagaglio per piu' tappe: le condizioni si UNISCONO, non si mediano
 *  (minimo dei minimi, massimo dei massimi, pioggia sommata, picchi di vento e UV). */
export function unisciTappe(perTappa: TappaRisolta[]): [Record_, Record_] {
  const agg = (k: string, f: (xs: number[]) => number, d: number | null = null) => {
    const v = perTappa.map((t) => t.meteo[k]).filter((x) => x != null) as number[];
    return v.length ? f(v) : d;
  };
  const paesi: string[] = [];
  for (const t of perTappa) {
    const pa = t.geo.paese;
    if (pa && !paesi.includes(pa)) paesi.push(pa);
  }
  const geo = {
    nome: perTappa.map((t) => t.destinazione).join(" → "),
    paese: paesi.length ? paesi.join(" / ") : "",
    lat: perTappa[0].geo.lat,
    lon: perTappa[0].geo.lon,
    // il freddo lo fa la quota piu' alta del viaggio, non la media
    altitudine_m: max(perTappa.map((t) => t.geo.altitudine_m || 0)),
    timezone: perTappa[0].geo.timezone ?? null,
    tappe: perTappa.map((t) => t.destinazione),
    per_tappa: perTappa,
  };
  const wx = {
    fonte: ordina(new Set(perTappa.map((t) => t.meteo.fonte ?? "?"))).join(" + "),
    giorni: perTappa.reduce((n, t) => n + t.giorni, 0),
    temp_min_media: agg("temp_min_media", min),
    temp_max_media: agg("temp_max_media", max),
    temp_min_assoluta: agg("temp_min_assoluta", min),
    temp_max_assoluta: agg("temp_max_assoluta", max),
    escursione_media: agg("escursione_media", max),
    escursione_max: agg("escursione_max", max),
    giorni_di_pioggia: agg("giorni_di_pioggia", pySum, 0),
    pioggia_totale_mm: agg("pioggia_totale_mm", pySum, 0),
    vento_max_kmh: agg("vento_max_kmh", max),
    uv_max: agg("uv_max", max),
    da_cache: perTappa.every((t) => !!t.meteo.da_cache),
    _per_tappa: perTappa.map((t) => ({
      destinazione: t.destinazione,
      giorni: t.giorni,
      temp_min_media: t.meteo.temp_min_media ?? null,
      temp_max_media: t.meteo.temp_max_media ?? null,
      giorni_di_pioggia: t.meteo.giorni_di_pioggia ?? null,
    })),
  };
  return [geo, wx];
}

/** Un luogo come lo da' l'app (Geoapify): nome, paese, coordinate. */
export interface Luogo { nome: string; paese?: string | null; lat: number; lon: number; timezone?: string | null }

export interface Tappa extends Luogo { giorni: number; attivita?: string[] | null }

/** Geo e meteo di un viaggio: una destinazione, o piu' tappe in fila dalla data
 *  di partenza. Se manca la quota del luogo vale quella della cella meteo. */
export async function climaViaggio(inizio: string, giorni: number, luogo: Luogo | null, tappe: Tappa[] | null,
  s: Servizi): Promise<{ geo: Record_; meteo: Record_ }> {
  const risolvi = async (l: Luogo, da: string, a: string) => {
    const q = await quota(l.lat, l.lon, s);
    const w = await meteo(l.lat, l.lon, da, a, q, s);
    const geo: Record_ = { nome: l.nome, paese: l.paese ?? null, lat: l.lat, lon: l.lon,
      altitudine_m: q ?? w.quota_griglia_m ?? null, timezone: l.timezone ?? null };
    return { geo, w };
  };
  if (tappe && tappe.length) {
    let g = giorno(inizio);
    const piano = tappe.map((t) => {
      const gg = Math.trunc(t.giorni || 1);
      const p = { t, gg, da: iso(g), a: iso(g + gg - 1) };
      g += gg;
      return p;
    });
    const risolte = await Promise.all(piano.map(async ({ t, gg, da, a }) => {
      try {
        const { geo, w } = await risolvi(t, da, a);
        return { destinazione: t.nome, giorni: gg, attivita: [...(t.attivita ?? [])], geo, meteo: w };
      } catch (e) {
        throw new Error(`tappa ${t.nome}: ${(e as Error).message}`);
      }
    }));
    const [geo, wx] = unisciTappe(risolte);
    return { geo, meteo: wx };
  }
  if (!luogo) throw new Error("manca la destinazione");
  const { geo, w } = await risolvi(luogo, inizio, iso(giorno(inizio) + giorni - 1));
  return { geo, meteo: w };
}
