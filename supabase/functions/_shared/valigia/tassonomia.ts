// Tassonomia dei capi: categorie e sottocategorie, decisa con Davide il
// 19 ottobre 2026. Porting di tassonomia.py del bench
// (AI-checklist-test-script): stesso contenuto, stesse funzioni.
//
import { type Catalogo, CATALOGO_BASE, voci } from "../catalogo/catalogo.ts";

// Ogni sottocategoria nuova ha un GENITORE, la vecchia piu' vicina, oppure
// null: con genitore il generatore la tratta come il genitore, senza entra
// solo dove una regola la chiede. "Other" c'e' in ogni categoria.

// Dal 31 ottobre i valori vengono dal catalogo dei tag (catalogo.json, o la
// tabella catalog_entries quando la funzione la legge: impostaTassonomia).
// Le strutture qui sotto sono le stesse di prima e si riempiono sul posto, cosi'
// chi le importa vede sempre il catalogo in uso.

/** categoria -> sottocategorie che c'erano prima del 19 ottobre. */
export const VECCHIE: Record<string, string[]> = {};

// sottocategoria nuova -> [categoria, genitore, spiegazione per il prompt]
export const NUOVE: Record<string, [string, string | null, string]> = {};
export const ALTRO = "Other";

export const SPIEGA_VECCHIE: Record<string, string> = {};

export const CATEGORIE: string[] = [];

/** categoria -> tutte le sottocategorie (anche disattivate: servono per leggere
 *  i capi salvati), nell'ordine del catalogo, con "Other" in fondo. */
export const SOTTOCATEGORIE: Record<string, string[]> = {};

export const GENITORE: Record<string, string | null> = {};

/** Le sottocategorie da proporre al modello: le voci attive del catalogo. */
export const TIPI_ATTIVI = new Set<string>();

function svuota(o: Record<string, unknown>): void {
  for (const k of Object.keys(o)) delete o[k];
}

/** Riempie la tassonomia dal catalogo. Una voce con genitore il generatore la
 *  tratta come il genitore; "Other" vale in ogni categoria. */
export function impostaTassonomia(c: Catalogo): void {
  for (const o of [VECCHIE, NUOVE, SPIEGA_VECCHIE, SOTTOCATEGORIE, GENITORE]) svuota(o);
  CATEGORIE.splice(0, CATEGORIE.length, ...voci(c, "clothing_group", false).map((v) => v.id));
  TIPI_ATTIVI.clear();
  for (const cat of CATEGORIE) SOTTOCATEGORIE[cat] = [];
  for (const t of voci(c, "clothing_type", false)) {
    if (t.id === ALTRO) continue;
    const cat = String(t.data.group);
    if (!SOTTOCATEGORIE[cat]) continue;
    SOTTOCATEGORIE[cat].push(t.id);
    if (t.active) TIPI_ATTIVI.add(t.id);
    if (t.data.isNew) {
      NUOVE[t.id] = [cat, t.data.parent ?? null, t.data.hint ?? ""];
      GENITORE[t.id] = t.data.parent ?? null;
    } else {
      (VECCHIE[cat] ??= []).push(t.id);
      if (t.data.hint) SPIEGA_VECCHIE[t.id] = t.data.hint;
    }
  }
  for (const cat of CATEGORIE) SOTTOCATEGORIE[cat].push(ALTRO);
}

impostaTassonomia(CATALOGO_BASE);

/** La sottocategoria con cui ragiona la logica: il genitore se c'e'. */
export function perIlGeneratore(sottocat: string | null | undefined): string | null | undefined {
  if (sottocat == null) return sottocat;
  return GENITORE[sottocat] || sottocat;
}

export function categoriaDi(sottocat: string): string | null {
  for (const c of CATEGORIE) {
    if (sottocat !== ALTRO && SOTTOCATEGORIE[c].includes(sottocat)) return c;
  }
  return null;
}

/** Le righe "categoria -> sottocategorie" per i prompt (scan e nome): solo le
 *  sottocategorie attive, e "Other". */
export function testoPerPrompt(): string {
  return CATEGORIE.map((c) => {
    const voci = SOTTOCATEGORIE[c].filter((s) => s === ALTRO || TIPI_ATTIVI.has(s)).map((s) => {
      const spiega = NUOVE[s]?.[2] || SPIEGA_VECCHIE[s];
      return spiega ? `"${s}" (${spiega})` : `"${s}"`;
    });
    return `  ${c} → ` + voci.join(", ");
  }).join("\n");
}
