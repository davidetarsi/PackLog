// Il prompt mandato al modello: le condizioni del viaggio dentro SLOTS_PROMPT.
// Porting di build_conditions, attivita_scenario e della preparazione delle
// condizioni in strategy_slots_multitappa (bench, packlog_checklist_bench_48.py).
import { SLOTS_PROMPT } from "./costanti.ts";
import { get, ordinaTappe } from "./slots.ts";
import { o, pf, vero } from "./py.ts";

type Record_ = Record<string, any>;

/** Nei multi-tappa le attivita' stanno dentro `legs`: valgono tutte insieme,
 *  senza doppioni (confronto in minuscolo, si tiene la prima scrittura). */
export function attivitaScenario(sc: Record_): string[] {
  const fuori = o(get(sc, "attivita"), []) as string[];
  const dentro = (o(get(sc, "legs"), []) as Record_[]).flatMap((t) => o(get(t, "attivita"), []) as string[]);
  return dedup([...fuori, ...dentro]);
}

function dedup(xs: string[]): string[] {
  const viste = new Set<string>(), out: string[] = [];
  for (const a of xs) {
    const k = a.toLowerCase().trim();
    if (!viste.has(k)) { viste.add(k); out.push(a); }
  }
  return out;
}

// Python distingue 13 da 13.0 e il modello ha sempre letto i dati cosi': il
// meteo e le quote sono float, i conteggi interi. La previsione conta i giorni
// di pioggia (intero) e somma la pioggia come intero quando e' tutta zero.
const INTERI = new Set(["durata_giorni", "giorni", "anni_mediati"]);

function intero(chiave: string, valore: number, meteo: Record_ | null): boolean {
  if (INTERI.has(chiave)) return true;
  if (meteo && get(meteo, "fonte") === "previsione") {
    if (chiave === "giorni_di_pioggia") return true;
    if (chiave === "pioggia_totale_mm") return valore === 0;
  }
  return false;
}

/** json.dumps(x, ensure_ascii=False, indent=2) di Python per le condizioni. */
export function jsonCondizioni(x: unknown, livello = 0, chiave = "", meteo: Record_ | null = null): string {
  if (x == null) return "null";
  if (typeof x === "boolean") return x ? "true" : "false";
  if (typeof x === "number") {
    if (!Number.isFinite(x)) return Number.isNaN(x) ? "NaN" : x > 0 ? "Infinity" : "-Infinity";
    return Number.isInteger(x) && intero(chiave, x, meteo) ? String(x) : pf(x);
  }
  if (typeof x === "string") return JSON.stringify(x);
  const dentro = "\n" + "  ".repeat(livello + 1), fuori = "\n" + "  ".repeat(livello);
  if (Array.isArray(x)) {
    if (!x.length) return "[]";
    return "[" + x.map((v) => dentro + jsonCondizioni(v, livello + 1, chiave, meteo)).join(",") + fuori + "]";
  }
  const voci = Object.entries(x as Record_);
  if (!voci.length) return "{}";
  const m = chiave === "meteo" ? (x as Record_) : meteo;
  return "{" + voci.map(([k, v]) => dentro + JSON.stringify(k) + ": " + jsonCondizioni(v, livello + 1, k, m))
    .join(",") + fuori + "}";
}

export function buildConditions(sc: Record_, geo: Record_, wx: Record_): string {
  return jsonCondizioni({
    // senza paese (il geocoder non lo da' per Torshavn) solo il nome
    destinazione: vero(get(geo, "paese")) ? `${geo.nome}, ${geo.paese}` : geo.nome,
    altitudine_m: geo.altitudine_m,
    durata_giorni: sc.giorni,
    attivita: sc.attivita,
    bagaglio: sc.bagaglio,
    alloggio: sc.alloggio,
    accesso_lavatrice: sc.lavatrice,
    meteo: wx,
  });
}

/** Le condizioni che legge il modello. A tappe: la tappa piu' calda fa da base,
 *  sui giorni di tutto il viaggio, con le attivita' di tutte le tappe. */
export function condizioniViaggio(sc: Record_, geo: Record_, wx: Record_): string {
  const perTappa = get(geo, "per_tappa") as Record_[] | null;
  if (!perTappa || !perTappa.length) return buildConditions(sc, geo, wx);
  const giorniTot = perTappa.reduce((n, t) => n + Math.trunc(o(get(t, "giorni"), 1) as number), 0);
  const base = ordinaTappe(perTappa)[0];
  const attContesto = dedup([...(o(get(sc, "attivita"), []) as string[]),
    ...perTappa.flatMap((t) => o(get(t, "attivita"), []) as string[])]);
  return buildConditions({ ...sc, giorni: giorniTot, attivita: attContesto }, base.geo, base.meteo);
}

/** Il testo intero mandato al modello. */
export function promptValigia(sc: Record_, geo: Record_, wx: Record_): string {
  return (SLOTS_PROMPT as string).replace("{conditions}", () => condizioniViaggio(sc, geo, wx));
}
