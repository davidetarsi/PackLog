// Gli slot che impone il codice: attivita', codice di abbigliamento, clima.
// Porting delle funzioni inject_* e vicine di packlog_checklist_bench_48.py;
// il PERCHE' di ogni regola e' commentato la'. Gli slot sono oggetti liberi come
// i dict di Python (vengono dal modello e il codice li arricchisce).
import * as K from "./costanti.ts";
import * as rc from "./regole_capi.ts";
import type { Capo } from "./capo.ts";
import { eAttivitaAcqua } from "./quantita.ts";
import { pf, ps, senzaAccenti, vero } from "./py.ts";

export type Slot = Record<string, any>;
export type Record_ = Record<string, any>;

export const insieme = (xs: Iterable<any> | null | undefined) => new Set<any>(xs ?? []);
export const interseca = (a: Set<any>, b: Iterable<any>) => [...b].some((x) => a.has(x));
export const sottoinsieme = (a: Iterable<any>, b: Set<any>) => [...a].every((x) => b.has(x));
const lw = (a: string | null | undefined) => (a ?? "").toLowerCase();
const lws = (a: string) => a.toLowerCase().trim();
/** list.remove di Python: toglie il primo elemento UGUALE (per contenuto). */
export function rimuoviUguale(xs: any[], x: any): void {
  const s = JSON.stringify(x);
  const i = xs.findIndex((y) => y === x || JSON.stringify(y) === s);
  if (i >= 0) xs.splice(i, 1);
}

// ── Normalizzazione degli enum ──────────────────────────────────────────────
export const rejects: unknown[] = [];
export const fixes: unknown[] = [];

export function norm(value: unknown, allowed: Set<string>): string | null {
  if (typeof value !== "string") return null;
  const v = value.trim();
  if (allowed.has(v)) return v;
  const low = v.toLowerCase();
  for (const a of allowed) {
    if (a.toLowerCase() === low) { fixes.push(value); return a; }
  }
  if (low in K.SYNONYMS && allowed.has(K.SYNONYMS[low])) { fixes.push(value); return K.SYNONYMS[low]; }
  rejects.push(value);
  return null;
}

export function normList(values: unknown, allowed: Set<string>): Set<string> {
  const out = new Set<string>();
  const vs = Array.isArray(values) ? values : (vero(values) ? [...(values as any)] : []);
  for (const v of vs) { const x = norm(v, allowed); if (x) out.add(x); }
  return out;
}

export function warmthFloor(tempMin: number | null | undefined): number {
  if (tempMin == null) return 1;
  let floor = 1;
  for (const [soglia, w] of K.WARMTH_FLOOR) if (tempMin >= soglia) floor = w;
  return floor;
}

export function warmthCeiling(tempMax: number | null | undefined): number {
  if (tempMax == null) return 5;
  if (tempMax >= 30) return 1;
  if (tempMax >= 25) return 2;
  if (tempMax >= 22) return 3;
  if (tempMax >= 18) return 4;
  return 5;
}

export function eTrekking(attivita: (string | null)[] | null | undefined): boolean {
  return (attivita ?? []).some((a) => K.RADICI_TREKKING.some((r: string) => lw(a).includes(r)));
}

export function jevDice(classi: Record<string, any> | null | undefined, domanda: string): boolean | null {
  if (!vero(classi) || classi![domanda] == null) return null;
  return classi![domanda] >= 0.5;
}

export function viaggioDiLavoro(attivita: string[] | null | undefined, classi: any = null): boolean {
  if ((attivita ?? []).some((a) => K.ATTIVITA_FORMALI.has(lws(a)))) return true;
  return Boolean(jevDice(classi, "lavoro_formale"));
}

export function serateCurate(attivita: string[] | null | undefined, classi: any = null): boolean {
  const j = jevDice(classi, "sera_elegante");
  if (j != null) return j;
  return (attivita ?? []).some((a) => K.PAROLE_SERA.some((p: string) => a.toLowerCase().includes(p)));
}

export function escludiFormale(giorni: number | null | undefined, capienza: number | null | undefined): boolean {
  if (capienza != null && capienza <= 8) return true;
  return !K.FORMALE_NEI_VIAGGI_BREVI && giorni != null && giorni <= 2;
}

export function injectMandatory(slots: Slot[], attivita: string[]): Slot[] {
  const presenti = insieme(slots.flatMap((s) => s.subCategories || []));
  for (const att of attivita) {
    for (const [nome, cat, subs, tags, freq] of (K.MANDATORY_SLOTS[lws(att)] ?? [])) {
      if (interseca(presenti, subs)) continue;
      slots.push({
        slot: nome, category: cat, subCategories: subs, minWarmth: 1, maxWarmth: 5, formality: [],
        activityTags: tags, frequency: freq, essential: true,
        reason: `attivita dichiarata: ${att} (slot imposto dal sistema)`, _imposto: true,
      });
    }
  }
  const giaPresenti = insieme(slots.flatMap((s) => s.subCategories || []));
  if (eAttivitaAcqua(attivita) && !giaPresenti.has("Swimwear")) {
    const [nome, cat, subs, tags, freq] = K.MANDATORY_SLOTS["mare/sauna"][0];
    slots.push({
      slot: nome, category: cat, subCategories: subs, minWarmth: 1, maxWarmth: 5, formality: [],
      activityTags: tags, frequency: freq, essential: true,
      reason: "attivita in acqua non catalogata per frase esatta, riconosciuta per radice (slot imposto dal sistema)",
      _imposto: true,
    });
  }
  return slots;
}

export function injectStratoFormale(slots: Slot[], attivita: string[], giorni: number | null = null,
  capienza: number | null = null): Slot[] {
  if (!attivita.some((a) => K.ATTIVITA_FORMALI.has(lws(a)))) return slots;
  if (escludiFormale(giorni, capienza)) return slots;
  if (slots.some((s) => { const x = insieme(s.subCategories || []); return x.size === 1 && x.has("Blazer"); })) {
    return slots;
  }
  slots.push({
    slot: "strato formale", category: "Outerwear", subCategories: ["Blazer"], minWarmth: 1, maxWarmth: 3,
    formality: ["Business", "Formal"], activityTags: ["Office"], frequency: "daily", essential: true,
    reason: "attivita' di lavoro formale: il blazer e' lo strato formale, non lo sostituisce un cappotto (slot imposto dal sistema)",
    _imposto: true,
  });
  return slots;
}

export function injectParteInferioreFormale(slots: Slot[], giorni: number | null = null,
  capienza: number | null = null): Slot[] {
  if (escludiFormale(giorni, capienza)) return slots;
  const topFormale = slots.some((s) => s.category === "Upper Body" && !vero(s._presentabili) &&
    interseca(insieme(["Business", "Formal"]), s.formality || []));
  if (!topFormale) return slots;
  if (slots.some((s) => s.category === "Lower Body" && vero(s.formality) && !s.formality.includes("Casual"))) {
    return slots;
  }
  slots.push({
    slot: "parte inferiore formale", category: "Lower Body", subCategories: ["Trousers", "Skirt"],
    minWarmth: 1, maxWarmth: 5, formality: ["Smart Casual", "Business", "Formal"], activityTags: [],
    frequency: "occasional", essential: true,
    reason: "c'e' un capo formale per la parte superiore: servono anche pantaloni o gonna formali (slot imposto dal sistema)",
    _imposto: true,
  });
  return slots;
}

export function capospallaInTracolla(capi: Record_[], capienza: number | null | undefined): Record_[] {
  if (!K.CAPOSPALLA_IN_TRACOLLA || capienza == null || capienza > 8) return capi;
  const caldi = capi.filter((x) => x.category === "Outerwear" &&
    (x.assegnazioni ?? []).some((a: any) => a.slot === K.SLOT_CAPOSPALLA_CALDO));
  if (!caldi.length) return capi;
  const caldo = caldi[0];
  caldo.in_partenza = true;
  caldo.nota_partenza = K.NOTA_CAPOSPALLA_PARTENZA;
  return capi.filter((x) => x.category !== "Outerwear" || x === caldo);
}

export function riverbero(attNorm: Set<string>, classi: any = null): boolean {
  if (interseca(attNorm, K.ATTIVITA_RIVERBERO)) return true;
  const p = (classi || {}).riverbero;
  return p != null && K.SOGLIA_JEV_RIVERBERO != null && p >= K.SOGLIA_JEV_RIVERBERO;
}

/** capo: record della valigia (oggetto con item_id) o Capo dell'armadio. */
function idCalore(capo: any): [string, any, any] {
  if ("item_id" in capo || !("sub_category" in capo)) return [capo.item_id, capo.warmth, capo.formality];
  return [capo.id, capo.warmth, capo.formality];
}

export function capoLeggero(capo: any, profili: Record<string, any> | null = null): boolean {
  const [id_, calore] = idCalore(capo);
  const p = (profili || {})[id_] || {};
  if (p.caldo_torrido != null) return p.caldo_torrido >= K.SOGLIA_CALDO_TORRIDO;
  return (calore || 3) <= K.CALORE_LEGGERO;
}

export function capoRiservato(capo: any, profili: Record<string, any> | null = null): boolean {
  const record = "item_id" in capo || !("sub_category" in capo);
  if (record && vero(capo._slot_elegante)) return true;
  const [id_, , formalita] = idCalore(capo);
  const p = (profili || {})[id_] || {};
  if (p.elegante != null && p.da_giorno != null) return p.elegante >= K.SOGLIA_ELEGANTE && p.da_giorno < K.SOGLIA_DA_GIORNO;
  return formalita === "Business" || formalita === "Formal";
}

export function penalitaCulto(slot: string | null | undefined, g: any, profili: Record<string, any> | null,
  caldo = true): number {
  if (!K.SLOT_CULTO.includes(slot)) return 0.0;
  return (capoRiservato(g, profili) ? K.PESO_ELEGANTE_DI_GIORNO : 0.0) +
    (!caldo || capoLeggero(g, profili) ? 0.0 : K.PESO_PESANTE_CULTO);
}

export function quantiStratiMedi(tempMin: number | null | undefined, tempMax: number | null | undefined): number {
  if (tempMin == null || tempMin > K.SOGLIA_STRATO_MEDIO) return 0;
  if (tempMin <= K.SOGLIA_DUE_STRATI_MEDI ||
    (tempMin <= K.SOGLIA_DUE_STRATI_GIORNO_FRESCO && tempMax != null && tempMax <= K.SOGLIA_GIORNO_FRESCO)) return 2;
  return 1;
}

export function caloreMaxStrato(tempMin: number | null | undefined): number {
  if (K.CALORE_STRATO_MITE && tempMin != null && tempMin > K.SOGLIA_DUE_STRATI_MEDI) return K.CALORE_STRATO_MITE;
  return 4;
}

export function stratiInTracolla(tempMin: number | null | undefined, servono: number): number {
  if (tempMin != null && tempMin <= K.SOGLIA_DUE_STRATI_MEDI) return Math.min(servono, 1);
  return 0;
}

export function parole(attivita: (string | null)[] | null | undefined): Set<string> {
  const out = new Set<string>();
  for (const a of attivita ?? []) for (const w of senzaAccenti((a ?? "").toLowerCase()).match(/[a-z]+/g) ?? []) out.add(w);
  return out;
}

export function segnaCapiDaNeve(items: Capo[], attivita: (string | null)[]): void {
  const neve = interseca(parole(attivita), K.PAROLE_NEVE);
  for (const g of items) if (g.solo_neve == null) g.solo_neve = K.SOTTOCAT_DA_NEVE.includes(g.sub_fine) && !neve;
}

export function slotCapiNuovi(items: Capo[], tempMin: number | null | undefined, attivita: any,
  giorniPioggia: number | null | undefined, capienza: number | null = null, gia: Slot[] | null = null,
  nome = ""): Slot[] {
  if (!K.CAPI_NUOVI || (capienza != null && capienza <= 8)) return [];
  const possiede = insieme(items.filter((g) => g.has_metadata && !g.sempre_in_valigia).map((g) => g.sub_category));
  const chiesti = insieme((gia || []).flatMap((s) => s.subCategories || []));
  const pw = parole(attivita);
  const pre = nome ? `${nome}: ` : "";
  const regole: [string, string, string, boolean, string][] = [
    ["guanti", "Accessory", "Gloves", tempMin != null && tempMin <= K.SOGLIA_ESTREMITA, `minima ${pf(tempMin)}: mani coperte`],
    ["pantaloni da neve", "Lower Body", "Ski Pants", interseca(pw, K.PAROLE_NEVE), "neve o sci"],
    ["muta", "Lower Body", "Wetsuit", interseca(pw, K.PAROLE_MUTA), "immersioni o surf"],
    ["calzamaglia termica", "Lower Body", "Thermal Bottoms", tempMin != null && tempMin <= rc.FREDDO_VERO,
      `minima ${pf(tempMin)}: uno strato termico sotto i pantaloni`],
    ["cravatta", "Accessory", "Tie", rc.occasioneFormale(attivita || []), "occasione formale"],
    ["ombrello", "Accessory", "Umbrella", K.OMBRELLO_CON_PIOGGIA && (giorniPioggia || 0) >= K.OMBRELLO_GIORNI_PIOGGIA,
      `${ps(giorniPioggia, true)} giorni di pioggia`],
  ];
  const out: Slot[] = [];
  for (const [slot, cat, sub, vale, perche] of regole) {
    if (vale && possiede.has(sub) && !chiesti.has(sub)) {
      out.push({
        slot, category: cat, subCategories: [sub], minWarmth: 1, maxWarmth: 5, formality: [], activityTags: [],
        minWaterResistance: 0, frequency: "once", essential: true, _fabbisogno: true, _imposto: true,
        senza_tetto: true, reason: pre + perche,
      });
    }
  }
  return out;
}

export function injectFabbisogno(slots: Slot[], tempMin: number | null | undefined, tempMax: number | null | undefined,
  giorniPioggia: number | null | undefined, giorni: number | null = null, capienza: number | null = null,
  attivita: string[] | null = null, classi: any = null, tempMinAssoluta: number | null = null,
  attivitaViaggio: string[] | null = null): Slot[] {
  const nuovo = (nome: string, cat: string, subs: string[], kw: Record<string, any> = {}): Slot => ({
    slot: nome, category: cat, subCategories: subs, minWarmth: 1, maxWarmth: 5, formality: [],
    activityTags: [], frequency: "daily", essential: true, _fabbisogno: true,
    reason: "fabbisogno minimo (slot imposto dal sistema)", ...kw,
  });
  const tm = pf(tempMin);

  const presenti = insieme(slots.map((s) => s.category));
  for (const [nome, cat, subs] of K.FABBISOGNO_ZONE) if (!presenti.has(cat)) slots.push(nuovo(nome, cat, subs));

  if (K.SOGLIA_STRATO_BASE == null || (tempMin != null && tempMin <= K.SOGLIA_STRATO_BASE)) {
    if (!slots.some((s) => interseca(insieme(K.SOTTOCAT_BASE), s.subCategories || []))) {
      slots.push(nuovo("strato base sulla pelle", "Upper Body", K.SOTTOCAT_BASE,
        { frequency: "daily", reason: "sotto gli strati caldi serve qualcosa sulla pelle" }));
    }
  }

  const viaggioMinimo = (giorni != null && giorni <= 2) || (capienza != null && capienza <= 8);
  const medio = insieme(K.SOTTOCAT_MEDIO);
  if (tempMin != null && tempMin <= K.SOGLIA_STRATO_MEDIO && (K.STRATI_NEI_VIAGGI_MINIMI || !viaggioMinimo)) {
    let servono = quantiStratiMedi(tempMin, tempMax);
    if (capienza != null && capienza <= 8) servono = stratiInTracolla(tempMin, servono);
    const presentiMedi = slots.filter((s) => vero(s.subCategories) && sottoinsieme(s.subCategories, medio)).length;
    for (let n = presentiMedi; n < servono; n++) {
      slots.push(nuovo(n === 0 ? "strato medio per la sera" : "secondo strato medio", "Upper Body", K.SOTTOCAT_MEDIO, {
        frequency: "occasional", minWarmth: K.CALORE_MIN_STRATO, maxWarmth: caloreMaxStrato(tempMin),
        reason: `minima ${tm}: la sera serve un maglione o una felpa`,
      }));
    }
  } else if (K.FELPA_SERA_ESTIVA && tempMin != null && tempMin > K.SOGLIA_STRATO_MEDIO &&
    rc.felpaSeraEstiva(attivita) &&
    !slots.some((s) => vero(s.subCategories) && sottoinsieme(s.subCategories, medio))) {
    slots.push(nuovo(K.SLOT_STRATO_SERA, "Upper Body", K.SOTTOCAT_MEDIO, {
      frequency: "once", minWarmth: 2, maxWarmth: rc.CALORE_FELPA_ESTIVA, _imposto: true,
      reason: "la sera al mare, al lago o in tenda serve una felpa leggera",
    }));
  }

  if (K.SLOT_TREKKING && eTrekking(attivita)) {
    if (tempMin != null && tempMin <= K.SOGLIA_STRATO_MEDIO) {
      for (const s of slots) if (s.slot === K.SLOT_STRATO_SERA || s.slot === K.SLOT_SECONDO_STRATO) s.activityTags = ["Hiking"];
    }
    const lista: [string, string, string[], string[], string, Record<string, any>][] = [
      [K.SLOT_PANTALONI_TREKKING, "Lower Body", ["Trousers"], ["Hiking"], "occasional", {}],
      [K.SLOT_MAGLIETTA_TECNICA, "Upper Body", ["T-Shirt"], ["Hiking", "Sport"], "occasional", {}],
      [K.SLOT_SCARPE_TREKKING, "Shoes", ["Hiking Boots", "Sneakers", "Boots"], ["Hiking"], "once", {}],
      [K.SLOT_ANTIVENTO_TREKKING, "Outerwear", ["Rain Jacket", "Windbreaker"], ["Hiking"], "occasional",
        (tempMin == null || tempMin > K.SOGLIA_ESTREMITA) ? { maxWarmth: 2 } : {}],
    ];
    for (const [nome, cat, subs, tags, freq, extra] of lista) {
      const largo = nome === K.SLOT_MAGLIETTA_TECNICA || !serateCurate(attivita, classi);
      const orientabili = slots.filter((s) => s.category === cat && interseca(insieme(s.subCategories || []), subs) &&
        (!vero(s.formality) || (largo && s.formality.includes("Casual")) ||
          [...insieme(s.formality)].every((f) => f === "Casual")));
      if (orientabili.length) {
        const o = orientabili[0];
        const t = insieme(o.activityTags || []);
        t.delete("Everyday");
        for (const x of tags) t.add(x);
        o.activityTags = [...t].sort();
        if (vero(o.formality)) o.formality = [...new Set([...o.formality, "Loungewear"])].sort();
        continue;
      }
      slots.push(nuovo(nome, cat, subs, {
        activityTags: tags, frequency: freq, _tag_rigido: true,
        reason: "trekking o escursioni: serve un capo pensato per camminare in montagna", ...extra,
      }));
    }
  }

  if (giorni != null && giorni >= K.GIORNI_SECONDE_SCARPE && capienza != null && capienza > 30) {
    if (slots.filter((s) => s.category === "Shoes").length < 2) {
      slots.push(nuovo("calzature di ricambio", "Shoes", ["Sneakers", "Loafers", "Boots", "Dress Shoes", "Sandals"],
        { frequency: "once", reason: `${giorni} giorni: un secondo paio di scarpe` }));
    }
  }

  if (tempMin != null && tempMin <= K.SOGLIA_CALZATURE) {
    for (const s of slots) {
      if (s.category !== "Shoes") continue;
      const subs = insieme(s.subCategories || []);
      for (const x of K.SCARPE_APERTE) subs.delete(x);
      for (const x of K.SCARPE_CHIUSE) subs.add(x);
      s.subCategories = [...subs].sort();
      if (tempMin <= K.SOGLIA_SCARPE_CALDE) {
        s.minWarmth = Math.max(Math.trunc(Number(s.minWarmth || 1)), 3);
        s._fabbisogno = true;
        s.reason = stripChars(`${s.reason ?? ""} · minima ${tm}: scarpa chiusa e calda`, " ·");
      }
    }
  }

  const outerwear = slots.filter((s) => s.category === "Outerwear");
  const allarga = (s: Slot) => {
    s.subCategories = [...new Set([...(s.subCategories || []), ...K.OUTERWEAR_METEO])].sort();
  };
  const floor = warmthFloor(tempMin);
  if (floor >= 4 && !outerwear.length) {
    const s = nuovo("capospalla per il freddo", "Outerwear", ["Coat", "Down Jacket", "Windbreaker", "Rain Jacket"],
      { minWarmth: floor, reason: `temperatura minima ${tm}: serve uno strato esterno` });
    slots.push(s);
    outerwear.push(s);
  }

  const caldoSet = insieme(K.SOTTOCAT_CAPOSPALLA_CALDO);
  if (tempMinAssoluta != null && tempMinAssoluta <= K.SOGLIA_CAPOSPALLA_CALDO &&
    (K.CAPOSPALLA_IN_TRACOLLA || !(capienza != null && capienza <= 8)) &&
    (K.CAPOSPALLA_NEI_VIAGGI_MINIMI || !(giorni != null && giorni <= 2)) &&
    !slots.some((s) => s.category === "Outerwear" && sottoinsieme(s.subCategories || [], caldoSet) &&
      (s.minWarmth || 0) >= 4)) {
    slots.push(nuovo(K.SLOT_CAPOSPALLA_CALDO, "Outerwear", [...K.SOTTOCAT_CAPOSPALLA_CALDO], {
      minWarmth: 4, frequency: "once", _imposto: true,
      reason: `minima assoluta ${pf(tempMinAssoluta)}: serve un cappotto o un piumino`,
    }));
  }

  if ((giorniPioggia || 0) >= 1 && !slots.some((s) => vero(s.minWaterResistance))) {
    if (outerwear.length) {
      outerwear[0].minWaterResistance = 1;
      outerwear[0]._fabbisogno = true;
      allarga(outerwear[0]);
    } else {
      slots.push(nuovo("protezione dalla pioggia", "Outerwear", ["Rain Jacket", "Windbreaker"],
        { minWaterResistance: 1, reason: `${ps(giorniPioggia, true)} giorni di pioggia previsti` }));
    }
  }

  if (tempMin != null && tempMin <= K.SOGLIA_ESTREMITA) {
    for (const s of [...slots]) {
      if (s.category !== "Accessory") continue;
      const tutti = s.subCategories || [];
      const resto = tutti.filter((x: string) => x !== "Cap/Hat" && x !== "Scarf");
      if (resto.length === tutti.length) continue;
      if (resto.length) s.subCategories = resto;
      else rimuoviUguale(slots, s);
    }
    const dedicati = new Set(slots.filter((s) => s.category === "Accessory").map((s) => JSON.stringify(s.subCategories || [])));
    if (!dedicati.has(JSON.stringify(["Cap/Hat"]))) {
      slots.push(nuovo("testa coperta", "Accessory", ["Cap/Hat"], { reason: `minima ${tm}: la testa disperde` }));
    }
    if (!dedicati.has(JSON.stringify(["Scarf"]))) {
      slots.push(nuovo("collo e mani", "Accessory", ["Scarf"], { reason: `minima ${tm}: collo e mani coperti` }));
    }
    for (const s of slots) {
      // cappello e sciarpa: col freddo il piu' caldo (non il foulard di seta a -2)
      const subs = JSON.stringify(s.subCategories);
      if (s.category === "Accessory" && (subs === JSON.stringify(["Cap/Hat"])
        || (subs === JSON.stringify(["Scarf"]) && s.slot !== "foulard"))) s._preferisci_calore = true;
    }
  } else if (!slots.some((s) => s.category === "Accessory")) {
    if (floor >= 4) {
      slots.push(nuovo("estremita al freddo", "Accessory", ["Cap/Hat", "Scarf"], { reason: `minima ${tm}: testa e collo coperti` }));
    } else if (warmthCeiling(tempMax) <= 1) {
      slots.push(nuovo("protezione dal sole", "Accessory", ["Cap/Hat", "Sunglasses"], { reason: `massima ${pf(tempMax)}: sole intenso` }));
    }
  }

  const attNorm = insieme((attivita || []).map(lws));
  const soleSet = insieme(["Cap/Hat", "Sunglasses"]);
  const haSole = slots.some((s) => s.category === "Accessory" && interseca(soleSet, s.subCategories || []));
  let sole = jevDice(classi, "sole");
  if (sole == null) sole = (tempMax != null && tempMax >= K.SOGLIA_SOLE) || interseca(attNorm, K.ATTIVITA_ALL_APERTO);
  if (!haSole && sole) {
    slots.push(nuovo("protezione dal sole", "Accessory", ["Cap/Hat", "Sunglasses"], { reason: "sole forte o attivita' all'aperto" }));
  } else if (sole) {
    for (const s of slots) {
      const subs = insieme(s.subCategories || []);
      if (s.category === "Accessory" && subs.size && sottoinsieme(subs, soleSet) &&
        s.slot !== "testa coperta" && s.slot !== "estremita al freddo") s.subCategories = ["Cap/Hat", "Sunglasses"];
    }
  }

  const cammino = insieme(K.SOTTOCAT_SCARPE_CAMMINO);
  if (K.SEGNALA_SCARPE_CAMMINO && (attivita || []).some((a) => K.RADICI_CAMMINO.some((r: string) => lw(a).includes(r))) &&
    !slots.some((s) => s.category === "Shoes" && vero(s.subCategories) && sottoinsieme(s.subCategories, cammino))) {
    slots.push(nuovo(K.SLOT_SCARPE_CAMMINO, "Shoes", [...K.SOTTOCAT_SCARPE_CAMMINO],
      { frequency: "daily", reason: "si cammina molto: serve una scarpa chiusa comoda" }));
  }

  const ciabatte = insieme(K.SOTTOCAT_CIABATTE);
  if (K.CIABATTE_IN_ACQUA && eAttivitaAcqua(attivita || []) && (tempMax == null || tempMax >= K.SOGLIA_CALZATURE) &&
    !(capienza != null && capienza <= 8) &&
    !slots.some((s) => s.category === "Shoes" && vero(s.subCategories) && sottoinsieme(s.subCategories, ciabatte))) {
    slots.push(nuovo(K.SLOT_CIABATTE, "Shoes", [...K.SOTTOCAT_CIABATTE], { frequency: "once", reason: "attivita' in acqua: ciabatte o sandali" }));
  }

  if (riverbero(attNorm, classi) && !slots.some((s) => s.category === "Accessory" &&
    JSON.stringify(s.subCategories || []) === JSON.stringify(["Sunglasses"]))) {
    slots.push(nuovo("occhiali da sole", "Accessory", ["Sunglasses"], { reason: "neve, ghiacciaio o quota: riverbero" }));
  }

  const attV = attivitaViaggio != null ? attivitaViaggio : attivita;
  let nPres: number;
  if (K.PRESENTABILI_PER_TIPO) {
    nPres = rc.presentabiliRichiesti(giorni || 1, attV,
      jevDice(classi, "sera_elegante") != null ? serateCurate(attV, classi) : null,
      capienza != null && capienza <= rc.CAPIENZA_SENZA_PRESENTABILI);
  } else {
    nPres = serateCurate(attivita, classi) ? 1 : 0;
  }
  if (nPres && !(giorni != null && giorni <= 1)) {
    slots.push(nuovo(K.SLOT_SERA_PRESENTABILE, "Upper Body", [...K.SOTTOCAT_PRESENTABILI], {
      formality: [...K.FORMALITA_PRESENTABILI], frequency: "once", _presentabili: nPres,
      reason: `cene, mare o citta': ${nPres} capi presentabili`,
    }));
  }
  return slots;
}

/** str.strip(chars) di Python. */
export function stripChars(s: string, chars: string): string {
  let i = 0, j = s.length;
  while (i < j && chars.includes(s[i])) i++;
  while (j > i && chars.includes(s[j - 1])) j--;
  return s.slice(i, j);
}
