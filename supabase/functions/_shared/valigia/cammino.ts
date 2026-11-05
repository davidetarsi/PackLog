// Politica del cammino: stessi bisogni tecnici del trekking, pochi ricambi da lavare.
import type { Capo } from "./capo.ts";

type Record_ = Record<string, any>;
export function eCammino(attivita: (string | null)[] | null | undefined): boolean {
  return (attivita ?? []).some((a) => (a ?? "").toLowerCase().includes("cammino"));
}
export function interoCammino(v: Record_ | null | undefined): boolean {
  const tappe = v?.tappe ?? v?.legs ?? [];
  return eCammino(v?.attivita) || (tappe.length > 0 && tappe.every((t: Record_) => eCammino(t.attivita)));
}

const TIPI: Record<string, string[]> = {
  "Upper Body": ["T-Shirt", "Thermal Top", "Fleece", "Sweater", "Hoodie", "Sweatshirt"],
  "Lower Body": ["Trousers", "Shorts", "Leggings", "Thermal Bottoms", "Ski Pants"],
  "Outerwear": ["Rain Jacket", "Windbreaker", "Down Jacket", "Vest"],
  "Shoes": ["Sneakers", "Hiking Boots", "Boots", "Flip-Flops", "Sandals"],
};
const RIPOSO = new Set(["Flip-Flops", "Sandals"]);
export function ammessoCammino(g: Capo, mite = false, acqua = false): boolean {
  if (g.sempre_in_valigia || !["Upper Body", "Lower Body", "Outerwear", "Shoes", "Full Body"].includes(g.category)) return true;
  if (acqua && ["Swimwear", "Wetsuit", "Water Shoes"].includes(g.sub_fine)) return true;
  if (!TIPI[g.category]?.includes(g.sub_fine)) return false;
  if (g.category === "Shoes" && RIPOSO.has(g.sub_category)) return !g.formality ||
    ["Casual", "Loungewear"].includes(g.formality);
  if (g.activity_tags.includes("Hiking")) return true;
  if (["T-Shirt", "Thermal Top", "Leggings"].includes(g.sub_fine) && g.activity_tags.includes("Sport")) return true;
  // Una maglia quotidiana puo' essere da riposo, mai sostituire un requisito Hiking.
  return mite && g.sub_fine === "T-Shirt" && (g.warmth ?? 3) <= 2 && g.activity_tags.includes("Everyday");
}

export function armadioCammino(items: Capo[], mite = false, acqua = false): Capo[] {
  return items.filter((g) => ammessoCammino(g, mite, acqua)).map((g) => g.category === "Shoes" && RIPOSO.has(g.sub_category)
    ? { ...g, sempre_in_valigia: false } : g);
}

/** Normalizza anche i ripieghi del modello e i gap: il solo calore non abilita un capo urbano. */
export function vincoliCammino(s: Record_, acqua = false): Record_ {
  const ammessi = TIPI[s.category];
  if (!ammessi) return s;
  const dati = s.subCategories ?? s.requiredSubcategories;
  const originali = Array.isArray(dati) ? dati : [];
  if (acqua && originali.length && originali.every((t: string) => ["Swimwear", "Wetsuit", "Water Shoes"].includes(t))) return s;
  let subs = originali.filter((t: string) => ammessi.includes(t));
  if (!subs.length) subs = s.category === "Outerwear" ? ["Down Jacket", "Rain Jacket", "Windbreaker"]
    : s.category === "Lower Body" ? ["Trousers", "Shorts"] : s.category === "Upper Body" ? ["T-Shirt"]
    : ["Sneakers", "Hiking Boots", "Boots"];
  const riposo = (s.category === "Shoes" && subs.every((t: string) => RIPOSO.has(t))) ||
    (s.category === "Upper Body" && s._riposo_cammino && subs.every((t: string) => t === "T-Shirt"));
  const tags = riposo ? (s.category === "Upper Body" ? ["Everyday"] : []) : s.category === "Upper Body" && subs.every((t: string) => ["T-Shirt", "Thermal Top"].includes(t))
    ? ["Hiking", "Sport"] : ["Hiking"];
  return { ...s, subCategories: subs, ...(s.requiredSubcategories ? { requiredSubcategories: subs } : {}),
    activityTags: tags, requiredActivityTags: tags, formality: [], _tag_rigido: !riposo,
    ...(riposo ? { _riposo_cammino: true, frequency: "once" } : {}) };
}

export function famigliaCammino(sub: string, radice = ""): string | null {
  if (["mutand", "slip", "boxer", "perizoma", "intim", "underwear", "brief"].includes(radice) || sub === "Underwear" || sub === "intimo") return "intimo";
  if (["calz", "sock"].includes(radice) || sub === "Socks" || sub === "calzini") return "calzini";
  if (["pigiama", "pyjama", "pajama", "camicia da notte"].includes(radice) || sub === "Pajamas" || sub === "notte") return "notte";
  if (["T-Shirt", "Thermal Top", "Tank Top", "Polo", "Shirt"].includes(sub)) return "maglie";
  if (["Trousers", "Shorts", "Jeans", "Leggings"].includes(sub)) return "pantaloni";
  if (["Fleece", "Sweater", "Hoodie", "Sweatshirt"].includes(sub)) return "medio";
  if (RIPOSO.has(sub)) return "ciabatte";
  if (["Sneakers", "Boots", "Hiking Boots", "Shoes"].includes(sub)) return "scarpe";
  return null;
}
export const BUDGET_CAMMINO: Record<string, number> = {
  maglie: 3, pantaloni: 2, medio: 1, scarpe: 1, ciabatte: 1, intimo: 3, calzini: 3, notte: 1,
};

/** Opera sulle copie complessive, non per slot; i capi piu' protettivi conservano il posto. */
export function limitaDotazioneCammino(capi: Record_[], items: Capo[], richiesti: Record_[],
  puoTogliere: (capo: Record_) => boolean = () => true): void {
  const perId = new Map(items.map((g) => [g.id, g]));
  let riposo = 1;
  const pioggiaScarpe = Math.max(0, ...richiesti.filter((r) => r.category === "Shoes" && !r._riposo_cammino &&
    !(r.subCategories ?? []).every((s: string) => RIPOSO.has(s) || s === "Water Shoes"))
    .map((r) => Number(r.minWaterResistance ?? 0)));
  const rimasti = { ...BUDGET_CAMMINO };
  const ordinati = [...capi].sort((a, b) => (b.warmth ?? 0) - (a.warmth ?? 0) ||
    (b.waterResistance ?? 0) - (a.waterResistance ?? 0));
  for (const g of ordinati) {
    const meta = perId.get(String(g.item_id));
    const famiglia = famigliaCammino(meta?.sub_fine ?? g.subCategory ?? "", g.radice);
    if (!famiglia) continue;
    if (famiglia === "scarpe" && (g.waterResistance ?? 0) < pioggiaScarpe) {
      g.quantita = 0;
      for (const a of g.assegnazioni ?? []) a.quantita = 0;
      continue;
    }
    const quotidiana = meta?.sub_fine === "T-Shirt" && !ammessoCammino(meta);
    let quanti = Math.min(g.quantita ?? 1, rimasti[famiglia], quotidiana ? riposo : Infinity);
    // Il ricambio puo' essere una protezione indispensabile per un'altra tappa.
    if (quanti === 0 && (g.quantita ?? 1) > 0 && !puoTogliere(g)) quanti = 1;
    g.quantita = quanti;
    if (quotidiana) riposo -= g.quantita;
    rimasti[famiglia] = Math.max(0, rimasti[famiglia] - g.quantita);
    for (const a of g.assegnazioni ?? []) a.quantita = Math.min(a.quantita ?? 1, g.quantita);
  }
}

/** Riserva le copie veramente possedute prima di assegnare lo stesso budget alle proposte. */
export function limitaProposteCammino<T extends { tipo: string; copie: number; requisiti?: { minWarmth?: number; maxWarmth?: number } }>(posti: T[],
  valigia: Record_, disponibili: (id: string) => number, items: Capo[]): T[] {
  const perId = new Map(items.map((g) => [g.id, g]));
  const rimasti = { ...BUDGET_CAMMINO };
  const climi: Record<string, [number, number][]> = { medio: [], maglie: [] };
  for (const g of [...(valigia.ideali ?? []), ...(valigia.ripieghi ?? []), ...(valigia.essenziali ?? [])]) {
    const famiglia = famigliaCammino(perId.get(String(g.item_id))?.sub_fine ?? g.subCategory ?? "", g.radice);
    if (!famiglia) continue;
    if (climi[famiglia] && g.quantita > 0) climi[famiglia].push([g.warmth ?? 3, g.warmth ?? 3]);
    rimasti[famiglia] = Math.max(0, rimasti[famiglia] - Math.min(g.quantita ?? 1, disponibili(String(g.item_id))));
  }
  return posti.flatMap((p) => {
    const famiglia = famigliaCammino(p.tipo);
    if (!famiglia) return [p];
    let copie = Math.min(p.copie, rimasti[famiglia]);
    if (climi[famiglia]) {
      const fascia: [number, number] = [p.requisiti?.minWarmth ?? 1, p.requisiti?.maxWarmth ?? 5];
      // Come per i capi posseduti, climi incompatibili possono richiedere uno strato protettivo diverso.
      if (!copie && !climi[famiglia].some(([lo, hi]) => Math.max(lo, fascia[0]) <= Math.min(hi, fascia[1]))) copie = 1;
      if (copie) climi[famiglia].push(fascia);
    }
    rimasti[famiglia] = Math.max(0, rimasti[famiglia] - copie);
    return copie > 0 ? [{ ...p, copie }] : [];
  });
}

/** Un taglio intenzionale dei ricambi non e' una mancanza dell'armadio. */
export function lacuneCammino(gaps: Record_[], capi: Record_[], items: Capo[]): Record_[] {
  const perId = new Map(items.map((g) => [g.id, g]));
  return gaps.flatMap((g) => {
    if (g.tipo !== "quantita_insufficiente") return [g];
    const famiglia = famigliaCammino((g.subCategories ?? [])[0] ?? "");
    if (!famiglia) return [g];
    const presenti = capi.filter((c) => famigliaCammino(perId.get(String(c.item_id))?.sub_fine ?? c.subCategory) === famiglia)
      .reduce((n, c) => n + c.quantita, 0);
    if (presenti >= BUDGET_CAMMINO[famiglia]) return [];
    const { capi_diversi_necessari: _vecchio, ...resto } = g;
    return [{ ...resto, usi_richiesti: BUDGET_CAMMINO[famiglia], usi_coperti: presenti }];
  });
}
