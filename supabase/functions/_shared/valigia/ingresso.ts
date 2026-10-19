// Controllo del viaggio che arriva dall'app: il client puo' mandare qualsiasi
// cosa, e ogni campo finisce in un prompt pagato o in una richiesta a Open-Meteo.
import type { ViaggioApp } from "./genera.ts";
import type { Luogo, Tappa } from "../clima/meteo.ts";

export const MAX_GIORNI = 60;
export const MAX_TAPPE = 8;
export const MAX_ATTIVITA = 20;
export const MAX_TESTO = 80;

export class IngressoNonValido extends Error {}

const no = (m: string): never => { throw new IngressoNonValido(m); };

function testo(x: unknown, campo: string, obbligatorio = false): string | null {
  if (x == null || x === "") return obbligatorio ? no(`manca '${campo}'`) : null;
  if (typeof x !== "string") return no(`'${campo}' deve essere un testo`);
  const t = x.trim();
  if (t.length > MAX_TESTO) return no(`'${campo}' troppo lungo (max ${MAX_TESTO} caratteri)`);
  return t || (obbligatorio ? no(`manca '${campo}'`) : null);
}

function giorni(x: unknown, campo: string): number {
  if (typeof x !== "number" || !Number.isInteger(x) || x < 1 || x > MAX_GIORNI) {
    return no(`'${campo}' deve essere un intero fra 1 e ${MAX_GIORNI}`);
  }
  return x;
}

function attivita(x: unknown, campo: string): string[] {
  if (x == null) return [];
  if (!Array.isArray(x)) return no(`'${campo}' deve essere un elenco`);
  if (x.length > MAX_ATTIVITA) return no(`'${campo}': al massimo ${MAX_ATTIVITA} attivita'`);
  return x.map((a, i) => testo(a, `${campo}[${i}]`, true)!);
}

function luogo(x: unknown, campo: string): Luogo {
  if (!x || typeof x !== "object") return no(`manca '${campo}'`);
  const l = x as Record<string, unknown>;
  const lat = l.lat, lon = l.lon;
  if (typeof lat !== "number" || !Number.isFinite(lat) || lat < -90 || lat > 90) return no(`'${campo}.lat' non valida`);
  if (typeof lon !== "number" || !Number.isFinite(lon) || lon < -180 || lon > 180) return no(`'${campo}.lon' non valida`);
  return { nome: testo(l.nome, `${campo}.nome`, true)!, paese: testo(l.paese, `${campo}.paese`), lat, lon,
    timezone: testo(l.timezone, `${campo}.timezone`) };
}

/** "AAAA-MM-GG" di una data vera, entro due anni da oggi. */
export function data(x: unknown, oggi: string): string {
  if (typeof x !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(x)) return no("'data_inizio' deve essere AAAA-MM-GG");
  const t = Date.parse(x + "T00:00:00Z");
  if (Number.isNaN(t) || new Date(t).toISOString().slice(0, 10) !== x) return no("'data_inizio' non e' una data");
  const g = (t - Date.parse(oggi + "T00:00:00Z")) / 86400000;
  if (g < -1 || g > 730) return no("'data_inizio' fuori intervallo (da ieri a due anni)");
  return x;
}

/** Il viaggio controllato. A tappe i giorni sono la somma delle tappe. */
export function validaViaggio(x: unknown, oggi: string, conDettagli = true): ViaggioApp {
  if (!x || typeof x !== "object" || Array.isArray(x)) return no("manca il viaggio");
  const v = x as Record<string, unknown>;
  const out: ViaggioApp = { data_inizio: data(v.data_inizio, oggi), giorni: 0 };
  if (v.tappe != null) {
    if (!Array.isArray(v.tappe) || !v.tappe.length) return no("'tappe' deve essere un elenco non vuoto");
    if (v.tappe.length > MAX_TAPPE) return no(`al massimo ${MAX_TAPPE} tappe`);
    out.tappe = v.tappe.map((t, i): Tappa => ({
      ...luogo(t, `tappe[${i}]`),
      giorni: giorni((t as Record<string, unknown>).giorni, `tappe[${i}].giorni`),
      attivita: attivita((t as Record<string, unknown>).attivita, `tappe[${i}].attivita`),
    }));
    out.giorni = out.tappe.reduce((n, t) => n + t.giorni, 0);
    if (out.giorni > MAX_GIORNI) return no(`viaggio troppo lungo (max ${MAX_GIORNI} giorni)`);
    if (v.giorni != null && v.giorni !== out.giorni) return no("'giorni' diverso dalla somma delle tappe");
  } else {
    out.destinazione = luogo(v.destinazione, "destinazione");
    out.giorni = giorni(v.giorni, "giorni");
  }
  if (!conDettagli) return out;
  out.attivita = attivita(v.attivita, "attivita");
  out.bagaglio = testo(v.bagaglio, "bagaglio");
  out.alloggio = testo(v.alloggio, "alloggio");
  if (v.lavatrice != null && typeof v.lavatrice !== "boolean") return no("'lavatrice' deve essere vero o falso");
  out.lavatrice = !!v.lavatrice;
  return out;
}
