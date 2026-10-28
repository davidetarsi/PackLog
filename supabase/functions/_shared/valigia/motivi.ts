// Motivi standard: PERCHE' un capo e' in valigia, in parole per l'utente.
// Porting di motivi.py del bench (catalogo chiuso: codice, etichetta, frase).
// Si calcola sulla valigia finita, senza toccare la scelta dei capi.
import { occasioneFormale } from "./regole_capi.ts";
import { lavanderiaPresunta } from "./dopo.ts";
import { get } from "./slots.ts";
import type { RigaArmadio } from "./capo.ts";
import { massimo, minimo, o, ordina, pyRound, vero } from "./py.ts";
import type { Lingua } from "../lingua.ts";

type Record_ = Record<string, any>;

/** codice -> [etichetta, priorita': piu' bassa = piu' specifica] */
export const CATALOGO: Record<string, [string, number]> = {
  culto: ["Luoghi di culto", 1],
  formale: ["Occasione formale", 2],
  trekking: ["Trekking", 3],
  neve: ["Neve", 4],
  muta: ["Immersioni", 4],
  mare: ["Mare", 5],
  sera: ["Per la sera", 6],
  capospalla_caldo: ["Freddo", 7],
  pioggia: ["Pioggia", 8],
  strato_caldo: ["Strato caldo", 9],
  strato_base: ["Strato di base", 10],
  testa: ["Freddo", 11],
  collo: ["Freddo", 11],
  guanti: ["Freddo", 11],
  riverbero: ["Neve o quota", 12],
  scarpe_neve: ["Neve e ghiaccio", 12],
  sole: ["Sole", 13],
  cammino: ["Scarpe comode", 14],
  secondo_paio: ["Secondo paio", 15],
  vento: ["Mezza stagione", 16],
  giorno: ["Tutti i giorni", 20],
  essenziale: ["Essenziali", 21],
  consigliato: ["Utile in viaggio", 30],
};

/** Le etichette del catalogo in inglese (l'italiano e' nel CATALOGO, uguale al bench). */
const ETICHETTE_EN: Record<string, string> = {
  culto: "Places of worship", formale: "Formal occasion", trekking: "Trekking", neve: "Snow", muta: "Diving",
  mare: "Sea", sera: "For the evening", capospalla_caldo: "Cold", pioggia: "Rain", strato_caldo: "Warm layer",
  strato_base: "Base layer", testa: "Cold", collo: "Cold", guanti: "Cold", riverbero: "Snow or altitude",
  scarpe_neve: "Snow and ice", sole: "Sun", cammino: "Comfortable shoes", secondo_paio: "Second pair",
  vento: "Mid-season", giorno: "Every day", essenziale: "Essentials", consigliato: "Handy on the trip",
};

/** Nomi fissi degli slot che mette il codice del generatore. */
export const DA_NOME: Record<string, string> = {
  "spalle coperte": "culto", "ginocchia coperte": "culto", "foulard": "culto",
  "strato formale": "formale", "parte inferiore formale": "formale", "cravatta": "formale",
  "abito da cerimonia": "formale",
  "pantaloni da trekking": "trekking", "maglietta tecnica": "trekking",
  "scarpe da trekking": "trekking", "antivento leggero": "trekking",
  "pantaloni da neve": "neve", "muta": "muta",
  "costume da bagno": "mare", "ciabatte da mare": "mare",
  "capo presentabile per la sera": "sera",
  "capospalla caldo": "capospalla_caldo",
  "protezione dalla pioggia": "pioggia", "ombrello": "pioggia",
  "strato medio per la sera": "strato_caldo", "secondo strato medio": "strato_caldo",
  "strato aggiuntivo": "strato_caldo",
  "strato base sulla pelle": "strato_base",
  "testa coperta": "testa", "estremita al freddo": "testa", "collo e mani": "collo",
  "guanti": "guanti",
  "occhiali da sole": "riverbero", "protezione dal sole": "sole",
  "scarpe da cammino": "cammino", "calzature di ricambio": "secondo_paio",
};

const CALDI = new Set(["Sweater", "Hoodie", "Sweatshirt"]);
const CAPISPALLA_CALDI = new Set(["Coat", "Down Jacket"]);
const VESTITI = new Set(["Upper Body", "Lower Body", "Full Body"]);
/** Scarpe da spiaggia: le sneakers di uno slot 'da mare' restano scarpe comode. */
const SCARPE_MARE = new Set(["Sandals", "Flip-Flops", "Water Shoes"]);

/** La valigia con il viaggio da cui nasce: scenario, meteo e uscita del generatore. */
export interface Valigia {
  scenario: Record_;
  meteo?: Record_ | null;
  slots: Record_;
}

interface Contesto {
  giorni: number;
  lavatrice: boolean;
  lavanderia: boolean;
  tappe: Map<string, Record_>;
  occasione: boolean;
  trekking: boolean;
  escursioni: boolean;
  meteo: Record_;
  attivita: string[];
  richiesti: Map<string, Record_>;
  /** La lingua delle frasi per l'utente (la scelta dei motivi non cambia). */
  lingua: Lingua;
}

const gradi = (t: number | null) => (t != null ? `${pyRound(t)}°` : "?");

function attivitaDi(sc: Record_): string[] {
  const a = [...(o(get(sc, "attivita"), []) as string[])];
  for (const leg of o(get(sc, "legs"), []) as Record_[]) a.push(...(o(get(leg, "attivita"), []) as string[]));
  return a;
}

/** Dati del viaggio che servono alle frasi: giorni, clima per tappa, attivita'. */
export function contesto(v: Valigia, lingua: Lingua = "it"): Contesto {
  const sc = v.scenario, m = o(v.meteo, {}) as Record_, s = v.slots;
  const tappe = new Map<string, Record_>();
  if (vero(get(m, "_per_tappa"))) {
    const legs = new Map<string, Record_>();
    for (const l of o(get(sc, "legs"), []) as Record_[]) legs.set(l.destinazione, l);
    for (const t of m._per_tappa as Record_[]) {
      const leg = legs.get(t.destinazione) ?? {};
      tappe.set(t.destinazione, {
        ...t,
        attivita: [...(o(get(sc, "attivita"), []) as string[]), ...(o(get(leg, "attivita"), []) as string[])],
        giorni: o(get(o(get(s, "giorni_per_tappa"), {}), t.destinazione), get(leg, "giorni")),
      });
    }
  }
  let somma = 0;
  for (const t of tappe.values()) somma += o(get(t, "giorni"), 0) as number;
  const giorni = o(o(get(sc, "giorni"), somma), 1) as number;
  const att = attivitaDi(sc);
  const richiesti = new Map<string, Record_>();
  for (const r of o(get(s, "richiesti"), []) as Record_[]) if (vero(get(r, "slot"))) richiesti.set(r.slot, r);
  return {
    giorni, lavatrice: vero(get(sc, "lavatrice")),
    lavanderia: !vero(get(sc, "legs")) && lavanderiaPresunta(giorni, get(sc, "lavatrice")), tappe,
    occasione: occasioneFormale(att),
    trekking: att.some((a) => ["trekking", "escursion", "cammino", "hiking", "alpinismo"]
      .some((r) => a.toLowerCase().includes(r))),
    escursioni: soloEscursioni(att),
    meteo: m, attivita: att, richiesti, lingua,
  };
}

/** Solo escursioni leggere, senza trekking veri: si dice "escursioni" (giri di
 *  prova su DEV del 25 ottobre: "Per il trekking a Sintra"). */
function soloEscursioni(attivita: unknown[]): boolean {
  const a = attivita.filter((x) => x).join(" ").toLowerCase();
  return a.includes("escursion") && !["trekking", "cammino", "hiking", "alpinismo"].some((r) => a.includes(r));
}

/** Acqua del viaggio: "Per il mare" solo se c'e' il mare (terme a Budapest, 25 ottobre). */
const MARE = ["mare", "spiagg", "beach", "snorkel", "surf", "immersion", "isola", "crociera"];
const TERME = /\b(terme|termal|onsen|spa\b|sauna|hammam)/;

function acqua(attivita: unknown[]): string {
  const a = attivita.filter((x) => x).join(" ").toLowerCase();
  if (MARE.some((r) => a.includes(r))) return "mare";
  if (TERME.test(a)) return "terme";
  if (a.includes("piscin")) return "piscina";
  return "";
}

function attivitaCapo(ctx: Contesto, tappeCapo: string[]): unknown[] {
  const tt = tappeCapo.filter((t) => ctx.tappe.has(t)).map((t) => ctx.tappe.get(t)!);
  return tt.length ? tt.flatMap((t) => o(get(t, "attivita"), []) as unknown[]) : ctx.attivita;
}

/** L'etichetta del motivo, detta con le parole del viaggio. */
export function etichetta(codice: string, ctx: Contesto): string {
  if (ctx.lingua === "en") {
    if (codice === "trekking" && ctx.escursioni) return "Hikes";
    if (codice === "mare") {
      return ({ mare: "Sea", terme: "Hot springs", piscina: "Pool" } as Record<string, string>)[acqua(ctx.attivita)] ?? "Water";
    }
    return ETICHETTE_EN[codice];
  }
  if (codice === "trekking" && ctx.escursioni) return "Escursioni";
  if (codice === "mare") {
    return ({ mare: "Mare", terme: "Terme", piscina: "Piscina" } as Record<string, string>)[acqua(ctx.attivita)] ?? "Acqua";
  }
  return CATALOGO[codice][0];
}

function elenco(nomi: string[], e = "e"): string {
  const n = [...new Set(nomi.filter((x) => x))];
  if (!n.length) return "";
  return n.length === 1 ? n[0] : n.slice(0, -1).join(", ") + ` ${e} ` + n[n.length - 1];
}

const a = (luogo: string) => (luogo.slice(0, 1).toLowerCase() === "a" ? "ad " : "a ") + luogo;

interface Clima { tmin: number | null; tmax: number | null; tmin_ass: number | null; pioggia: number | null }

/** Minima, massima e pioggia delle tappe in cui il capo serve (la piu' dura). */
function clima(ctx: Contesto, tappeCapo: string[] | null | undefined): Clima {
  let tt = (o(tappeCapo, []) as string[]).filter((t) => ctx.tappe.has(t)).map((t) => ctx.tappe.get(t)!);
  if (!tt.length) tt = ctx.tappe.size ? [...ctx.tappe.values()] : [ctx.meteo];
  const v = (k: string, f: (...x: number[]) => number) => {
    const xs = tt.map((t) => get(t, k)).filter((x) => x != null) as number[];
    return xs.length ? f(...xs) : null;
  };
  return {
    tmin: v("temp_min_media", Math.min), tmax: v("temp_max_media", Math.max),
    tmin_ass: o(v("temp_min_assoluta", Math.min), v("temp_min_media", Math.min)),
    pioggia: v("giorni_di_pioggia", Math.max),
  };
}

/** Il motivo di uno slot: dal nome se lo mette il codice, se no dai dati.
 *  Giudizi di Davide (19 ottobre): un capo da vestire col tag Everyday non e'
 *  "da trekking"; una scarpa da trekking lo e' anche in uno slot da spiaggia;
 *  un capospalla dello slot pioggia senza pioggia vera ripara dal vento. */
export function codiceSlot(nome: string, slot: Record_ | null | undefined, capo: Record_, occasione = false,
  trekking = false, tmin: number | null = null, pioggia: number | null = null): string {
  const c = codiceSlotDati(nome, slot, capo, occasione, trekking, tmin);
  if (c === "pioggia" && get(capo, "category") === "Outerwear" && (o(pioggia, 0) as number) < 1) return "vento";
  return c;
}

function codiceSlotDati(nome: string, slot: Record_ | null | undefined, capo: Record_, occasione: boolean,
  trekking: boolean, tmin: number | null): string {
  const tagCapo = o(get(capo, "activityTags"), []) as string[];
  const quotidiano = VESTITI.has(get(capo, "category")) && tagCapo.includes("Everyday");
  const caldoVero = get(capo, "category") === "Outerwear" && (o(get(capo, "warmth"), 0) as number) >= 4;
  if (nome in DA_NOME) {
    const c = DA_NOME[nome];
    if (c === "pioggia" && caldoVero) return "capospalla_caldo";
    if (c === "trekking" && !trekking) return "cammino";
    if (c === "trekking" && quotidiano) return "giorno";
    return c;
  }
  slot = o(slot, {}) as Record_;
  const cat = o(get(capo, "category"), get(slot, "category"));
  const subs = new Set(o(get(slot, "subCategories"), [get(capo, "subCategory")]) as string[]);
  const forme = new Set(o(get(slot, "formality"), []) as string[]);
  const tag = new Set(o(get(slot, "activityTags"), []) as string[]);
  const sub = get(capo, "subCategory");
  if ((forme.has("Business") || forme.has("Formal")) && !(forme.has("Casual") || forme.has("Loungewear"))) {
    // senza un'occasione formale vera e' il capo presentabile della sera
    return occasione ? "formale" : "sera";
  }
  // Trekking solo se lo e' il CAPO: il modello mette il tag a slot generici.
  if (trekking && tagCapo.includes("Hiking") && !quotidiano && (tag.has("Hiking") || cat === "Shoes")) {
    return "trekking";
  }
  if (cat === "Shoes" && tmin != null && tmin <= 0 && (o(get(capo, "waterResistance"), 0) as number) >= 1) {
    return "scarpe_neve";
  }
  if (caldoVero) return "capospalla_caldo";
  if (sub === "Swimwear" || ((tag.has("Beach") || tag.has("Swimming")) && cat === "Shoes" && SCARPE_MARE.has(sub))) {
    return "mare";
  }
  if ((o(get(slot, "minWaterResistance"), 0) as number) >= 1 || subs.has("Rain Jacket")) return "pioggia";
  if (cat === "Outerwear") return [...subs].some((x) => CAPISPALLA_CALDI.has(x)) ? "capospalla_caldo" : "vento";
  if (cat === "Upper Body" && subs.size && [...subs].every((x) => CALDI.has(x) || x === "Fleece")) {
    return "strato_caldo";
  }
  if (cat === "Accessory") {
    if (sub === "Scarf") return (o(get(capo, "warmth"), 0) as number) >= 3 ? "collo" : "consigliato";
    if ((sub === "Sunglasses" || sub === "Cap/Hat") && (o(get(capo, "warmth"), 3) as number) <= 2) return "sole";
    if (sub === "Cap/Hat") return "testa";
    if (sub === "Gloves") return "guanti";
    return "consigliato";
  }
  if (cat === "Shoes") return "cammino";
  if (cat === "Upper Body" || cat === "Lower Body" || cat === "Full Body") return "giorno";
  return "consigliato";
}

const FORMALI: [string, string][] = [
  ["matrimon", "il matrimonio"], ["cerimon", "la cerimonia"], ["riunion", "le riunioni di lavoro"],
  ["lavoro", "il lavoro"], ["congress", "il congresso"], ["opera", "l'opera"], ["gala", "la serata di gala"],
];

export function frase(codice: string, capo: Record_, ctx: Contesto, nomeSlot = ""): string {
  if (ctx.lingua === "en") return fraseEn(codice, capo, ctx, nomeSlot);
  const c = clima(ctx, get(capo, "tappe"));
  let dove = "";
  const tappeCapo = o(get(capo, "tappe"), []) as string[];
  // Con piu' di tre tappe l'elenco non si legge: vale per il viaggio.
  if (ctx.tappe.size && tappeCapo.length && tappeCapo.length < ctx.tappe.size && new Set(tappeCapo).size <= 3) {
    const luoghi = elenco(tappeCapo);
    if (luoghi) dove = " " + a(luoghi);
  }
  const att = ctx.attivita.join(" ").toLowerCase();
  switch (codice) {
    case "culto": {
      const parte = nomeSlot === "ginocchia coperte" ? "ginocchia coperte" : "spalle coperte";
      return `Visite a templi o chiese${dove}: ${parte}`;
    }
    case "formale":
      for (const [parola, testo] of FORMALI) if (att.includes(parola)) return `Per ${testo}${dove}`;
      return `Per le occasioni eleganti${dove}`;
    case "trekking": return ctx.escursioni ? `Per le escursioni${dove}` : `Per il trekking${dove}`;
    case "neve": return "Per sci e neve";
    case "muta": return "Per immersioni o surf";
    case "mare": {
      const w = acqua(attivitaCapo(ctx, tappeCapo));
      if (w === "terme") return `Per le terme${dove}`;
      if (w === "piscina") return `Per la piscina${dove}`;
      if (get(capo, "subCategory") === "Swimwear") return w === "mare" ? `Per il mare${dove}` : `Per fare il bagno${dove}`;
      return `Mare o piscina${dove}`;
    }
    case "sera": return "Per cene e serate: un capo presentabile";
    case "capospalla_caldo": return `Minime fino a ${gradi(c.tmin_ass)}: serve un capo caldo${dove}`;
    case "pioggia": {
      const n = pyRound(o(c.pioggia, 0) as number);
      return n >= 2 ? `Circa ${n} giorni di pioggia previsti${dove}` : `Pioggia possibile${dove}`;
    }
    case "strato_caldo": {
      const t = c.tmin;
      if (t != null && t <= 8) return `Minima di ${gradi(t)}: uno strato caldo sotto la giacca`;
      if (t != null && t > 18) return `Minima di ${gradi(t)}: qualcosa di leggero per le sere fresche`;
      return `Minima di ${gradi(t)}: uno strato caldo per la sera e il fresco`;
    }
    case "strato_base": return `Minima di ${gradi(c.tmin)}: un capo leggero sotto i maglioni`;
    case "testa": return `Minima di ${gradi(c.tmin)}: testa coperta`;
    case "collo": return `Minima di ${gradi(c.tmin)}: collo coperto`;
    case "guanti": return `Minima di ${gradi(c.tmin)}: mani coperte`;
    case "scarpe_neve": return `Minima di ${gradi(c.tmin)}: scarpe che reggono neve e bagnato`;
    case "riverbero": return "Neve, ghiacciaio o quota: protegge dal riverbero";
    case "sole": return "Sole forte o giornate all'aperto";
    case "cammino": return "Si cammina molto: una scarpa chiusa e comoda";
    case "secondo_paio": return `${ctx.giorni} giorni: un secondo paio di scarpe`;
    case "vento": return `Per vento e serate fresche${dove}`;
    case "giorno": return `Da usare tutti i giorni${dove}`;
    case "essenziale": return "";
  }
  if (get(capo, "subCategory") === "Scarf") return "Un foulard leggero: copre spalle o collo quando serve";
  return "Utile per le attività del viaggio";
}

const FORMALI_EN: Record<string, string> = {
  matrimon: "the wedding", cerimon: "the ceremony", riunion: "the work meetings", lavoro: "work",
  congress: "the conference", opera: "the opera", gala: "the gala evening",
};

/** frase() in inglese: gli stessi casi, le stesse soglie. */
function fraseEn(codice: string, capo: Record_, ctx: Contesto, nomeSlot: string): string {
  const c = clima(ctx, get(capo, "tappe"));
  let dove = "";
  const tappeCapo = o(get(capo, "tappe"), []) as string[];
  if (ctx.tappe.size && tappeCapo.length && tappeCapo.length < ctx.tappe.size && new Set(tappeCapo).size <= 3) {
    const luoghi = elenco(tappeCapo, "and");
    if (luoghi) dove = " in " + luoghi;
  }
  const att = ctx.attivita.join(" ").toLowerCase();
  switch (codice) {
    case "culto": {
      const parte = nomeSlot === "ginocchia coperte" ? "knees covered" : "shoulders covered";
      return `Visiting temples or churches${dove}: ${parte}`;
    }
    case "formale":
      for (const [parola] of FORMALI) if (att.includes(parola)) return `For ${FORMALI_EN[parola]}${dove}`;
      return `For smart occasions${dove}`;
    case "trekking": return ctx.escursioni ? `For the hikes${dove}` : `For trekking${dove}`;
    case "neve": return "For skiing and snow";
    case "muta": return "For diving or surfing";
    case "mare": {
      const w = acqua(attivitaCapo(ctx, tappeCapo));
      if (w === "terme") return `For the hot springs${dove}`;
      if (w === "piscina") return `For the pool${dove}`;
      if (get(capo, "subCategory") === "Swimwear") return w === "mare" ? `For the sea${dove}` : `For swimming${dove}`;
      return `Sea or pool${dove}`;
    }
    case "sera": return "For dinners and evenings out: something presentable";
    case "capospalla_caldo": return `Lows down to ${gradi(c.tmin_ass)}: you need something warm${dove}`;
    case "pioggia": {
      const n = pyRound(o(c.pioggia, 0) as number);
      return n >= 2 ? `About ${n} rainy days expected${dove}` : `Rain possible${dove}`;
    }
    case "strato_caldo": {
      const t = c.tmin;
      if (t != null && t <= 8) return `Low of ${gradi(t)}: a warm layer under your jacket`;
      if (t != null && t > 18) return `Low of ${gradi(t)}: something light for cool evenings`;
      return `Low of ${gradi(t)}: a warm layer for evenings and cool weather`;
    }
    case "strato_base": return `Low of ${gradi(c.tmin)}: a light layer under your sweaters`;
    case "testa": return `Low of ${gradi(c.tmin)}: keep your head covered`;
    case "collo": return `Low of ${gradi(c.tmin)}: keep your neck covered`;
    case "guanti": return `Low of ${gradi(c.tmin)}: keep your hands covered`;
    case "scarpe_neve": return `Low of ${gradi(c.tmin)}: shoes that can handle snow and wet`;
    case "riverbero": return "Snow, glaciers or altitude: protects from the glare";
    case "sole": return "Strong sun or days outdoors";
    case "cammino": return "Lots of walking: a closed, comfortable shoe";
    case "secondo_paio": return `${ctx.giorni} days: a second pair of shoes`;
    case "vento": return `For wind and cool evenings${dove}`;
    case "giorno": return `For every day${dove}`;
    case "essenziale": return "";
  }
  if (get(capo, "subCategory") === "Scarf") return "A light scarf: covers shoulders or neck when needed";
  return "Useful for the trip's activities";
}

export interface Motivo { codice: string; etichetta: string; frase: string; anche: string[]; note: string[] }

/** Il motivo principale e le note del capo. */
export function motivoCapo(capo: Record_, ctx: Contesto): Motivo {
  const candidati: [string, string][] = [];
  const cl = clima(ctx, get(capo, "tappe"));
  for (const a of o(get(capo, "assegnazioni"), [{ slot: get(capo, "slot") }]) as Record_[]) {
    const nome = o(get(a, "slot"), "") as string;
    candidati.push([codiceSlot(nome, ctx.richiesti.get(nome), capo, ctx.occasione, ctx.trekking,
      cl.tmin, cl.pioggia), nome]);
  }
  const [codice, nome] = minimo(candidati, (x) => CATALOGO[x[0]][1])!;
  const note: string[] = [];
  const en = ctx.lingua === "en";
  if (vero(get(capo, "in_partenza"))) note.push(en ? "Wear it when you leave" : "Da indossare in partenza");
  const manche = (o(get(capo, "assegnazioni"), []) as Record_[]).flatMap((a) => o(get(a, "manchevolezze"), []) as unknown[]);
  if (get(capo, "match") === "ripiego" || manche.length) note.push(en ? "The best fit you have" : "Il più adatto che hai");
  const et = etichetta(codice, ctx);
  const altri = ordina(new Set(candidati.filter(([c]) => c !== codice).map(([c]) => etichetta(c, ctx))))
    .filter((e) => e !== et);
  return { codice, etichetta: et, frase: frase(codice, capo, ctx, nome), anche: altri, note };
}

const pezzi = (n: number) => (n === 1 ? "1 pezzo" : `${n} pezzi`);
const pezziEn = (n: number) => (n === 1 ? "1 piece" : `${n} pieces`);

/** Per i capi di tutti i giorni: perche' sono QUANTI sono (T-shirt x10). */
export function fraseQuantita(gruppo: Record_[], ctx: Contesto): string {
  const p = gruppo.reduce((n, x) => n + (get(x, "quantita", 1) as number), 0);
  const g = ctx.giorni;
  const c = clima(ctx, null);
  const caldo = c.tmax != null && c.tmax > 24;
  const sopra = get(gruppo[0], "category") === "Upper Body";
  if (ctx.lingua === "en") {
    const inizio = `${pezziEn(p)} for ${g} days`;
    if (ctx.lavanderia && p > 1) return `${inizio}: washed along the way`;
    if (ctx.lavatrice && g > 5) return `${inizio}: washed along the way with the washing machine`;
    if (caldo && sopra && p >= Math.min(g, 4)) return `${inizio}: one a day in the heat`;
    if (caldo && !sopra && p > 1) return `${inizio}: changed more often in the heat`;
    if (p > 1) {
      const ogni = Math.max(1, Math.floor(g / p + 0.5));
      return ogni === 1 ? `${inizio}: one a day` : `${inizio}: one every ${ogni} days or so`;
    }
    return "";
  }
  if (ctx.lavanderia && p > 1) return `${pezzi(p)} per ${g} giorni: si lavano strada facendo`;
  if (ctx.lavatrice && g > 5) return `${pezzi(p)} per ${g} giorni: con la lavatrice si rilavano strada facendo`;
  if (caldo && sopra && p >= Math.min(g, 4)) return `${pezzi(p)} per ${g} giorni: col caldo uno al giorno`;
  if (caldo && !sopra && p > 1) return `${pezzi(p)} per ${g} giorni: col caldo si cambiano più spesso`;
  if (p > 1) {
    const ogni = Math.max(1, Math.floor(g / p + 0.5));
    if (ogni === 1) return `${pezzi(p)} per ${g} giorni: uno al giorno`;
    return `${pezzi(p)} per ${g} giorni: uno ogni ${ogni} giorni circa`;
  }
  return "";
}

export function fraseEssenziale(e: Record_, ctx: Contesto): string {
  const q = get(e, "quantita", 1) as number, g = ctx.giorni;
  if (ctx.lingua === "en") {
    if (["pigiama", "pyjama", "pajama", "camicia da notte"].includes(get(e, "radice"))) return "One for the trip";
    if (q <= 1) return "One is enough for the trip";
    if (ctx.lavanderia && q < g) return `${q}: washing along the way they last ${q - 1} days, plus a spare`;
    if (ctx.lavatrice && q < g) return `${q}: with the washing machine they last ${q - 1} days, plus a spare`;
    if (q === g + 1) return `${q}: one a day plus a spare`;
    return `${q} for ${g} days`;
  }
  if (["pigiama", "pyjama", "pajama", "camicia da notte"].includes(get(e, "radice"))) return "Uno per il viaggio";
  if (q <= 1) return "Uno basta per il viaggio";
  if (ctx.lavanderia && q < g) return `${q}: lavando strada facendo bastano per ${q - 1} giorni, più un ricambio`;
  if (ctx.lavatrice && q < g) return `${q}: con la lavatrice bastano per ${q - 1} giorni, più un ricambio`;
  if (q === g + 1) return `${q}: uno al giorno più un ricambio`;
  return `${q} per ${g} giorni`;
}

/** str() di Python per l'id di un capo (None -> "None"). */
const strId = (x: unknown) => (x == null ? "None" : String(x));

/** {id del capo: tag d'uso} dalle righe dell'armadio (le righe della valigia non li hanno). */
export function tagArmadio(righe: RigaArmadio[]): Record<string, string[]> {
  const out: Record<string, string[]> = {};
  for (const r of righe) {
    let m: any = r.ai_metadata;
    m = vero(m) ? (typeof m === "string" ? JSON.parse(m) : m) : {};
    out[strId(r.id)] = o(get(m, "activityTags"), []) as string[];
  }
  return out;
}

export interface MotiviValigia {
  capi: Record_[];
  riepilogo: Record<string, string>;
  essenziali: Record_[];
}

/** Tutti i motivi di una valigia: capi, riepilogo per gruppo, essenziali. */
export function motiviValigia(v: Valigia, tag: Record<string, string[]>, lingua: Lingua = "it"): MotiviValigia {
  const ctx = contesto(v, lingua);
  const s = v.slots;
  const capi: Record_[] = [];
  for (const x0 of [...s.ideali, ...s.ripieghi] as Record_[]) {
    const id = strId(get(x0, "item_id"));
    const x = { ...x0, activityTags: id in tag ? tag[id] : [] };
    capi.push({ ...x, motivo: motivoCapo(x, ctx) });
  }
  const gruppi = new Map<string, Record_[]>();
  for (const x of capi) {
    if (x.motivo.codice !== "giorno") continue;
    const k = get(x, "subCategory");
    if (!gruppi.has(k)) gruppi.set(k, []);
    gruppi.get(k)!.push(x);
  }
  const riepilogo: Record<string, string> = {};
  for (const [sub, g] of gruppi) riepilogo[String(sub)] = fraseQuantita(g, ctx);
  const essenziali = (o(get(s, "essenziali"), []) as Record_[]).map((e) => ({
    ...e, motivo: { codice: "essenziale", etichetta: etichetta("essenziale", ctx), frase: fraseEssenziale(e, ctx), anche: [], note: [] },
  }));
  return { capi, riepilogo, essenziali };
}

export const NOMI_PLURALI: Record<string, string> = {
  "T-Shirt": "T-shirt", Shirt: "camicie", Polo: "polo", "Tank Top": "canotte",
  Shorts: "bermuda e shorts", Trousers: "pantaloni", Jeans: "jeans",
  Skirt: "gonne", Leggings: "leggings", Sweatpants: "pantaloni della tuta",
  Dress: "vestiti", "Crop Top": "top", "Thermal Top": "maglie termiche",
  "Thermal Bottoms": "pantaloni termici",
};
/** [singolare, plurale, paio]: "1 T-shirt", "3 T-shirts", "2 pairs of jeans". */
const NOMI_EN: Record<string, [string, string, boolean]> = {
  "T-Shirt": ["T-shirt", "T-shirts", false], Shirt: ["shirt", "shirts", false], Polo: ["polo shirt", "polo shirts", false],
  "Tank Top": ["tank top", "tank tops", false], Shorts: ["shorts", "shorts", true], Trousers: ["trousers", "trousers", true],
  Jeans: ["jeans", "jeans", true], Skirt: ["skirt", "skirts", false], Leggings: ["leggings", "leggings", true],
  Sweatpants: ["sweatpants", "sweatpants", true], Dress: ["dress", "dresses", false], "Crop Top": ["crop top", "crop tops", false],
  "Thermal Top": ["thermal top", "thermal tops", false], "Thermal Bottoms": ["thermal bottoms", "thermal bottoms", true],
  Hoodie: ["hoodie", "hoodies", false], Sweatshirt: ["sweatshirt", "sweatshirts", false],
  Sweater: ["sweater", "sweaters", false], Fleece: ["fleece", "fleeces", false], Swimwear: ["swimsuit", "swimsuits", false],
  "Ski Pants": ["ski trousers", "ski trousers", true], Wetsuit: ["wetsuit", "wetsuits", false],
};

/** "1 T-shirt", "3 T-shirts", "1 pair of jeans", "2 pairs of jeans"; un tipo sconosciuto com'e'. */
function quantiEn(n: number, sub: string): string {
  const voce = NOMI_EN[sub];
  if (!voce) return `${n} ${sub.toLowerCase()}`;
  const [uno, tanti, paio] = voce;
  if (paio) return `${n} ${n === 1 ? "pair" : "pairs"} of ${tanti}`;
  return `${n} ${n === 1 ? uno : tanti}`;
}

/** Nomi femminili: "2 camicie: una ogni 4 giorni" (non "uno"). */
const FEMMINILI = new Set(["T-Shirt", "Shirt", "Polo", "Tank Top", "Skirt", "Thermal Top"]);

const nomi = (capi: Record_[]) =>
  capi.map((x) => x.item + ((get(x, "quantita", 1) as number) > 1 ? ` ×${x.quantita}` : ""));

export interface Punto { codice: string; titolo: string; frasi: string[]; capi: string[] }

/** La scheda "Perche' queste scelte": un punto per motivo, nell'ordine del
 *  catalogo, con i capi che ci rientrano. */
export function percheValigia(v: Valigia, tag: Record<string, string[]>, m?: MotiviValigia,
  lingua: Lingua = "it"): Punto[] {
  m ??= motiviValigia(v, tag, lingua);
  const ctx = contesto(v, lingua);
  const en = lingua === "en";
  const gruppi = new Map<string, Record_[]>();
  for (const x of m.capi) {
    const k = x.motivo.codice;
    if (!gruppi.has(k)) gruppi.set(k, []);
    gruppi.get(k)!.push(x);
  }
  const punti: Punto[] = [];
  // "Tutti i giorni" per primo: e' la parte che l'utente riconosce subito
  const ordine = ordina(gruppi.keys(), (c) => [c !== "giorno", CATALOGO[c][1]]);
  for (const codice of ordine) {
    const capi = gruppi.get(codice)!;
    let frasi = [...new Set(capi.map((x) => x.motivo.frase as string))];
    if (codice === "giorno") {
      frasi = [];
      for (const [sub, testo] of Object.entries(m.riepilogo)) {
        if (!testo) continue;
        const n = capi.filter((x) => String(get(x, "subCategory")) === sub)
          .reduce((t, x) => t + (get(x, "quantita", 1) as number), 0);
        const i = testo.indexOf(": ");
        let resto = i < 0 ? testo : testo.slice(i + 2);
        if (en) {
          frasi.push(`${quantiEn(n, sub)}: ` + resto);
          continue;
        }
        if (FEMMINILI.has(sub)) resto = resto.replace("uno ", "una ");
        frasi.push(`${n} ${NOMI_PLURALI[sub] ?? sub.toLowerCase()}: ` + resto);
      }
      if (!frasi.length) frasi = [en ? "For every day" : "Da usare tutti i giorni"];
    } else if (codice === "culto") {
      const dove = frasi[0].split(":")[0];
      if (en) {
        const parti = new Set(frasi.map((f) => (f.includes("knees") ? "knees" : "shoulders")));
        frasi = [`${dove}: ` + ordina(parti, (x) => x, true).join(" and ") + " covered, in light clothes"];
      } else {
        const parti = new Set(frasi.map((f) => (f.includes("ginocchia") ? "ginocchia" : "spalle")));
        frasi = [`${dove}: ` + ordina(parti, (x) => x, true).join(" e ") + " coperte, con capi leggeri"];
      }
    } else if (frasi.length > 1) {
      frasi = [massimo(frasi, (f) => [...f].length)!]; // la stessa idea detta meglio
    }
    punti.push({ codice, titolo: etichetta(codice, ctx), frasi, capi: nomi(capi) });
  }
  if (m.essenziali.length) {
    punti.push({
      codice: "essenziale", titolo: etichetta("essenziale", ctx),
      frasi: [en
        ? `${ctx.giorni} days` + (ctx.lavanderia ? ", washing along the way" : ctx.lavatrice ? " with the washing machine" : "")
        : `${ctx.giorni} giorni` + (ctx.lavanderia ? " lavando strada facendo" : ctx.lavatrice ? " con la lavatrice" : "")],
      capi: m.essenziali.map((e) => (e.quantita > 1 ? `${e.item} ×${e.quantita}` : e.item)),
    });
  }
  return punti;
}
