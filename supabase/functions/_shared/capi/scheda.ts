// La scheda di un capo: prompt dello scan e dell'aggiunta a mano, pulizia
// della risposta di GPT, domande di controllo a Jev e campi in dubbio.
// Porting di scheda_capo.py del bench (oracolo: esporta_oracolo.py scheda).
//
// GPT RIEMPIE la scheda (dalla foto o dal solo nome), il codice la PULISCE
// (valori ammessi, categoria ricavata dalla sottocategoria), Jev CONTROLLA i
// campi che l'utente vede: un campo e' in dubbio se Jev e' sotto SOGLIA_DUBBIO
// o non e' d'accordo con GPT. Jev non riempie mai: sbaglia piu' di GPT.
import * as tassonomia from "../valigia/tassonomia.ts";

type Record_ = Record<string, any>;

export const NON_CAPO = "Not Clothing";
/** Cosa e' un oggetto che non e' un vestito -> categoria dell'app (items.category). */
export const TIPI_NON_CAPO: Record<string, string> = { Toiletries: "toiletries", Electronics: "elettronica", Other: "varie" };
export const PATTERN = ["Solid", "Striped", "Plaid", "Graphic", "Logo", "Floral", "Other"];
export const COPERTURE = ["Short-sleeve", "Long-sleeve", "Sleeveless", "Shorts", "Full-length", "Cropped", "N/A"];
export const FIT = ["Skinny", "Regular", "Oversize", "N/A"];
export const FORMALITA = ["Loungewear", "Casual", "Smart Casual", "Business", "Formal"];
export const TAG = ["Everyday", "Office", "Beach", "Swimming", "Hiking", "Sport", "Formal", "Lounge"];
export const NA = "N/A";
export const MAX_NOME = 80;
export const MAX_CAPI_SCAN = 12;

/** Soglia di Jev: presa da 36 capi il 19 ottobre, da ritarare coi dati veri. */
export const SOGLIA_DUBBIO = 0.8;
/** I campi che l'utente vede come etichette (ingombro e copertura mai). */
export const CAMPI_VISIBILI = ["subCategory", "warmth", "waterResistance", "formality"];
/** Essenziali e oggetti non vestiti: niente etichette, quindi niente dubbi. */
export const CATEGORIE_SENZA_ETICHETTE = new Set(["Essentials", NON_CAPO]);

const RIGHE_CAMPI = `- "baseColor": string ({colore})
- "pattern": string (ONE OF: "Solid", "Striped", "Plaid", "Graphic", "Logo", "Floral", "Other")
- "coverage": string (ONE OF: "Short-sleeve", "Long-sleeve", "Sleeveless", "Shorts", "Full-length", "Cropped", "N/A"; tops, dresses and jackets use the sleeve length, a coat is "Long-sleeve"; "Shorts", "Full-length", "Cropped" only for trousers, shorts and skirts; shoes, accessories and essentials "N/A")
- "fit": string (ONE OF: "Skinny", "Regular", "Oversize", "N/A")
- "warmth": integer (1 to 5: 1=canottiera/sandali, 2=t-shirt/sneakers, 3=felpa/jeans, 4=cappotto/stivali, 5=piumino/scarponi)
- "formality": string (ONE OF: "Loungewear", "Casual", "Smart Casual", "Business", "Formal")
- "activityTags": array of 1-3 strings (ONLY from: ["Everyday", "Office", "Beach", "Swimming", "Hiking", "Sport", "Formal", "Lounge"])
- "waterResistance": integer (0 = gets wet in the rain, 1 = resists light rain, 2 = waterproof)
- "bulk": integer (1 = folds small like a t-shirt, 2 = medium like jeans or sneakers, 3 = bulky like a coat or boots)`;

const CATEGORIE_PROMPT = tassonomia.CATEGORIE.map((c) => `"${c}"`).join(", ");

/** Aggiunta a mano: il prompt provato sulla lista di Davide il 19 ottobre, piu'
 *  il tipo di oggetto quando non e' un vestito. */
export const PROMPT_NOME = `You are a precise fashion item parser. The user typed the NAME of one item they want to
add to their wardrobe app (no photo), in Italian: {nome}.
It may also be something that is not clothing (electronics, toiletries, documents...).
Bags, backpacks, belts, watches, jewelry, sunglasses and umbrellas ARE wardrobe items: category "Accessory".
Respond ONLY with a raw JSON object — no markdown, no code fences — with EXACTLY these keys:
- "name": string (the name as typed)
- "category": string (ONE OF: ${CATEGORIE_PROMPT}, "Not Clothing")
- "subCategory": string (ONE OF based on category, "N/A" if "Not Clothing"):
{sottocategorie}
- "notClothingKind": string (ONLY if "Not Clothing", ONE OF: "Toiletries", "Electronics", "Other"; else "N/A")
` + RIGHE_CAMPI.replace("{colore}", 'primary color in Italian if the name says it, else "N/A"') + `
Brand names are a hint: use what you know about the brand.`;

/** Scan: il prompt di openai-proxy con la tassonomia nuova e i due campi. */
export const PROMPT_SCAN = `You are a precise fashion item parser. Analyze the image and identify ALL distinct clothing items currently WORN by the PRIMARY person in the foreground.
CRITICAL RULES:
- IGNORE any clothing items in the background (e.g., clothes on beds, chairs, hangers).
- Focus ONLY on the main subject's outfit.
- If the image shows a single item with no person (laid flat, on a hanger), describe that item.
Respond ONLY with a raw JSON array of objects — no markdown, no code fences.
Each object must have EXACTLY these keys:
- "name": string (Short descriptive name in Italian, e.g. "Giacca in pelle", "Jeans slim")
- "category": string (ONE OF: ${CATEGORIE_PROMPT})
- "subCategory": string (ONE OF based on category):
{sottocategorie}
` + RIGHE_CAMPI.replace("{colore}", 'Primary color in Italian, e.g. "Nero", "Bianco", "Blu navy"');

/** json.dumps(nome, ensure_ascii=False): il nome dell'utente resta dentro il campo. */
function stringaJson(t: string): string {
  return JSON.stringify(t);
}

export function promptNome(nome: string): string {
  // Prima la tassonomia: un nome che contiene "{sottocategorie}" resta com'e'.
  return PROMPT_NOME.replace("{sottocategorie}", () => tassonomia.testoPerPrompt())
    .replace("{nome}", () => stringaJson(nome));
}

export function promptScan(): string {
  return PROMPT_SCAN.replace("{sottocategorie}", () => tassonomia.testoPerPrompt());
}

// Gli spazi di str.split() di Python.
const SPAZI = /[\t\n\x0b\x0c\r\x1c-\x1f \x85\xa0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000]+/;

/** " ".join(t.split())[:massimo] di Python (taglio per caratteri, non per unita' UTF-16). */
function compatta(t: string, massimo: number): string {
  return Array.from(t.split(SPAZI).filter((x) => x !== "").join(" ")).slice(0, massimo).join("");
}

/** Il nome digitato: spazi in fila ridotti, al massimo MAX_NOME caratteri. */
export function pulisciNome(nome: unknown): string {
  return typeof nome === "string" ? compatta(nome, MAX_NOME) : "";
}

/** La risposta di GPT senza recinti markdown; null se non e' JSON. */
export function leggiJson(testo: string): unknown {
  let t = testo.trim();
  if (t.startsWith("```")) {
    t = t.slice(3);
    if (t.toLowerCase().startsWith("json")) t = t.slice(4);
    if (t.endsWith("```")) t = t.slice(0, -3);
  }
  try {
    return JSON.parse(t.trim());
  } catch {
    return null;
  }
}

function intero(v: unknown, basso: number, alto: number): number | null {
  if (typeof v === "string" && /^-?[0-9]+$/.test(v.trim())) v = parseInt(v.trim(), 10);
  return typeof v === "number" && Number.isInteger(v) && basso <= v && v <= alto ? v : null;
}

const scelta = (v: unknown, ammessi: string[]) => typeof v === "string" && ammessi.includes(v) ? v : null;
const testo = (v: unknown, massimo: number) => typeof v === "string" ? compatta(v, massimo) : "";

export interface Normalizzata {
  metadata: Record_;
  app_category: string;
  /** Campi che mancavano o non erano validi e hanno preso un valore di riserva. */
  corretti: string[];
}

/** Una scheda di GPT con i soli valori ammessi. Con `nome` (aggiunta a mano) il
 *  nome e' quello digitato, non quello riscritto da GPT. */
export function normalizza(grezzo: unknown, nome?: string | null): Normalizzata {
  const g: Record_ = grezzo !== null && typeof grezzo === "object" && !Array.isArray(grezzo) ? grezzo as Record_ : {};
  const corretti: string[] = [];
  const nomeOk = nome != null ? pulisciNome(nome) : testo(g.name, MAX_NOME);

  let cat = g.category;
  let sub = g.subCategory;
  if (cat === NON_CAPO) {
    const tipo = typeof g.notClothingKind === "string" && Object.hasOwn(TIPI_NON_CAPO, g.notClothingKind)
      ? g.notClothingKind : "Other";
    return {
      metadata: { name: nomeOk, category: NON_CAPO, subCategory: NA, notClothingKind: tipo },
      app_category: TIPI_NON_CAPO[tipo], corretti,
    };
  }

  // La categoria si ricava dalla sottocategoria (GPT ha scritto "Outerwear /
  // Fleece": il pile e' Upper Body). "Other" tiene la categoria di GPT.
  if (typeof sub === "string" && sub !== tassonomia.ALTRO && tassonomia.categoriaDi(sub)) {
    cat = tassonomia.categoriaDi(sub);
  } else if (sub === tassonomia.ALTRO && tassonomia.CATEGORIE.includes(cat)) {
    // tiene la categoria
  } else {
    sub = NA;
    corretti.push("subCategory");
    if (!tassonomia.CATEGORIE.includes(cat)) {
      cat = "Accessory";
      corretti.push("category");
    }
  }

  const m: Record_ = { name: nomeOk, category: cat, subCategory: sub, baseColor: testo(g.baseColor, 40) || NA };
  for (const [campo, ammessi, riserva] of [["pattern", PATTERN, "Solid"], ["coverage", COPERTURE, NA],
    ["fit", FIT, NA]] as [string, string[], string][]) {
    m[campo] = scelta(g[campo], ammessi) ?? riserva;
  }
  const w = intero(g.warmth, 1, 5);
  if (w === null) corretti.push("warmth");
  m.warmth = w ?? 3;
  const f = scelta(g.formality, FORMALITA);
  if (f === null) corretti.push("formality");
  m.formality = f ?? "Casual";

  const grezzi = g.activityTags;
  const tags = Array.isArray(grezzi)
    ? grezzi.filter((t, i) => typeof t === "string" && TAG.includes(t) && !grezzi.slice(0, i).includes(t)).slice(0, 3)
    : [];
  if (!tags.length) corretti.push("activityTags");
  m.activityTags = tags.length ? tags : ["Everyday"];

  for (const [campo, basso, alto, riserva] of [["waterResistance", 0, 2, 0], ["bulk", 1, 3, 2]] as
    [string, number, number, number][]) {
    const v = intero(g[campo], basso, alto);
    if (v === null) corretti.push(campo);
    m[campo] = v ?? riserva;
  }
  return { metadata: m, app_category: cat === "Accessory" ? "varie" : "vestiti", corretti };
}

// ── Jev ──────────────────────────────────────────────────────────────────────

const chiaveSub = (cat: string, sub: string) => sub === tassonomia.ALTRO ? `${cat}|${sub}` : sub;

/** Le stesse domande dei campi visibili, piu' "e' un vestito?" dentro il tipo. */
export function domandeJev(): Record<string, Record_> {
  const spiega = (s: string) => {
    const d = tassonomia.NUOVE[s]?.[2] ?? tassonomia.SPIEGA_VECCHIE[s];
    return d ? ` (${d})` : "";
  };
  const tipi: Record<string, string> = {};
  for (const c of tassonomia.CATEGORIE) {
    for (const s of tassonomia.SOTTOCATEGORIE[c]) tipi[chiaveSub(c, s)] = `${c}: ${s}${spiega(s)}`;
  }
  tipi[NON_CAPO] = "not a clothing item: electronics, toiletries, documents, other objects";
  return {
    subCategory: { type: "choice", instructions: "What kind of item is this?", criteria: tipi },
    warmth: {
      type: "choice", instructions: "How warm is this item?",
      criteria: {
        "1": "very light, like a tank top or sandals",
        "2": "light, like a t-shirt or sneakers",
        "3": "medium, like a sweatshirt or jeans",
        "4": "warm, like a coat or leather boots",
        "5": "very warm, like a down jacket or mountain boots",
      },
    },
    waterResistance: {
      type: "choice", instructions: "How does this item behave in the rain?",
      criteria: { "0": "it gets wet", "1": "it resists light rain", "2": "it is waterproof" },
    },
    formality: {
      type: "choice", instructions: "How formal is this item?",
      criteria: Object.fromEntries(FORMALITA.map((x) => [x, x])),
    },
  };
}

/** Cosa legge Jev. Dal nome: solo il nome digitato. Dalla foto Jev non vede
 *  l'immagine: legge il nome scritto da GPT e i campi che NON controlla. */
export function statoJev(metadata: Record_, daFoto: boolean): Record_ {
  if (!daFoto) {
    return {
      item_name: metadata.name,
      note: "Name typed by the user, in Italian, for one item they want to add "
        + "to their wardrobe app. No photo. Brand names are a hint.",
    };
  }
  return {
    item_name: metadata.name, color: metadata.baseColor ?? null, pattern: metadata.pattern ?? null,
    coverage: metadata.coverage ?? null, fit: metadata.fit ?? null,
    note: "Description of one clothing item seen in a photo, written in Italian "
      + "by another model. You do not see the photo.",
  };
}

/** [scelta, sicurezza] di una risposta a scelta di Jev; null se manca. */
function risposta(a: unknown): [string, number] | null {
  if (a === null || typeof a !== "object" || Array.isArray(a)) return null;
  const r = a as Record_;
  if (typeof r.choice !== "string") return null;
  const numero = (v: unknown): v is number => typeof v === "number";
  let p: number | null = null;
  if (r.probabilities !== null && typeof r.probabilities === "object" && !Array.isArray(r.probabilities)) {
    for (const v of Object.values(r.probabilities)) if (numero(v) && (p === null || v > p)) p = v;
  }
  if (p === null) p = numero(r.confidence) ? r.confidence : 0;
  return [r.choice, p];
}

export interface Dubbio { campo: string; valore: unknown; jev: unknown; sicurezza: number | null }

/** I campi da chiedere all'utente, nell'ordine delle etichette. "capo" in testa
 *  quando GPT e Jev non concordano su vestito / non vestito. Senza Jev restano
 *  solo i campi corretti dalla pulizia. */
export function dubbi(n: Normalizzata, risposteJev: Record_ | null | undefined): Dubbio[] {
  const m = n.metadata;
  const out: Dubbio[] = [];
  const r = risposteJev ?? {};
  const subJev = risposta(r.subCategory);
  const jevNonCapo = subJev !== null && subJev[0] === NON_CAPO;
  if (subJev !== null && jevNonCapo !== (m.category === NON_CAPO)) {
    out.push({ campo: "capo", valore: m.category === NON_CAPO, jev: jevNonCapo, sicurezza: subJev[1] });
  }
  if (CATEGORIE_SENZA_ETICHETTE.has(m.category)) return out;
  for (const campo of CAMPI_VISIBILI) {
    const valore = m[campo];
    const a = risposta(r[campo]);
    if (a !== null) {
      let s: unknown = a[0].split("|").at(-1);
      if ((campo === "warmth" || campo === "waterResistance") && /^[0-9]+$/.test(s as string)) s = parseInt(s as string, 10);
      if (campo === "subCategory" && s === NON_CAPO) s = null;
      if (a[1] < SOGLIA_DUBBIO || s !== valore || n.corretti.includes(campo)) {
        out.push({ campo, valore, jev: s, sicurezza: a[1] });
      }
    } else if (n.corretti.includes(campo)) {
      out.push({ campo, valore, jev: null, sicurezza: null });
    }
  }
  return out;
}
