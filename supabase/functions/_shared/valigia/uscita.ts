// L'uscita per l'app: i capi come li vede l'utente (uno per capo, con la quantita'
// da portare), il tetto sulle quantita' che ha davvero nell'armadio, e gli avvisi
// su cio' che manca. Non tocca la scelta dei capi: lavora sul risultato del generatore.
import { lavanderiaPresunta } from "./dopo.ts";
import { vero } from "./py.ts";
import type { Lingua } from "../lingua.ts";

type Record_ = Record<string, any>;

export const CODICE_POCHI = "pochi_pezzi";
export const CODICE_LAVANDERIA = "lavanderia";

export interface CapoApp {
  item_id: string;
  quantita: number;
  in_partenza: boolean;
  motivo: { codice: string; etichetta: string; frase: string };
}

export interface AvvisoApp {
  id: string;
  codice: string;
  livello: "importante" | "utile";
  titolo: string;
  perche: string;
  cerca: string | null;
}

// Copy fisso (italiano, niente testo libero dal generatore): ogni frase nasce solo
// dai campi strutturati del gap (category, subCategories, tipo, tappe, warmth_richiesto,
// impermeabilita_richiesta, candidato_scartato, da_valutare). Mai la parola "capospalla", mai numeri.
const NOME_SOTTOCATEGORIA: Record<string, string> = {
  "T-Shirt": "una maglietta", "Shirt": "una camicia", "Polo": "una polo", "Hoodie": "una felpa con cappuccio",
  "Sweatshirt": "una felpa", "Sweater": "un maglione", "Tank Top": "una canottiera", "Crop Top": "un top",
  "Thermal Top": "una maglia termica", "Fleece": "un pile", "Jeans": "un paio di jeans",
  "Shorts": "un paio di pantaloncini", "Trousers": "un paio di pantaloni", "Leggings": "un paio di leggings",
  "Skirt": "una gonna", "Sweatpants": "un paio di pantaloni della tuta", "Swimwear": "un costume da bagno",
  "Thermal Bottoms": "un paio di pantaloni termici", "Ski Pants": "un paio di pantaloni da sci",
  "Wetsuit": "una muta", "Dress": "un vestito", "Sneakers": "un paio di sneakers", "Sandals": "un paio di sandali",
  "Boots": "un paio di stivali", "Flip-Flops": "un paio di infradito", "Loafers": "un paio di mocassini",
  "Dress Shoes": "un paio di scarpe eleganti", "Hiking Boots": "un paio di scarponi da trekking",
  "Water Shoes": "un paio di scarpe da acqua", "Snow Boots": "un paio di doposci", "Coat": "un cappotto",
  "Rain Jacket": "una giacca impermeabile", "Down Jacket": "un piumino", "Windbreaker": "una giacca a vento",
  "Blazer": "un blazer", "Ski Jacket": "una giacca da sci", "Ski Suit": "una tuta da sci",
  "Casual Jacket": "una giacca casual", "Vest": "un gilet", "Cap/Hat": "un cappello", "Belt": "una cintura",
  "Bag": "una borsa", "Scarf": "una sciarpa", "Sunglasses": "un paio di occhiali da sole",
  "Jewelry": "un gioiello", "Watch": "un orologio", "Gloves": "un paio di guanti", "Tie": "una cravatta",
  "Umbrella": "un ombrello",
};
const NOME_CATEGORIA: Record<string, string> = {
  "Upper Body": "una maglia", "Lower Body": "un paio di pantaloni", "Full Body": "un vestito",
  "Shoes": "un paio di scarpe", "Outerwear": "una giacca", "Accessory": "un accessorio",
};

// In inglese l'articolo e "a pair of" si mettono scrivendo la frase: "a light sweater",
// "more than one pair of jeans". [nome, paio]
const EN_SOTTOCATEGORIA: Record<string, [string, boolean]> = {
  "T-Shirt": ["T-shirt", false], "Shirt": ["shirt", false], "Polo": ["polo shirt", false],
  "Hoodie": ["hoodie", false], "Sweatshirt": ["sweatshirt", false], "Sweater": ["sweater", false],
  "Tank Top": ["tank top", false], "Crop Top": ["crop top", false], "Thermal Top": ["thermal top", false],
  "Fleece": ["fleece", false], "Jeans": ["jeans", true], "Shorts": ["shorts", true], "Trousers": ["trousers", true],
  "Leggings": ["leggings", true], "Skirt": ["skirt", false], "Sweatpants": ["sweatpants", true],
  "Swimwear": ["swimsuit", false], "Thermal Bottoms": ["thermal bottoms", true], "Ski Pants": ["ski trousers", true],
  "Wetsuit": ["wetsuit", false], "Dress": ["dress", false], "Sneakers": ["sneakers", true],
  "Sandals": ["sandals", true], "Boots": ["boots", true], "Flip-Flops": ["flip-flops", true],
  "Loafers": ["loafers", true], "Dress Shoes": ["dress shoes", true], "Hiking Boots": ["hiking boots", true],
  "Water Shoes": ["water shoes", true], "Snow Boots": ["snow boots", true], "Coat": ["coat", false],
  "Rain Jacket": ["rain jacket", false], "Down Jacket": ["down jacket", false], "Windbreaker": ["windbreaker", false],
  "Blazer": ["blazer", false], "Ski Jacket": ["ski jacket", false], "Ski Suit": ["ski suit", false],
  "Casual Jacket": ["casual jacket", false], "Vest": ["gilet", false], "Cap/Hat": ["hat", false],
  "Belt": ["belt", false], "Bag": ["bag", false], "Scarf": ["scarf", false], "Sunglasses": ["sunglasses", true],
  "Jewelry": ["piece of jewellery", false], "Watch": ["watch", false], "Gloves": ["gloves", true],
  "Tie": ["tie", false], "Umbrella": ["umbrella", false],
};
const EN_CATEGORIA: Record<string, [string, boolean]> = {
  "Upper Body": ["top", false], "Lower Body": ["trousers", true], "Full Body": ["dress", false],
  "Shoes": ["shoes", true], "Outerwear": ["jacket", false], "Accessory": ["accessory", false],
};

const conArticolo = (t: string) => (/^[aeiou]/i.test(t) ? "an " : "a ") + t;

/** "a sweater", "a light sweater", "a pair of light trousers". */
function unoEn([nome, paio]: [string, boolean], leggero = false): string {
  const t = (leggero ? "light " : "") + nome;
  return paio ? `a pair of ${t}` : conArticolo(t);
}

/** Il capo del gap in inglese, dalla scelta fatta per l'italiano. */
function capoEn(capo: { nome: string; sub: string | null; categoria: string }, leggero = false): string {
  if (capo.nome === "una felpa o un maglione") {
    return `${unoEn(EN_SOTTOCATEGORIA.Sweatshirt, leggero)} or ${unoEn(EN_SOTTOCATEGORIA.Sweater, leggero)}`;
  }
  const n = (capo.sub && EN_SOTTOCATEGORIA[capo.sub]) || EN_CATEGORIA[capo.categoria];
  return n ? unoEn(n, leggero) : (leggero ? "a light item" : "an item");
}

/** "more than one sweater", "more than one pair of jeans". */
function piuDiUnoEn(capo: { sub: string | null; categoria: string }): string {
  const [nome, paio] = (capo.sub && EN_SOTTOCATEGORIA[capo.sub]) || EN_CATEGORIA[capo.categoria] || ["item", false];
  return paio ? `more than one pair of ${nome}` : `more than one ${nome}`;
}

// Il meteo si nomina solo per i capi che lo riguardano: niente "pioggia" per un paio di
// infradito, niente "freddo" per un costume. Altrimenti la frase dice "a questo viaggio".
const CONTRO_LA_PIOGGIA = new Set(["Coat", "Rain Jacket", "Down Jacket", "Windbreaker", "Ski Jacket", "Ski Suit",
  "Casual Jacket", "Boots", "Hiking Boots", "Snow Boots", "Sneakers", "Dress Shoes", "Loafers", "Ski Pants",
  "Cap/Hat", "Umbrella"]);
const CATEGORIE_CONTRO_LA_PIOGGIA = new Set(["Outerwear", "Shoes"]);
const MAI_PER_IL_FREDDO = new Set(["T-Shirt", "Polo", "Tank Top", "Crop Top", "Shorts", "Swimwear", "Sandals",
  "Flip-Flops", "Water Shoes", "Sunglasses", "Umbrella", "Wetsuit", "Belt", "Tie", "Jewelry", "Watch", "Bag"]);

/** Capi che non tutti usano: fra i mancanti solo se l'armadio ne ha gia' uno (Davide, 25 ottobre;
 *  la soluzione vera e' il profilo dell'utente). */
export const SOLO_SE_NELL_ARMADIO = new Set(["Skirt", "Dress", "Tie"]);
const STRATI_CALDI = new Set(["Hoodie", "Sweater", "Sweatshirt", "Fleece"]);
// Fra due o tre sottocategorie si nomina la piu' generica; i capi da cerimonia solo se il
// mancante chiede solo eleganza, il maglione e il piumino prima se fa freddo.
const PIU_GENERICHE = ["Trousers", "Jeans", "Sweatshirt", "Sweater", "T-Shirt", "Shirt", "Sneakers", "Boots",
  "Hiking Boots", "Coat", "Down Jacket", "Rain Jacket", "Casual Jacket", "Windbreaker", "Blazer", "Flip-Flops",
  "Sandals", "Shorts", "Leggings", "Sweatpants", "Dress Shoes", "Loafers", "Thermal Top", "Thermal Bottoms"];
// Un capo estivo chiesto caldo (la T-Shirt per lo "strato termico base" a Mosca) e' lo strato termico.
const TERMICO: Record<string, string> = { "Upper Body": "Thermal Top", "Lower Body": "Thermal Bottoms" };
const ELEGANTI = ["Blazer", "Dress Shoes", "Trousers", "Shirt"];
const COL_FREDDO = ["Sweater", "Down Jacket", "Boots"];

/** Solo eleganza: Business o Formal, niente di casual. */
function soloElegante(g: Record_): boolean {
  const f: unknown[] = Array.isArray(g.formality) ? g.formality : [];
  return f.some((x) => x === "Business" || x === "Formal") && !f.some((x) => x === "Casual" || x === "Loungewear");
}

/** Il capo del gap. Una sottocategoria: quella. Due o tre: la piu' generica. Piu' di tre: la
 *  categoria ("un paio di scarpe" e non "un paio di stivali" per cinque tipi di scarpe). */
function capoDelGap(g: Record_, freddo = false): { nome: string; sub: string | null; categoria: string } {
  const categoria = String(g.category ?? "");
  const subs = (Array.isArray(g.subCategories) ? g.subCategories : [])
    .filter((s: unknown): s is string => typeof s === "string" && NOME_SOTTOCATEGORIA[s] !== undefined);
  const generico = { nome: NOME_CATEGORIA[categoria] ?? "un capo", sub: null, categoria };
  if (!subs.length) return generico;
  const termico = TERMICO[categoria];
  if (termico && (calore(g)?.[0] ?? 0) >= 3 && subs.every((s) => MAI_PER_IL_FREDDO.has(s))) {
    return { nome: NOME_SOTTOCATEGORIA[termico], sub: termico, categoria };
  }
  if (subs.length > 1 && subs.every((s) => STRATI_CALDI.has(s))) {
    // col freddo serve il maglione (e si unisce all'avviso "Manca un maglione", Rovaniemi)
    return freddo ? { nome: NOME_SOTTOCATEGORIA.Sweater, sub: "Sweater", categoria }
      : { nome: "una felpa o un maglione", sub: "Sweatshirt", categoria };
  }
  if (subs.length > 3) return generico;
  const ordine = [...(soloElegante(g) ? ELEGANTI : []), ...(freddo ? COL_FREDDO : []), ...PIU_GENERICHE];
  const posto = (s: string) => (ordine.indexOf(s) < 0 ? ordine.length : ordine.indexOf(s));
  const sub = [...subs].sort((a, b) => posto(a) - posto(b))[0];
  return { nome: NOME_SOTTOCATEGORIA[sub], sub, categoria };
}

/** Il capo, leggero: "un maglione leggero", "una felpa leggera", "un paio di scarpe leggere". */
function leggero(nome: string): string {
  if (nome.includes(" o ")) return nome.split(" o ").map(leggero).join(" o ");
  if (nome.startsWith("un paio di ")) return `${nome} ${/^un paio di (scarpe|sneakers)\b/.test(nome) ? "leggere" : "leggeri"}`;
  return `${nome} ${nome.startsWith("una ") ? "leggera" : "leggero"}`;
}

/** "A", "A e B", "A, B e C" (oppure con "o", o in inglese "and"), senza nomi vuoti ne' ripetuti. */
function elenco(valori: unknown[], congiunzione: "e" | "o" | "and"): string {
  const nomi = [...new Set(valori.map((n) => String(n ?? "").trim()).filter((n) => n !== ""))];
  if (nomi.length <= 1) return nomi.join("");
  return `${nomi.slice(0, -1).join(", ")} ${congiunzione} ${nomi[nomi.length - 1]}`;
}

/** "per Reykjavik", "per Reykjavik e Akureyri"; senza tappe: il viaggio intero. */
function perTappe(g: Record_, lingua: Lingua = "it"): string {
  if (lingua === "en") {
    const nomi = elenco(Array.isArray(g.tappe) ? g.tappe : [], "and");
    return nomi ? `for ${nomi}` : "for the trip";
  }
  const nomi = elenco(Array.isArray(g.tappe) ? g.tappe : [], "e");
  return nomi ? `per ${nomi}` : "per il viaggio";
}

/** La forbice di calore chiesta, se c'e': [minimo, massimo]. */
function calore(g: Record_): [number, number] | null {
  const v = g.warmth_richiesto;
  if (!Array.isArray(v) || v.length !== 2) return null;
  const [a, b] = v.map((x) => (x == null ? NaN : Number(x)));
  return Number.isFinite(a) && Number.isFinite(b) ? [a, b] : null;
}

/** Il gap chiede freddo o pioggia per un capo che li riguarda. viaggioFreddo: minime del
 *  viaggio (o delle sue tappe) basse, per i mancanti che non dicono il calore. */
function meteoDelGap(g: Record_, capo: { sub: string | null; categoria: string }, viaggioFreddo = false) {
  const pioggiaSensata = capo.sub ? CONTRO_LA_PIOGGIA.has(capo.sub) : CATEGORIE_CONTRO_LA_PIOGGIA.has(capo.categoria);
  const freddoSensato = !(capo.sub && MAI_PER_IL_FREDDO.has(capo.sub));
  const acqua = capo.sub === "Umbrella" || (pioggiaSensata &&
    (Number(g.impermeabilita_richiesta ?? 0) >= 1 || Number(g.requiredWaterResistance ?? 0) >= 1));
  const w = calore(g);
  const freddo = freddoSensato && (w ? w[0] >= 3 : viaggioFreddo);
  return { freddo, acqua };
}

// Calzature da acqua: se il viaggio ha mare o terme, la frase lo dice (le infradito di Reykjavik).
const DA_ACQUA = new Set(["Flip-Flops", "Sandals", "Water Shoes"]);
const LUOGHI_D_ACQUA: [string, string, string][] = [["mare", "al mare", "the sea"], ["immersioni", "al mare", "the sea"],
  ["terme", "alle terme", "the hot springs"]];

/** Le frasi fisse degli avvisi. */
const TESTI = {
  it: {
    freddoEPioggia: "al freddo e alla pioggia previsti", freddo: "al freddo previsto", pioggia: "alla pioggia prevista",
    viaggio: "a questo viaggio", e: "e" as const,
    pesante: "è troppo pesante per il clima previsto", nonAdatto: (a: string) => `non è adatto ${a}`,
    eleganteEFreddo: "non è abbastanza elegante né adatto al freddo previsto", elegante: "non è abbastanza elegante",
  },
  en: {
    freddoEPioggia: "the expected cold and rain", freddo: "the expected cold", pioggia: "the expected rain",
    viaggio: "this trip", e: "and" as const,
    pesante: "is too heavy for the expected weather", nonAdatto: (a: string) => `isn't suited to ${a}`,
    eleganteEFreddo: "isn't smart enough or suited to the expected cold", elegante: "isn't smart enough",
  },
};

/** A cosa non basta quello che c'e': il freddo e la pioggia solo se il capo li riguarda;
 *  per le calzature da acqua il mare o le terme delle tappe del mancante. */
function adattoA(g: Record_, capo: { sub: string | null; categoria: string }, viaggioFreddo = false,
  attivita: string[] = [], lingua: Lingua = "it"): string {
  const t = TESTI[lingua];
  const { freddo, acqua } = meteoDelGap(g, capo, viaggioFreddo);
  if (freddo && acqua) return t.freddoEPioggia;
  if (freddo) return t.freddo;
  if (acqua) return t.pioggia;
  if (capo.sub && DA_ACQUA.has(capo.sub)) {
    const luoghi = elenco(LUOGHI_D_ACQUA.filter(([a]) => attivita.includes(a))
      .map(([, it, en]) => (lingua === "en" ? en : it)), t.e);
    if (luoghi) return luoghi;
  }
  return t.viaggio;
}

/** Le attivita' delle tappe del mancante (tutte, se non le dice), o quelle del viaggio. */
function attivitaPer(g: Record_, viaggio: Record_ | null | undefined): string[] {
  if (!viaggio) return [];
  const tappe: Record_[] = Array.isArray(viaggio.tappe) ? viaggio.tappe : [];
  const nomi = new Set((Array.isArray(g.tappe) ? g.tappe : []).map(String));
  const scelte = tappe.filter((t) => nomi.has(String(t.nome)));
  const fonti = scelte.length ? scelte : tappe;
  return [...(Array.isArray(viaggio.attivita) ? viaggio.attivita : []),
    ...fonti.flatMap((t) => (Array.isArray(t.attivita) ? t.attivita : []))].map(String);
}

/** Il candidato e' scartato perche' troppo caldo per la forbice chiesta (mai se fa freddo). */
function troppoPesante(g: Record_, freddo: boolean): boolean {
  const w = calore(g);
  const cw = g.candidato_warmth == null ? NaN : Number(g.candidato_warmth);
  return !freddo && w !== null && Number.isFinite(cw) && cw > w[1];
}

/** Titolo e corpo di un avviso dai mancanti del generatore: solo copy fisso, mai il testo libero.
 *  Le frasi non accordano nulla col nome del capo dell'utente ("Il più simile che hai, X, ..."),
 *  cosi' reggono singolari e plurali. */
/** Perche' il candidato non va, dai suoi dati: troppo pesante, poco caldo, non regge la
 *  pioggia, poco elegante. Il soggetto e' sempre "Il piu' simile che hai". */
function percheNonVa(g: Record_, capo: { sub: string | null; categoria: string }, viaggioFreddo: boolean,
  attivita: string[], lingua: Lingua = "it"): string {
  const t = TESTI[lingua];
  const w = calore(g);
  const cw = g.candidato_warmth == null ? NaN : Number(g.candidato_warmth);
  const { freddo, acqua } = meteoDelGap(g, capo, viaggioFreddo);
  const wr = g.candidato_wr == null ? NaN : Number(g.candidato_wr);
  const req = Number(g.impermeabilita_richiesta ?? g.requiredWaterResistance ?? 0);
  const poco = { caldo: freddo && w !== null && Number.isFinite(cw) && cw < w[0], acqua: acqua && Number.isFinite(wr) && wr < req };
  if (troppoPesante(g, freddo)) return t.pesante;
  if (poco.caldo && poco.acqua) return t.nonAdatto(t.freddoEPioggia);
  if (poco.caldo) return t.nonAdatto(t.freddo);
  if (poco.acqua) return t.nonAdatto(t.pioggia);
  if (soloElegante(g) || (Array.isArray(g.formality) && g.formality.length && g.formality.every(
    (x: unknown) => x === "Business" || x === "Formal" || x === "Smart Casual"))) {
    // Il lino a Mosca: il generatore lo scarta per l'eleganza, ma l'utente vede anche il freddo.
    const estivo = viaggioFreddo && Number.isFinite(cw) && cw <= 1 && !(capo.sub && MAI_PER_IL_FREDDO.has(capo.sub));
    return estivo ? t.eleganteEFreddo : t.elegante;
  }
  return t.nonAdatto(adattoA(g, capo, viaggioFreddo, attivita, lingua));
}

export function copyMancante(g: Record_, viaggioFreddo = false, attivita: string[] = [],
  lingua: Lingua = "it"): { titolo: string; perche: string } {
  if (lingua === "en") return copyMancanteEn(g, viaggioFreddo, attivita);
  if (g.tipo === "volume_eccedente") {
    const nomi = elenco(Array.isArray(g.da_valutare) ? g.da_valutare : [], "e");
    return { titolo: "Il bagaglio è troppo pieno",
      perche: nomi ? `Considera un bagaglio più grande oppure lascia a casa qualcosa tra ${nomi}.`
        : "Quello che serve per questo viaggio non ci sta nel bagaglio scelto: considera un bagaglio più grande." };
  }
  const capo = capoDelGap(g, viaggioFreddo || (calore(g)?.[0] ?? 0) >= 3);
  const tappe = perTappe(g);
  if (g.tipo === "quantita_insufficiente") {
    return { titolo: `Ti serve più di ${capo.nome} ${tappe}`,
      perche: "Nell'armadio di questa casa ne hai meno di quante ne servono." };
  }
  const candidato = typeof g.candidato_scartato === "string" ? g.candidato_scartato.trim() : "";
  if (g.tipo === "posseduto_ma_inadatto" && candidato) {
    // "Manca un maglione" con la felpa "troppo pesante" suona strano: si chiede quello leggero.
    const nome = troppoPesante(g, meteoDelGap(g, capo, viaggioFreddo).freddo) ? leggero(capo.nome) : capo.nome;
    return { titolo: `Manca ${nome} ${tappe}`,
      perche: `Il più simile che hai, ${candidato}, ${percheNonVa(g, capo, viaggioFreddo, attivita)}.` };
  }
  return { titolo: `Manca ${capo.nome} ${tappe}`,
    perche: `Nell'armadio di questa casa non c'è niente di adatto ${adattoA(g, capo, viaggioFreddo, attivita)}.` };
}

/** copyMancante in inglese: le stesse scelte, le frasi scritte per l'inglese. */
function copyMancanteEn(g: Record_, viaggioFreddo: boolean, attivita: string[]): { titolo: string; perche: string } {
  if (g.tipo === "volume_eccedente") {
    const nomi = elenco(Array.isArray(g.da_valutare) ? g.da_valutare : [], "and");
    return { titolo: "Your luggage is too full",
      perche: nomi ? `Consider a bigger bag, or leave one of these at home: ${nomi}.`
        : "What this trip needs doesn't fit in the chosen luggage: consider a bigger one." };
  }
  const capo = capoDelGap(g, viaggioFreddo || (calore(g)?.[0] ?? 0) >= 3);
  const tappe = perTappe(g, "en");
  if (g.tipo === "quantita_insufficiente") {
    return { titolo: `You need ${piuDiUnoEn(capo)} ${tappe}`,
      perche: "This home's wardrobe has fewer than you need." };
  }
  const candidato = typeof g.candidato_scartato === "string" ? g.candidato_scartato.trim() : "";
  if (g.tipo === "posseduto_ma_inadatto" && candidato) {
    const leggero = troppoPesante(g, meteoDelGap(g, capo, viaggioFreddo).freddo);
    return { titolo: `Missing ${capoEn(capo, leggero)} ${tappe}`,
      perche: `The closest you have, ${candidato}, ${percheNonVa(g, capo, viaggioFreddo, attivita, "en")}.` };
  }
  return { titolo: `Missing ${capoEn(capo)} ${tappe}`,
    perche: `Nothing in this home's wardrobe is suited to ${adattoA(g, capo, viaggioFreddo, attivita, "en")}.` };
}

/** Minima media sotto cui il viaggio (o la tappa) e' freddo, per i mancanti che non dicono il calore. */
export const MINIMA_FREDDA = 10;

/** Il viaggio e' freddo nelle tappe del gap (tutte, se il gap non le dice): la minima piu' bassa. */
function freddoPer(g: Record_, meteo: Record_ | null | undefined): boolean {
  if (!meteo) return false;
  const perTappa: Record_[] = Array.isArray(meteo._per_tappa) ? meteo._per_tappa : [];
  const tappe = new Set((Array.isArray(g.tappe) ? g.tappe : []).map(String));
  let fonti = perTappa.filter((t) => tappe.has(String(t.destinazione)));
  if (!fonti.length) fonti = perTappa.length ? perTappa : [meteo];
  const minime = fonti.map((t) => t.temp_min_media).filter((x) => x != null && Number.isFinite(Number(x))).map(Number);
  return minime.length > 0 && Math.min(...minime) <= MINIMA_FREDDA;
}

/** Togli dal gap gonna, vestito e cravatta se l'armadio non ne ha: null se non resta niente. */
function perQuestoArmadio(g: Record_, armadio: Set<string> | null): Record_ | null {
  if (!armadio || !Array.isArray(g.subCategories) || !g.subCategories.length) return g;
  const subs = g.subCategories.filter((s: unknown) => !SOLO_SE_NELL_ARMADIO.has(String(s)) || armadio.has(String(s)));
  return subs.length ? { ...g, subCategories: subs } : null;
}

/** Capi (uniti per item_id, quantita' sommata, tetto dell'armadio) e avvisi della valigia.
 *  meteo: quello della risposta del generatore; armadio: le sottocategorie dei capi della casa;
 *  viaggio: quello dell'app (giorni, lavatrice, tappe); lingua: quella dei testi degli avvisi. */
export function uscitaApp(valigia: Record_, motivi: { capi: Record_[]; essenziali: Record_[] },
  salvate: Map<string, number | null>,
  contesto: { meteo?: Record_ | null; armadio?: Iterable<string>; viaggio?: Record_ | null; lingua?: Lingua } = {},
): { capi: CapoApp[]; avvisi: AvvisoApp[] } {
  const en = contesto.lingua === "en";
  const armadio = contesto.armadio ? new Set(contesto.armadio) : null;
  // Lo stesso capo puo' stare in piu' tappe, come ideale e ripiego, o tra gli essenziali:
  // una riga sola, con la quantita' di tutti i posti in cui serve.
  const uniti = new Map<string, { item: string; quantita: number; in_partenza: boolean; motivo: Record_ }>();
  for (const x of [...motivi.capi, ...motivi.essenziali]) {
    const id = String(x.item_id);
    // Quantita' non numerica (o assente) conta come un pezzo.
    const n = x.quantita == null ? 1 : Number(x.quantita);
    const quantita = Number.isFinite(n) ? n : 1;
    const corrente = uniti.get(id);
    if (corrente) {
      corrente.quantita += quantita;
      corrente.in_partenza = corrente.in_partenza || vero(x.in_partenza);
    } else {
      uniti.set(id, { item: String(x.item ?? ""), quantita, in_partenza: vero(x.in_partenza), motivo: x.motivo });
    }
  }

  // Un capo tra gli essenziali e' importante anche se il suo motivo principale viene dai capi.
  const essenziali = new Set(motivi.essenziali.map((x) => String(x.item_id)));
  const capi: CapoApp[] = [];
  const avvisi: Omit<AvvisoApp, "id">[] = [];
  for (const [id, c] of uniti) {
    // Zero o negativo nell'armadio conta come una copia: il capo non sparisce.
    const tetto = Math.max(1, salvate.get(id) ?? 1);
    const quantita = Math.min(c.quantita, tetto);
    capi.push({
      item_id: id, quantita, in_partenza: c.in_partenza,
      motivo: { codice: c.motivo.codice, etichetta: c.motivo.etichetta, frase: c.motivo.frase },
    });
    if (quantita < c.quantita) {
      // Un pezzo solo in meno non e' mai importante, nemmeno per un essenziale.
      const essenziale = c.motivo.codice === "essenziale" || essenziali.has(id);
      avvisi.push({
        codice: CODICE_POCHI,
        livello: essenziale && c.quantita - tetto > 1 ? "importante" : "utile",
        titolo: en ? `You need more of ${c.item.trim()}` : `Ti servono più pezzi di ${c.item.trim()}`,
        perche: en ? `You'd need ${c.quantita}, the wardrobe has ${tetto}.`
          : `Ne servirebbero ${c.quantita}, nell'armadio ne hai ${tetto}.`,
        cerca: c.item.trim(),
      });
    }
  }

  for (const originale of (valigia.mancanti_canonici ?? []) as Record_[]) {
    const g = perQuestoArmadio(originale, armadio);
    if (!g) continue;
    const viaggioFreddo = freddoPer(g, contesto.meteo);
    const { titolo, perche } = copyMancante(g, viaggioFreddo, attivitaPer(g, contesto.viaggio), contesto.lingua);
    const { freddo, acqua } = meteoDelGap(g, capoDelGap(g, viaggioFreddo), viaggioFreddo);
    avvisi.push({
      codice: String(g.tipo),
      // Importante se il generatore lo dice necessario, o se e' essenziale e serve per il freddo
      // o la pioggia (Rovaniemi senza piumino si', la felpa della sera a Sharm no: 25 ottobre).
      livello: g.priorita === "necessario" || (vero(g.essential) && (freddo || acqua)) ? "importante" : "utile",
      titolo,
      perche,
      cerca: null,
    });
  }

  // Viaggio lungo in un posto solo, senza lavatrice: il generatore conta su un bucato
  // (quantita' di due settimane), e l'utente deve saperlo (Davide, 25 ottobre).
  const v = contesto.viaggio;
  if (v && !(Array.isArray(v.tappe) && v.tappe.length) && lavanderiaPresunta(v.giorni, v.lavatrice)) {
    avvisi.push({
      codice: CODICE_LAVANDERIA, livello: "utile", titolo: en ? "Plan to do laundry" : "Prevedi una lavanderia",
      perche: en ? "It's a long trip: the packing list counts on washing clothes along the way."
        : "Il viaggio è lungo: la valigia conta di lavare i vestiti strada facendo.", cerca: null,
    });
  }

  // Due mancanti diversi possono dare lo stesso titolo (scarpe per la citta' e scarpe da neve):
  // un avviso solo, importante se lo era almeno uno dei due, con la spiegazione di quello importante.
  const unici = new Map<string, Omit<AvvisoApp, "id">>();
  for (const a of avvisi) {
    const gia = unici.get(a.titolo);
    if (!gia) unici.set(a.titolo, a);
    else if (a.livello === "importante" && gia.livello !== "importante") unici.set(a.titolo, { ...a, cerca: gia.cerca ?? a.cerca });
  }

  // Prima gli importanti; a parita' di livello l'ordine di sopra (sort e' stabile).
  const ordinati = [...unici.values()]
    .sort((a, b) => Number(b.livello === "importante") - Number(a.livello === "importante"))
    .map((a, i) => ({ id: `${a.codice}:${i}`, ...a }));
  return { capi, avvisi: ordinati };
}
