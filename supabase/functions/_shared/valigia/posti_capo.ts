// Il capo di un posto della valigia quando il modello ha elencato le sottocategorie del bisogno.
// Il generatore riporta le sottocategorie al genitore e le ordina (slots.ts), e capoDelGap sceglie
// da quell'elenco senza piu' l'ordine del modello: con il freddo finiva sempre su "Maglione".
// Qui si segue l'ordine del modello, scartando cio' che non va al bisogno: un'altra categoria,
// un capo da caldo col freddo, un capo troppo leggero, un capo troppo casual. Non tocca la scelta
// dei capi dell'armadio: e' solo il nome del posto. I bisogni imposti dal sistema non hanno
// l'elenco del modello e restano alla regola di prima (capoDelGap).
import { viaggioDiLavoro } from "./inject.ts";
import { occasioneFormale } from "./regole_capi.ts";
import { calore, MAI_PER_IL_FREDDO, NOME_SOTTOCATEGORIA, soloElegante } from "./uscita.ts";

/** Categoria e calore che la sottocategoria garantisce (1-5): il piu' basso che un capo di quel tipo
 *  ha di solito, dalle definizioni del prompt dello scan. Il cappotto garantisce 3 (il trench), il
 *  piumino 4 (quello leggero): il cappotto di lana o il piumino da inverno stanno sopra. */
const TIPICO: Record<string, [string, number]> = {
  "T-Shirt": ["Upper Body", 2], "Shirt": ["Upper Body", 2], "Polo": ["Upper Body", 2], "Tank Top": ["Upper Body", 1],
  "Crop Top": ["Upper Body", 1], "Hoodie": ["Upper Body", 3], "Sweatshirt": ["Upper Body", 3], "Sweater": ["Upper Body", 4],
  "Fleece": ["Upper Body", 3], "Thermal Top": ["Upper Body", 3],
  "Jeans": ["Lower Body", 3], "Trousers": ["Lower Body", 3], "Shorts": ["Lower Body", 1], "Skirt": ["Lower Body", 2],
  "Leggings": ["Lower Body", 2], "Sweatpants": ["Lower Body", 3], "Thermal Bottoms": ["Lower Body", 4],
  "Ski Pants": ["Lower Body", 4], "Swimwear": ["Lower Body", 1], "Wetsuit": ["Lower Body", 2],
  "Dress": ["Full Body", 1],
  "Sneakers": ["Shoes", 2], "Sandals": ["Shoes", 1], "Flip-Flops": ["Shoes", 1], "Loafers": ["Shoes", 2],
  "Dress Shoes": ["Shoes", 2], "Boots": ["Shoes", 3], "Hiking Boots": ["Shoes", 4], "Snow Boots": ["Shoes", 5],
  "Water Shoes": ["Shoes", 1],
  "Coat": ["Outerwear", 3], "Down Jacket": ["Outerwear", 4], "Windbreaker": ["Outerwear", 2], "Rain Jacket": ["Outerwear", 3],
  "Blazer": ["Outerwear", 3], "Casual Jacket": ["Outerwear", 2], "Vest": ["Outerwear", 3], "Ski Jacket": ["Outerwear", 5],
  "Ski Suit": ["Outerwear", 5],
  "Cap/Hat": ["Accessory", 1], "Belt": ["Accessory", 1], "Bag": ["Accessory", 1], "Scarf": ["Accessory", 4],
  "Sunglasses": ["Accessory", 1], "Watch": ["Accessory", 1], "Jewelry": ["Accessory", 1], "Gloves": ["Accessory", 5],
  "Tie": ["Accessory", 1], "Umbrella": ["Accessory", 1],
};

/** Capi solo casual: non vanno in un bisogno senza il casual (solo Business, Formal o Smart Casual). */
const SOLO_CASUAL = new Set(["Jeans", "Sweatpants", "Shorts", "T-Shirt", "Tank Top", "Crop Top", "Hoodie", "Sweatshirt",
  "Leggings", "Flip-Flops"]);
/** Capi di sotto da non proporre in un viaggio di lavoro o con un'occasione formale, nemmeno per il casual. */
const NON_AL_LAVORO = new Set(["Jeans", "Sweatpants", "Shorts", "Leggings"]);

/** Capi fatti per il freddo: il calore e' il loro scopo, non serve il margine in piu' che si chiede agli altri. */
const PER_IL_FREDDO = new Set(["Thermal Top", "Thermal Bottoms", "Fleece", "Down Jacket", "Ski Jacket", "Ski Suit",
  "Ski Pants", "Snow Boots", "Gloves", "Scarf"]);

const senzaCasual = (formalita: string[]) =>
  formalita.length > 0 && !formalita.some((f) => f === "Casual" || f === "Loungewear");

/** La sottocategoria del posto: la prima dell'elenco del modello che e' della categoria del bisogno,
 *  non e' da caldo se serve calore, garantisce il calore chiesto (col freddo, uno in piu': la
 *  forbice e' un minimo, e il capo tipico deve starci sopra; salvo i capi fatti per il freddo), e non e' troppo casual per l'occasione.
 *  Se nessuna va, null: il posto resta quello di capoDelGap. */
export function sottocategoriaDalModello(g: Record<string, any>, richiesto: Record<string, any> | undefined,
  freddo: boolean, attivita: string[], armadio: (s: string) => boolean): string | null {
  const elenco: unknown = richiesto?.subCategoriesModello;
  if (!Array.isArray(elenco) || !elenco.length) return null;
  const minimo = Number(richiesto?.minWarmth ?? calore(g)?.[0] ?? 1);
  const formalita: string[] = (Array.isArray(richiesto?.formality) ? richiesto!.formality : Array.isArray(g.formality) ? g.formality : [])
    .map(String);
  const lavoro = viaggioDiLavoro(attivita) || occasioneFormale(attivita);
  // Col freddo il capo qualunque deve garantire un livello sopra il minimo; i capi per il freddo bastano al minimo meno uno.
  const serveA = (s: string) => (freddo && !PER_IL_FREDDO.has(s) ? minimo + 1 : minimo - 1);
  const eleganteSolo = soloElegante(g) || senzaCasual(formalita);
  for (const s of elenco.map(String)) {
    const t = TIPICO[s];
    if (!t || NOME_SOTTOCATEGORIA[s] === undefined || t[0] !== g.category || !armadio(s)) continue;
    if (minimo >= 3 && MAI_PER_IL_FREDDO.has(s)) continue;
    if (t[1] < serveA(s)) continue;
    if (eleganteSolo && SOLO_CASUAL.has(s)) continue;
    if (lavoro && NON_AL_LAVORO.has(s)) continue;
    return s;
  }
  return null;
}
