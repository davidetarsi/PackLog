// Quantita' ed essenziali: deterministico, nessuna AI. Porting delle sezioni
// "Quantita" e "porta sempre" di packlog_checklist_bench_48.py; il PERCHE' di
// ogni numero e' commentato la'.
import * as rc from "./regole_capi.ts";
import { radiceSempre, type Capo } from "./capo.ts";
import { floorDiv, pyRound, senzaAccenti } from "./py.ts";

// ── Essenziali (intimo, calze, pigiama, igiene) ─────────────────────────────
export const TETTO_ESSENZIALI_EXTRA = 2;
export const USI_PER_PEZZO: Record<string, number> = {
  "mutand": 1, "slip": 1, "boxer": 1, "perizoma": 1, "intim": 1,
  "underwear": 1, "brief": 1, "calz": 1, "sock": 1, "reggisen": 2, "bra ": 2,
  "canottiera intima": 1,
  "pigiama": 4, "pyjama": 4, "pajama": 4, "camicia da notte": 4,
};
export const RADICI_NOTTE = new Set(["pigiama", "pyjama", "pajama", "camicia da notte"]);
export const RADICE_DA_SOTTOCAT: Record<string, string> = { Underwear: "underwear", Socks: "sock", Pajamas: "pigiama" };

export interface Essenziale {
  item: string;
  item_id: string;
  radice: string;
  quantita: number;
  bulk: number;
}

const ceilDiv = (a: number, b: number) => -floorDiv(-a, b);

export function essenzialiPerViaggio(items: Capo[], giorni: number, lavatrice: boolean): Essenziale[] {
  const out: Essenziale[] = [];
  const visti = new Set<string>();
  for (const g of items) {
    if (!g.sempre_in_valigia) continue;
    const r = radiceSempre(g.name) || RADICE_DA_SOTTOCAT[g.sub_fine] || null;
    if (r != null && visti.has(r)) continue;   // una sola voce per tipo
    if (r != null && RADICI_NOTTE.has(r)) {      // una sola cosa per la notte
      if (visti.has("notte")) continue;
      visti.add("notte");
    }
    if (r) visti.add(r);
    const usi = USI_PER_PEZZO[r ?? ""] ?? 99;
    let qta: number;
    if (r != null && RADICI_NOTTE.has(r)) {
      qta = rc.pigiamiPerViaggio(giorni);
    } else if (usi >= 99) {
      qta = 1;
    } else {
      qta = ceilDiv(giorni, usi) + 1;
      if (lavatrice) qta = Math.min(qta, ceilDiv(5, usi) + 1);
      qta = Math.min(qta, giorni + TETTO_ESSENZIALI_EXTRA);
    }
    out.push({ item: g.name, item_id: g.id, radice: r || "categoria", quantita: qta, bulk: g.bulk || 1 });
  }
  return out;
}

// ── Usi prima del lavaggio ──────────────────────────────────────────────────
export const WEARS_BEFORE_WASH: Record<string, number> = {
  "T-Shirt": 1, "Tank Top": 1, "Crop Top": 1, "Polo": 2, "Shirt": 2,
  "Swimwear": 2, "Leggings": 2, "Shorts": 3, "Skirt": 3,
  "Sweatpants": 3, "Trousers": 2, "Jeans": 3,
  "Hoodie": 5, "Sweatshirt": 5, "Sweater": 5,
  "Coat": 99, "Rain Jacket": 99, "Down Jacket": 99,
  "Windbreaker": 99, "Blazer": 99,
  "Sneakers": 99, "Boots": 99, "Sandals": 99, "Flip-Flops": 99,
  "Loafers": 99, "Dress Shoes": 99, "Hiking Boots": 99,
  "Cap/Hat": 99, "Belt": 99, "Bag": 99, "Scarf": 99,
  "Sunglasses": 99, "Jewelry": 99, "Watch": 99,
};
export const DEFAULT_WEARS = 3;
export const UNDERWEAR_HINTS = ["intimo", "calz", "mutand", "slip", "boxer", "sock"];
export const FREQUENCY_FACTOR: Record<string, number> = { daily: 1.0, occasional: 0.4, once: 0.0 };
export const MOLTIPLICATORE_USI: Record<string, number> = { bassa: 1.0, media: 1.0, alta: 0.5 };
export const SOTTOCAT_SENZA_INTENSITA = new Set(["Trousers", "Jeans", "Shorts", "Skirt", "Leggings", "Sweatpants"]);
export const SOGLIA_T_SHIRT_DUE_GIORNI = 18.0;
export const UN_CAPO_LEGGERO_AL_GIORNO = true;
export const SOTTOCAT_DUE_GIORNI_SOTTO_SOGLIA = new Set(["T-Shirt"]);

export function normIntensita(valore: unknown): string | null {
  if (typeof valore !== "string") return null;
  const v = valore.trim().toLowerCase();
  return v in MOLTIPLICATORE_USI ? v : null;
}

export function usiSottoSoglia(sub: string, tempMax: number | null | undefined, intensita: string | null | undefined): boolean {
  return SOTTOCAT_DUE_GIORNI_SOTTO_SOGLIA.has(sub) && tempMax != null &&
    tempMax < SOGLIA_T_SHIRT_DUE_GIORNI && intensita !== "alta";
}

// ── Mare e acqua ────────────────────────────────────────────────────────────
export const MAX_COSTUMI = rc.MAX_COSTUMI;
export const MEZZI_GIORNI_DI_MARE = true;
export const RADICI_MARE_VERO = ["mare", "spiaggia", "snorkel", "immersion", "surf"];
export const RADICI_GIORNI_ACQUA_IN_PIU = ["immersion", "snorkel", "surf", "spiaggia"];
export const RADICI_ACQUA = ["mare", "sauna", "swim", "terme", "termal", "onsen", "piscin", "nuot"];
export const PAROLE_SERA = ["cena", "cene", "ristorante", "vita notturna", "concert", "teatro", "serata"];

export function eAttivitaAcqua(attivita: string[] | null | undefined): boolean {
  const norm = (attivita ?? []).map((a) => senzaAccenti(a.toLowerCase().trim()));
  return norm.some((a) => RADICI_ACQUA.some((r) => a.includes(senzaAccenti(r))));
}

export function giorniDiMare(giorni: number, attivita: string[] | null | undefined): number {
  const diGiorno = (attivita ?? []).filter((a) => !PAROLE_SERA.some((p) => a.toLowerCase().includes(p)));
  const norm = (a: string) => senzaAccenti(a.toLowerCase().trim());
  const radici = [...RADICI_ACQUA, ...RADICI_GIORNI_ACQUA_IN_PIU];
  const inAcqua = diGiorno.filter((a) => radici.some((r) => norm(a).includes(senzaAccenti(r))));
  if (!inAcqua.length) return 0;
  let stima = Math.max(1, Math.floor(giorni * inAcqua.length / diGiorno.length));
  const diMare = inAcqua.some((a) => RADICI_MARE_VERO.some((r) => norm(a).includes(r)));
  if (MEZZI_GIORNI_DI_MARE && diMare) stima = Math.max(stima, rc.minimoGiorniDiMare(giorni));
  return stima;
}

export function costumiPerViaggio(giorniMare: number, _frequency = "daily"): number {
  return rc.costumiPerGiorniDiMare(giorniMare);
}

export function quantityFor(sub: string, name: string, giorni: number, lavatrice: boolean,
  frequency = "daily", intensita: string | null = null, tempMax: number | null = null,
  giorniMare: number | null = null, calore: number | null = null): number {
  if (sub === "Swimwear" && MAX_COSTUMI) {
    if (giorniMare == null && frequency === "once") return 1;
    return costumiPerViaggio(giorniMare == null ? giorni : giorniMare, frequency);
  }
  const lowered = name.toLowerCase();
  let wears: number;
  if (UNDERWEAR_HINTS.some((h) => lowered.includes(h))) {
    wears = 1;
  } else {
    wears = WEARS_BEFORE_WASH[sub] ?? DEFAULT_WEARS;
    if (wears < 99 && !SOTTOCAT_SENZA_INTENSITA.has(sub)) {
      // int(x + 0.5) di Python: tronca verso zero (qui x e' sempre positivo)
      wears = Math.max(1, Math.trunc(wears * (MOLTIPLICATORE_USI[intensita ?? ""] ?? 1.0) + 0.5));
    }
    if (usiSottoSoglia(sub, tempMax, intensita)) wears = Math.max(wears, 2);
    if (UN_CAPO_LEGGERO_AL_GIORNO && frequency === "daily" && rc.caldoUnCapoAlGiorno(tempMax) &&
      rc.capoSopraLeggero("Upper Body", sub, calore)) {
      wears = 1;
    }
  }
  if (wears >= 99) return 1;
  if (frequency === "once") return 1;
  const giorniEffettivi = Math.max(1, pyRound(giorni * (FREQUENCY_FACTOR[frequency] ?? 1.0)));
  let needed = ceilDiv(giorniEffettivi, wears);
  if (lavatrice) needed = Math.min(needed, ceilDiv(4, wears) + 1);
  return Math.max(1, needed);
}
