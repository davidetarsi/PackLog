// Il dettaglio dei prossimi giorni di una tappa: per ogni giorno il riepilogo
// e sei fasce di quattro ore, dalla previsione oraria di Open-Meteo. Sta
// accanto a meteo.ts senza toccarlo: meteo() riduce il viaggio a medie per il
// generatore, qui servono i giorni come li vede l'utente nella pagina valigia.
import { FORECAST_ENDPOINT, giorno, iso, type Servizi } from "./meteo.ts";

/** Giorni da oggi con il dettaglio: oltre la previsione e' poco affidabile. */
export const GIORNI_DETTAGLIO = 7;

/** Ore di ogni fascia: 0-4, 4-8, 8-12, 12-16, 16-20, 20-24. */
export const ORE_FASCIA = 4;

const VERSIONE_GIORNI = 1;

const CAMPI_GIORNO = [
  "weather_code", "temperature_2m_max", "temperature_2m_min", "precipitation_sum",
  "precipitation_probability_max", "wind_speed_10m_max", "uv_index_max",
];
const CAMPI_ORA = ["weather_code", "temperature_2m", "precipitation_probability", "precipitation", "wind_speed_10m"];

export interface Fascia {
  /** Ora di inizio, 0..20. */
  da: number;
  /** Codice WMO piu' severo della fascia (come fa Open-Meteo per il giorno). */
  codice: number | null;
  temp_media: number | null;
  prob_pioggia: number | null;
  pioggia_mm: number | null;
  vento_kmh: number | null;
}

export interface Giorno {
  data: string;
  codice: number | null;
  temp_min: number | null;
  temp_max: number | null;
  prob_pioggia: number | null;
  pioggia_mm: number | null;
  vento_max_kmh: number | null;
  uv_max: number | null;
  fasce: Fascia[];
}

type Serie = Record<string, (number | null)[] | undefined>;

const r1 = (x: number) => Math.round(x * 10) / 10;
const pieni = (xs: (number | null | undefined)[]) => xs.filter((v) => v != null) as number[];
const massimo = (xs: number[]) => (xs.length ? xs.reduce((a, b) => (b > a ? b : a)) : null);
const somma = (xs: number[]) => (xs.length ? r1(xs.reduce((a, b) => a + b, 0)) : null);
const media = (xs: number[]) => (xs.length ? r1(xs.reduce((a, b) => a + b, 0) / xs.length) : null);
const valore = (s: Serie, k: string, i: number) => s[k]?.[i] ?? null;
const tondo = (v: number | null) => (v == null ? null : r1(v));

/** I giorni della tappa [inizio, fine] che cadono nei prossimi GIORNI_DETTAGLIO
 *  da oggi; null se nessuno. */
export function finestra(inizio: string, fine: string, oggi: string): [string, string] | null {
  const da = Math.max(giorno(inizio), giorno(oggi));
  const a = Math.min(giorno(fine), giorno(oggi) + GIORNI_DETTAGLIO - 1);
  return da <= a ? [iso(da), iso(a)] : null;
}

/** Riepilogo e fasce di ogni giorno, dalle serie di Open-Meteo. */
export function componiGiorni(daily: Serie & { time?: string[] }, hourly: Serie & { time?: string[] }): Giorno[] {
  const ore = hourly.time ?? [];
  return (daily.time ?? []).map((data, i) => {
    const fasce: Fascia[] = [];
    for (let da = 0; da < 24; da += ORE_FASCIA) {
      const indici = ore
        .map((t, j) => [t, j] as const)
        .filter(([t]) => {
          if (!t.startsWith(data)) return false;
          const ora = Number(t.slice(11, 13));
          return ora >= da && ora < da + ORE_FASCIA;
        })
        .map(([, j]) => j);
      const di = (k: string) => pieni(indici.map((j) => valore(hourly, k, j)));
      fasce.push({
        da,
        codice: massimo(di("weather_code")),
        temp_media: media(di("temperature_2m")),
        prob_pioggia: massimo(di("precipitation_probability")),
        pioggia_mm: somma(di("precipitation")),
        vento_kmh: tondo(massimo(di("wind_speed_10m"))),
      });
    }
    return {
      data,
      codice: valore(daily, "weather_code", i),
      temp_min: tondo(valore(daily, "temperature_2m_min", i)),
      temp_max: tondo(valore(daily, "temperature_2m_max", i)),
      prob_pioggia: valore(daily, "precipitation_probability_max", i),
      pioggia_mm: tondo(valore(daily, "precipitation_sum", i)),
      vento_max_kmh: tondo(valore(daily, "wind_speed_10m_max", i)),
      uv_max: tondo(valore(daily, "uv_index_max", i)),
      fasce,
    };
  });
}

/** I prossimi giorni di una tappa, con le fasce. Lista vuota se la tappa non
 *  cade nei prossimi GIORNI_DETTAGLIO. In cache per il giorno in cui si chiede,
 *  come le previsioni di meteo(). */
export async function giorniTappa(lat: number, lon: number, inizio: string, fine: string,
  s: Servizi): Promise<Giorno[]> {
  const oggi = s.oggi();
  const f = finestra(inizio, fine, s.oggiUtc());
  if (!f) return [];
  const [da, a] = f;

  const chiave = `giorni|${lat.toFixed(2)}|${lon.toFixed(2)}|${da}|${a}|v${VERSIONE_GIORNI}`;
  const hit = await s.leggiCache(chiave);
  if (hit && hit._giorno === oggi && Array.isArray(hit.giorni)) return hit.giorni;

  const resp = await s.scarica(FORECAST_ENDPOINT, {
    latitude: lat, longitude: lon, start_date: da, end_date: a,
    daily: CAMPI_GIORNO.join(","), hourly: CAMPI_ORA.join(","), timezone: "auto",
  });
  if (resp.status >= 400) throw new Error(`Open-Meteo giorni: HTTP ${resp.status}`);
  const j = await resp.json();
  const giorni = componiGiorni(j.daily ?? {}, j.hourly ?? {});
  await s.scriviCache(chiave, { _giorno: oggi, giorni });
  return giorni;
}

/** Le tappe di un viaggio in fila dalla partenza, con inizio e fine, come le
 *  mette in fila climaViaggio(). */
export function pianoTappe(inizio: string, tappe: { giorni: number }[]): { da: string; a: string }[] {
  let g = giorno(inizio);
  return tappe.map((t) => {
    const gg = Math.trunc(t.giorni || 1);
    const p = { da: iso(g), a: iso(g + gg - 1) };
    g += gg;
    return p;
  });
}
