// Le regole fisse dei suggerimenti (posti.ts), controllate su un posto alla volta.
// Le usano il test regole_posti.test.ts e la misura misura_errori_posti.ts: stessa definizione,
// cosi' la tabella dei numeri e il test non possono dire cose diverse.
import { readFileSync } from "node:fs";
import { caricaArmadio, type RigaArmadio } from "../capo.ts";
import { valigiaDa } from "../genera.ts";
import { motiviValigia, tagArmadio } from "../motivi.ts";
import { analizzaFabbisogni } from "../fabbisogni.ts";
import { CALDO_FORTE, FREDDO_VERO, postiApp, viaggioFormale, type PostoApp } from "../posti.ts";
import { eAttivitaAcqua, RADICI_GIORNI_ACQUA_IN_PIU } from "../quantita.ts";
import { ha } from "../regole_capi.ts";
import { eTrekking } from "../inject.ts";
import { eCammino } from "../cammino.ts";

type Record_ = Record<string, any>;

/** Una cella del bench rigiocata dall'app con un armadio vuoto o a meta'. */
export interface CellaPosti {
  id: string;
  armadio: "vuoto" | "medio";
  attivita: string[];
  /** Per tappa (una sola se il viaggio e' in un posto): minima, massima e giorni di pioggia. */
  tappe: { tmin: number | null; tmax: number | null; pioggia: number }[];
  posti: PostoApp[];
}

const righeDegliArmadi: Record<string, RigaArmadio[]> = {};
for (const c of JSON.parse(readFileSync(new URL("./oracolo_quantita.json", import.meta.url), "utf8"))) {
  if (c.f === "carica_armadio") righeDegliArmadi[c.nome + ".json"] = c.args[0];
}

export function caricaCelle(file: string | URL): Record_[] {
  return JSON.parse(readFileSync(file, "utf8")).filter((c: Record_) => !String(c.insieme).toLowerCase().includes("v4"));
}

/** Rigioca una cella dell'oracolo come fa pack-trip: valigia, motivi, fabbisogni, posti. */
export function rigiocaCella(c: Record_, armadio: "vuoto" | "medio"): CellaPosti {
  const { scenario: sc, geo, meteo } = structuredClone(c.viaggio);
  const righe: RigaArmadio[] = armadio === "vuoto" ? [] : (righeDegliArmadi[c.armadio] ?? []).filter((_, i) => i % 2 === 0);
  const jev: Record_ = {};
  for (const k of ["voti_scarpe", "profili_capi", "scarti_capi", "classi_viaggio"]) if (c.args?.[k]) jev[k] = c.args[k];
  const valigia = valigiaDa(c.grezzo, sc, geo, meteo, righe, jev);
  const motivi = motiviValigia({ scenario: sc, meteo, slots: valigia }, tagArmadio(righe));
  const viaggio = { ...sc, ...(sc.legs?.length ? {
    tappe: sc.legs.map((l: Record_) => ({ nome: l.destinazione, giorni: l.giorni, attivita: l.attivita })),
  } : { destinazione: { nome: sc.destinazione } }) };
  const items = caricaArmadio(righe);
  const salvate = new Map<string, number | null>(righe.map((r) => [String(r.id), r.quantity ?? null]));
  const fabbisogni = analizzaFabbisogni(valigia, items, viaggio, meteo, { motivi: motivi as any, salvate });
  const { posti } = postiApp(valigia, motivi as any, salvate, { meteo, viaggio, armadio: items, lingua: "it", fabbisogni });
  const perTappa: Record_[] = Array.isArray(meteo._per_tappa) && meteo._per_tappa.length ? meteo._per_tappa : [meteo];
  const num = (x: unknown) => (x == null || !Number.isFinite(Number(x)) ? null : Number(x));
  return {
    id: `${c.insieme}/${c.id}/${String(c.armadio).replace(".json", "")}`, armadio,
    attivita: [...(sc.attivita ?? []), ...(sc.legs ?? []).flatMap((l: Record_) => l.attivita ?? [])].map(String),
    tappe: perTappa.map((t) => ({ tmin: num(t.temp_min_media), tmax: num(t.temp_max_media), pioggia: Number(t.giorni_di_pioggia ?? 0) })),
    posti,
  };
}

const TIPI_GIACCA = new Set(["Outerwear", "Coat", "Down Jacket", "Casual Jacket", "Windbreaker", "Rain Jacket"]);
const TIPI_SCARPA = new Set(["Shoes", "Sneakers", "Boots", "Hiking Boots", "Loafers", "Dress Shoes", "Snow Boots"]);
const TIPI_SENZA_CALDO = new Set(["Leggings", "Shirt", "T-Shirt", "Polo", "Tank Top", "Crop Top"]);
const CALDO = /\b(caldo|calda|caldi|calde)\b/i;

/** Le regole che il suggerimento non deve violare: la chiave di ogni violazione e' la sua descrizione. */
export function violazioni(cella: CellaPosti): { regola: string; posto: string }[] {
  const out: { regola: string; posto: string }[] = [];
  const { attivita, tappe } = cella;
  const freddo = tappe.some((t) => t.tmin != null && t.tmin <= FREDDO_VERO);
  const pioggia = tappe.some((t) => t.pioggia >= 1);
  const caldoOvunque = tappe.every((t) => t.tmax != null && t.tmax >= CALDO_FORTE);
  const formale = viaggioFormale(attivita);
  const acqua = eAttivitaAcqua(attivita) || ha(attivita, RADICI_GIORNI_ACQUA_IN_PIU);
  const trekkingVero = eTrekking(attivita) && (eCammino(attivita) || attivita.some((a) => /trekking|alpinism|quota|cammin/i.test(a)));
  const no = (regola: string, p: PostoApp) => out.push({ regola, posto: `${p.livello[0]} ${p.copie}x ${p.nome}` });
  for (const p of cella.posti) {
    const importante = p.livello === "importante";
    if (p.tipo === "Umbrella" || /ombrell/i.test(p.nome)) no("nessun ombrello", p);
    if (importante && (p.requisiti?.minWaterResistance ?? 0) >= 1 && !pioggia && !freddo &&
      (TIPI_GIACCA.has(p.tipo) || TIPI_SCARPA.has(p.tipo)) && p.tipo !== "Hiking Boots") {
      no("importante per la pioggia senza giorni di pioggia", p);
    }
    if (/impermeabil/i.test(p.nome) && importante && !pioggia && p.tipo !== "Hiking Boots") no("importante 'impermeabile' senza pioggia", p);
    if (/invernal/i.test(p.nome) && TIPI_GIACCA.has(p.tipo) && !freddo) no("giacca invernale senza freddo vero", p);
    if (importante && p.tipo === "Outerwear" && !freddo && !pioggia && !formale) no("giacca importante senza freddo ne' pioggia", p);
    if (/leggera|leggere/i.test(p.nome) && TIPI_GIACCA.has(p.tipo) && importante) no("giacca leggera importante", p);
    if (/leggera|leggere/i.test(p.nome) && TIPI_GIACCA.has(p.tipo) && tappe.every((t) => t.tmin != null && t.tmin <= 10)) no("giacca leggera con minima di 10 gradi o meno", p);
    if (["Cap/Hat", "Scarf"].includes(p.tipo) && !freddo && (importante || CALDO.test(p.nome)) && !/impermeabil/i.test(p.nome)) no("cappello o sciarpa caldi/importanti senza freddo vero", p);
    if (p.tipo === "Water Shoes" && !acqua) no("scarpette da scoglio senza acqua", p);
    if (p.tipo === "Shirt" && /elegant/i.test(p.nome) && !formale) no("camicia elegante fuori dai contesti formali", p);
    if (p.tipo === "Wetsuit" && importante) no("muta importante", p);
    if (p.tipo === "Swimwear" && acqua && !importante) no("costume non importante con attivita' in acqua", p);
    if (CALDO.test(p.nome) && TIPI_SENZA_CALDO.has(p.tipo)) no("nome 'caldo' su leggings, camicie o magliette", p);
    if (importante && caldoOvunque && !trekkingVero && ["Boots", "Hiking Boots", "Snow Boots"].includes(p.tipo)) no("stivali o scarponi importanti col caldo", p);
    if (importante && caldoOvunque && /invernal/i.test(p.nome) && TIPI_SCARPA.has(p.tipo)) no("scarpe invernali importanti col caldo", p);
    if (/Scarponi da trekking invernali/i.test(p.nome) && !freddo) no("scarponi da trekking invernali senza freddo vero", p);
    if (caldoOvunque && ["Coat", "Down Jacket", "Ski Jacket", "Ski Pants", "Snow Boots", "Thermal Top", "Thermal Bottoms"].includes(p.tipo) && !attivita.some((x) => /sci|neve/i.test(x))) no("capo da freddo estremo col caldo", p);
    if (p.tipo === "Hiking Boots" && /^Scarponi/i.test(p.nome) && ((p.requisiti?.maxWarmth ?? 5) <= 2 || caldoOvunque)) no("scarponi con calore basso (sono scarpe da trekking)", p);
  }
  return out;
}
