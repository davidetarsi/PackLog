// Il passo dei kit di pack-trip: dopo il generatore e prima dei posti. Un kit e' un gruppo
// di oggetti della casa che partono insieme (spec kit § 3.3): non cambia il generatore,
// decide solo quali oggetti entrano da soli (strada 1) e quali kit meritano una domanda (strada 2).
import type { Capo as CapoArmadio } from "./capo.ts";
import type { PostoApp } from "./posti.ts";
import type { CapoApp } from "./uscita.ts";

export interface KitIngresso {
  id: string;
  attivita: string[];
  mezzi: string[];
  oggetti: { item_id: string; copie: number }[];
}
export interface KitAggiunto { kit_id: string; item_id: string; copie: number }
export interface KitSuggerito {
  kit_id: string;
  presi: number;
  totale: number;
  mancanti: { item_id: string; copie: number }[];
}

/** Gli oggetti distinti del kit che stanno nell'armadio, col massimo delle copie se ripetuti. */
function oggettiValidi(k: KitIngresso, armadio: Set<string>): Map<string, number> {
  const m = new Map<string, number>();
  for (const o of k.oggetti) {
    if (!armadio.has(o.item_id)) continue;
    m.set(o.item_id, Math.max(m.get(o.item_id) ?? 0, o.copie));
  }
  return m;
}

/** I kit del viaggio. `viaggio.attivita` e' l'unione delle attivita' del viaggio e di ogni tappa
 *  (id grezzi del catalogo). Strada 1: il kit ha un'attivita' o un mezzo del viaggio, ogni suo
 *  oggetto entra con le copie massime fra kit e capi. Strada 2: il generatore ha gia' preso almeno
 *  meta' degli oggetti (e almeno 2) ma non tutti; si propone il kit coi mancanti. */
export function kitDelViaggio(
  kit: KitIngresso[], capi: CapoApp[], viaggio: { attivita: string[]; mezzi: string[] }, armadio: Set<string>,
): { aggiunti: KitAggiunto[]; suggeriti: KitSuggerito[] } {
  const attivita = new Set(viaggio.attivita);
  const mezzi = new Set(viaggio.mezzi);
  const inCapi = new Map<string, number>();
  for (const c of capi) inCapi.set(c.item_id, Math.max(inCapi.get(c.item_id) ?? 0, c.quantita));

  const aggiunti: KitAggiunto[] = [];
  const candidati: (KitSuggerito & { ordine: number })[] = [];
  kit.forEach((k, ordine) => {
    const oggetti = oggettiValidi(k, armadio);
    if (k.attivita.some((a) => attivita.has(a)) || k.mezzi.some((m) => mezzi.has(m))) {
      for (const [item_id, copie] of oggetti) {
        aggiunti.push({ kit_id: k.id, item_id, copie: Math.max(copie, inCapi.get(item_id) ?? 0) });
      }
      return;
    }
    const totale = oggetti.size;
    const presi = [...oggetti.keys()].filter((id) => inCapi.has(id)).length;
    if (!(presi < totale && presi >= 2 && presi * 2 >= totale)) return;
    candidati.push({ kit_id: k.id, presi, totale, ordine,
      mancanti: [...oggetti].filter(([id]) => !inCapi.has(id)).map(([item_id, copie]) => ({ item_id, copie })) });
  });
  const suggeriti = candidati.sort((a, b) => b.presi - a.presi || a.ordine - b.ordine)
    .map(({ ordine: _o, ...s }) => s);
  return { aggiunti, suggeriti };
}

/** I posti dopo i kit: ogni oggetto aggiunto che il generatore non aveva gia' scelto (`capi`)
 *  riempie il posto con `tipo` uguale alla sua sottocategoria, altrimenti alla sua categoria, e
 *  ne fa scendere le copie (a 0 il posto sparisce). Lo stesso oggetto in piu' kit conta una volta,
 *  col massimo delle copie. Gli id dei posti restano quelli di postiApp. */
export function riempiPostiConKit(
  posti: PostoApp[], aggiunti: KitAggiunto[], armadio: CapoArmadio[], capi: CapoApp[] = [],
): PostoApp[] {
  const perId = new Map(armadio.map((g) => [g.id, g]));
  const gia = new Set(capi.map((c) => c.item_id));
  const copie = new Map<string, number>();
  for (const a of aggiunti) {
    if (gia.has(a.item_id) || !perId.has(a.item_id)) continue;
    copie.set(a.item_id, Math.max(copie.get(a.item_id) ?? 0, a.copie));
  }
  const rimaste = new Map(posti.map((p) => [p.id, p.copie]));
  const adatto = (p: PostoApp, g: CapoArmadio) => {
    const r = p.requisiti;
    if (!r) return true; // Risultati precedenti: manca il dettaglio dei requisiti.
    return (r.minWarmth == null || (g.warmth != null && g.warmth >= r.minWarmth)) &&
      (r.maxWarmth == null || (g.warmth != null && g.warmth <= r.maxWarmth)) &&
      (!r.formality?.length || r.formality.includes(g.formality ?? "")) &&
      (g.water_resistance ?? 0) >= (r.minWaterResistance ?? 0);
  };
  for (const [id, n] of copie) {
    const g = perId.get(id)!;
    // Prima i posti della sottocategoria, poi quelli della categoria: lo stesso
    // tipo puo' avere piu' posti (quello del meteo e' a parte), e le copie che
    // avanzano dal primo passano al successivo.
    let resto = n;
    for (const p of [...posti.filter((x) => x.tipo === g.sub_fine || x.tipo === g.sub_category),
      ...posti.filter((x) => x.tipo === g.category)]) {
      if (resto <= 0) break;
      if (!adatto(p, g)) continue;
      const ha = rimaste.get(p.id)!;
      if (ha <= 0) continue;
      const tolte = Math.min(ha, resto);
      rimaste.set(p.id, ha - tolte);
      resto -= tolte;
    }
  }
  return posti.map((p) => ({ ...p, copie: rimaste.get(p.id)! })).filter((p) => p.copie > 0);
}
