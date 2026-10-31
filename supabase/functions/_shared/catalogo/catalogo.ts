// Il catalogo dei tag (spec del 31 ottobre 2026, § 6): tipi, usi, stile,
// colori, livelli, attivita' e alloggi. La verita' e' la tabella
// catalog_entries; catalogo.json ne e' la copia nel repo, e qui fa da riserva
// quando il database non risponde.
//
// Letture rare (Davide, 31 ottobre): un'istanza legge il catalogo la prima
// volta che serve, poi ricontrolla la versione al massimo una volta all'ora, e
// solo mentre serve una richiesta. Le righe si rileggono solo se la versione e'
// cambiata.
import base from "./catalogo.json" with { type: "json" };

type Db = any;

export interface VoceCatalogo {
  domain: string;
  id: string;
  sort: number;
  active: boolean;
  label: { it: string; en: string };
  data: Record<string, any>;
}

export interface Catalogo {
  voci: VoceCatalogo[];
}

/** La copia nel repo (catalogo.json). */
export const CATALOGO_BASE: Catalogo = { voci: (base as { entries: VoceCatalogo[] }).entries };

/** Ogni quanto un'istanza ricontrolla la versione, al massimo. */
export const CONTROLLO_MS = 60 * 60 * 1000;

let cache: { catalogo: Catalogo; versione: string | null; controllato: number } | null = null;

/** Solo per i test: l'istanza riparte senza catalogo letto. */
export function azzeraCache(): void {
  cache = null;
}

/** Una riga della tabella come voce del catalogo. */
function daRiga(r: Record<string, any>): VoceCatalogo {
  return {
    domain: String(r.domain), id: String(r.id), sort: Number(r.sort), active: r.active !== false,
    label: { it: String(r.label_it ?? ""), en: String(r.label_en ?? "") },
    data: r.data && typeof r.data === "object" ? r.data : {},
  };
}

/** Il catalogo per questa richiesta: dalla cache dell'istanza se controllata da
 *  meno di un'ora, se no dalla tabella (righe rilette solo se la versione e'
 *  cambiata). Con il database che non risponde: l'ultima cache, o la copia nel
 *  repo. */
export async function leggiCatalogo(db: Db, ora = Date.now()): Promise<Catalogo> {
  if (cache && ora - cache.controllato < CONTROLLO_MS) return cache.catalogo;
  const riserva = cache?.catalogo ?? CATALOGO_BASE;
  try {
    const { data: v, error: errV } = await db.from("app_config").select("value")
      .eq("key", "catalog_version").maybeSingle();
    if (errV) throw new Error(errV.message);
    const versione = v?.value == null ? null : String(v.value);
    if (cache && versione === cache.versione) {
      cache.controllato = ora;
      return cache.catalogo;
    }
    const { data: righe, error: errR } = await db.from("catalog_entries")
      .select("domain, id, sort, active, label_it, label_en, data");
    if (errR) throw new Error(errR.message);
    if (!Array.isArray(righe) || righe.length === 0) throw new Error("catalogo vuoto");
    cache = { catalogo: { voci: righe.map(daRiga) }, versione, controllato: ora };
    return cache.catalogo;
  } catch (e) {
    console.error("[catalogo] lettura non riuscita, uso la copia:", (e as Error).message);
    // Anche l'errore conta come controllo: non si riprova a ogni richiesta.
    cache = { catalogo: riserva, versione: cache?.versione ?? null, controllato: ora };
    return riserva;
  }
}

/** Le voci di un dominio, ordinate; con [soloAttive] solo quelle da proporre. */
export function voci(c: Catalogo, dominio: string, soloAttive = true): VoceCatalogo[] {
  return c.voci.filter((v) => v.domain === dominio && (!soloAttive || v.active))
    .sort((a, b) => a.sort - b.sort);
}

/** La voce [id] di [dominio], anche disattivata. */
export function voce(c: Catalogo, dominio: string, id: string): VoceCatalogo | undefined {
  return c.voci.find((v) => v.domain === dominio && v.id === id);
}

/** Le attivita' per il generatore: un id (anche di una voce disattivata) diventa
 *  i suoi testi; un valore che non e' un id resta com'e' (le app vecchie mandano
 *  gia' i testi). Senza doppioni, nell'ordine della prima comparsa. */
export function testiAttivita(c: Catalogo, valori: string[]): string[] {
  const out: string[] = [];
  for (const valore of valori) {
    const testi = voce(c, "activity", valore)?.data.generator;
    for (const t of Array.isArray(testi) ? testi : [valore]) if (!out.includes(t)) out.push(t);
  }
  return out;
}

/** L'alloggio per il generatore: un id diventa il suo testo; un altro valore
 *  resta com'e'. */
export function testoAlloggio(c: Catalogo, valore: string | null | undefined): string | null {
  if (valore == null) return null;
  const testo = voce(c, "stay", valore)?.data.generator;
  return typeof testo === "string" ? testo : valore;
}
