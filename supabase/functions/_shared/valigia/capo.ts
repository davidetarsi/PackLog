// Il capo dell'armadio come lo vede il generatore. Porting della classe Garment
// e di load_inventory del bench (packlog_checklist_bench_48.py).
import { perIlGeneratore } from "./tassonomia.ts";
import { senzaAccenti } from "./py.ts";

/** Categorie dei capi da vestire: con i metadati non sono mai intimo. */
export const CATEGORIE_DA_VESTIRE = new Set(["Upper Body", "Lower Body", "Full Body", "Outerwear"]);

export interface Capo {
  id: string;
  name: string;
  house_id: string;
  category: string;
  /** Sottocategoria per la logica: il genitore per le nuove (Fleece -> Sweater). */
  sub_category: string;
  /** Sottocategoria come l'ha scritta lo scan. */
  sub_fine: string;
  /** Giacca o tuta da sci in un viaggio senza neve; null = non ancora deciso. */
  solo_neve: boolean | null;
  base_color: string;
  pattern: string;
  coverage: string;
  fit: string;
  warmth: number | null;
  formality: string;
  activity_tags: string[];
  sempre_in_valigia: boolean;
  water_resistance: number | null;
  bulk: number | null;
  has_metadata: boolean;
}

/** Una riga della tabella items: nome e ai_metadata (stringa JSON o oggetto). */
export interface RigaArmadio {
  id: string | number;
  name?: string | null;
  house_id?: string | number | null;
  ai_metadata?: string | Record<string, unknown> | null;
  category?: string | null;
}

// ── Dizionario "porta sempre": intimo, calze, pigiama, igiene ───────────────
// Riconoscimento per RADICE del nome: non finiscono mai in una foto.
export const RADICI_SEMPRE = [
  "mutand", "slip", "boxer", "perizoma", "intim", "underwear", "brief",
  "calz", "sock", "reggisen", "bra ", "canottiera intima",
  "pigiama", "pyjama", "pajama", "camicia da notte",
  "beauty", "trousse", "necessaire", "nécessaire", "washbag", "toilette",
  "spazzolin", "dentifric", "shampoo", "deodorant",
  "ciabatt", "infradito da doccia",
];

export function radiceSempre(nome: string): string | null {
  const low = senzaAccenti(nome.toLowerCase());
  for (const r of RADICI_SEMPRE) {
    if (low.includes(senzaAccenti(r))) return r;
  }
  return null;
}

export function eSempreInValigia(nome: string, categoria = ""): boolean {
  if (radiceSempre(nome)) return true;
  const c = categoria.toLowerCase();
  return c === "toiletries" || c === "igiene";
}

function str(v: unknown): string {
  return typeof v === "string" ? v : "";
}

/** Come load_inventory: un capo per riga, metadati dallo scan quando ci sono. */
export function caricaArmadio(righe: RigaArmadio[]): Capo[] {
  return righe.map((r) => {
    const g: Capo = {
      id: String(r.id ?? ""), name: r.name || "", house_id: String(r.house_id || ""),
      category: "", sub_category: "", sub_fine: "", solo_neve: null, base_color: "",
      pattern: "", coverage: "", fit: "", warmth: null, formality: "", activity_tags: [],
      sempre_in_valigia: false, water_resistance: null, bulk: null, has_metadata: false,
    };
    g.sempre_in_valigia = eSempreInValigia(g.name);
    const raw = r.ai_metadata;
    if (raw) {
      let m: Record<string, unknown> | null = null;
      try {
        m = typeof raw === "string" ? JSON.parse(raw) : raw;
      } catch {
        m = null;
      }
      if (m && typeof m === "object" && !Array.isArray(m)) {
        g.category = str(m.category ?? "");
        g.sub_fine = str(m.subCategory ?? "");
        g.sub_category = perIlGeneratore(g.sub_fine) || "";
        g.base_color = str(m.baseColor ?? "");
        g.pattern = str(m.pattern ?? "");
        g.coverage = str(m.coverage ?? "");
        g.fit = str(m.fit ?? "");
        g.warmth = (m.warmth as number | null | undefined) ?? null;
        g.formality = str(m.formality ?? "");
        g.activity_tags = Array.isArray(m.activityTags) ? [...(m.activityTags as string[])] : [];
        g.water_resistance = (m.waterResistance as number | null | undefined) ?? null;
        g.bulk = (m.bulk as number | null | undefined) ?? null;
        g.has_metadata = true;
        if (g.category === "Essentials") g.sempre_in_valigia = true;
        // un capo da vestire non e' intimo anche se il nome ha una radice dell'intimo
        // (la calzamaglia termica non sono calzini)
        else if (CATEGORIE_DA_VESTIRE.has(g.category)) g.sempre_in_valigia = false;
      }
    }
    return g;
  });
}
