// I posti della valigia dai mancanti del generatore: quanto e' importante un posto e come
// si chiama. Non tocca la scelta dei capi ne' gli avvisi (uscita.ts): e' un livello in piu'.
import type { Lingua } from "../lingua.ts";
import { meteoDelGap, soloElegante } from "./uscita.ts";
import { NOMI_CATEGORIA, NOMI_SOTTOCATEGORIA, type NomePosto } from "./posti_nomi.ts";

export type Livello = "importante" | "utile";
export type Qualifica = "freddo" | "acqua" | "elegante";

type Capo = { sub: string | null; categoria: string };

// Sottocategorie d'attivita': senza, l'attivita' non si fa (Davide, 1 novembre).
const DA_ATTIVITA = new Set(["Hiking Boots", "Water Shoes", "Swimwear", "Wetsuit", "Ski Jacket", "Ski Pants",
  "Ski Suit", "Snow Boots"]);
const CATEGORIE_DEL_METEO = new Set(["Outerwear", "Shoes", "Accessory"]);

/** Importante solo cio' che dipende da questo viaggio: un'attivita', un'occasione elegante, il
 *  freddo o la pioggia per giacche, scarpe e accessori. Il resto (magliette, maglioni, strato
 *  termico compresi) e' utile. */
export function livelloPosto(g: Record<string, any>, capo: Capo, viaggioFreddo: boolean): Livello {
  if (capo.sub && DA_ATTIVITA.has(capo.sub)) return "importante";
  if (soloElegante(g)) return "importante";
  if (CATEGORIE_DEL_METEO.has(capo.categoria)) {
    const { freddo, acqua } = meteoDelGap(g, capo, viaggioFreddo);
    if (freddo || acqua) return "importante";
  }
  return "utile";
}

/** Cosa qualifica il nome del posto: il freddo, poi la pioggia, poi l'eleganza. */
export function qualificaDelGap(g: Record<string, any>, capo: Capo, viaggioFreddo: boolean): Qualifica | null {
  const { freddo, acqua } = meteoDelGap(g, capo, viaggioFreddo);
  if (freddo) return "freddo";
  if (acqua) return "acqua";
  return soloElegante(g) ? "elegante" : null;
}

// Qualificatori italiani: [singolare, plurale], o per genere e numero quando cambiano.
const IT_INVERNALE: [string, string] = ["invernale", "invernali"];
const IT_ACQUA: [string, string] = ["impermeabile", "impermeabili"];
const IT_ELEGANTE: [string, string] = ["elegante", "eleganti"];
const IT_CALDO = { m: ["caldo", "caldi"], f: ["calda", "calde"] } as const;
const EN_QUALIFICATORE: Record<Qualifica, (invernale: boolean) => string> = {
  freddo: (invernale) => (invernale ? "winter" : "warm"), acqua: () => "waterproof", elegante: () => "smart",
};
const IT_AGGIUNGI = { m: ["Aggiungi il tuo", "Aggiungi i tuoi"], f: ["Aggiungi la tua", "Aggiungi le tue"] } as const;

const maiuscola = (t: string) => t.charAt(0).toUpperCase() + t.slice(1);

/** Il nome del posto e la frase del bottone "aggiungi". Plurale quando le copie sono piu' di
 *  una o il nome e' solo plurale (soloPlurale in tabella). I nomi invariabili restano singolari. */
export function nomePosto(capo: Capo, copie: number, qualifica: Qualifica | null, lingua: Lingua):
  { nome: string; aggiungi: string } {
  const voce: NomePosto | undefined = (capo.sub && NOMI_SOTTOCATEGORIA[capo.sub]) || NOMI_CATEGORIA[capo.categoria];
  if (!voce) return lingua === "en" ? { nome: "Item", aggiungi: "Add yours" } : { nome: "Capo", aggiungi: "Aggiungi il tuo" };
  const q = voce.qualificabile ? qualifica : null;
  const plurale = copie > 1 || voce.soloPlurale ? 1 : 0;
  if (lingua === "en") {
    const invernale = capo.categoria === "Outerwear" || capo.categoria === "Shoes";
    const nome = voce.en[plurale];
    return { nome: maiuscola(q ? `${EN_QUALIFICATORE[q](invernale)} ${nome}` : nome), aggiungi: "Add yours" };
  }
  let nome = voce.it[plurale];
  if (q === "freddo") {
    const invernale = capo.categoria === "Outerwear" || capo.categoria === "Shoes";
    nome += " " + (invernale ? IT_INVERNALE : IT_CALDO[voce.genere])[plurale];
  } else if (q === "acqua") {
    nome += " " + IT_ACQUA[plurale];
  } else if (q === "elegante") {
    nome += " " + IT_ELEGANTE[plurale];
  }
  return { nome: maiuscola(nome), aggiungi: IT_AGGIUNGI[voce.genere][plurale] };
}
