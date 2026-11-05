// I nomi dei posti della valigia: uno per sottocategoria e per categoria (la generica di
// capoDelGap), in italiano e in inglese, singolare e plurale. Niente testo libero dal
// generatore: il nome nasce solo da questa tabella e dal qualificatore.
export interface NomePosto {
  /** [singolare, plurale]; per i nomi solo plurali le due voci sono uguali. */
  it: [string, string];
  /** Nome solo plurale (Pantaloni, Guanti, Scarpe): anche con una copia si usa il plurale. I nomi
   *  invariabili (Polo, Blazer, Gilet) NON lo sono: con una copia restano singolari. */
  soloPlurale: boolean;
  genere: "m" | "f";
  /** [singular, plural]. */
  en: [string, string];
  /** false se il nome dice gia' il freddo, la pioggia o l'eleganza (Piumino, Guanti, Blazer). */
  qualificabile: boolean;
}

/** Nome solo plurale: la stessa voce per singolare e plurale. */
const sp = (s: string): [string, string] => [s, s];

export const NOME_FOULARD_LEGGERO: NomePosto = {
  it: ["foulard leggero", "foulard leggeri"], genere: "m", en: ["light scarf", "light scarves"],
  soloPlurale: false, qualificabile: false,
};

export const NOMI_SOTTOCATEGORIA: Record<string, NomePosto> = {
  "T-Shirt": { it: ["maglietta", "magliette"], genere: "f", en: ["t-shirt", "t-shirts"], soloPlurale: false, qualificabile: true },
  "Shirt": { it: ["camicia", "camicie"], genere: "f", en: ["shirt", "shirts"], soloPlurale: false, qualificabile: true },
  "Polo": { it: ["polo", "polo"], genere: "f", en: ["polo shirt", "polo shirts"], soloPlurale: false, qualificabile: true },
  "Hoodie": { it: ["felpa con cappuccio", "felpe con cappuccio"], genere: "f", en: ["hoodie", "hoodies"], soloPlurale: false, qualificabile: true },
  "Sweatshirt": { it: ["felpa", "felpe"], genere: "f", en: ["sweatshirt", "sweatshirts"], soloPlurale: false, qualificabile: true },
  "Sweater": { it: ["maglione", "maglioni"], genere: "m", en: ["sweater", "sweaters"], soloPlurale: false, qualificabile: true },
  "Tank Top": { it: ["canottiera", "canottiere"], genere: "f", en: ["tank top", "tank tops"], soloPlurale: false, qualificabile: true },
  "Crop Top": { it: ["top", "top"], genere: "m", en: ["crop top", "crop tops"], soloPlurale: false, qualificabile: true },
  "Thermal Top": { it: ["maglia termica", "maglie termiche"], genere: "f", en: ["thermal top", "thermal tops"], soloPlurale: false, qualificabile: false },
  // Il pile e' gia' un capo caldo: "Pile caldi" non si dice (come la maglia termica).
  "Fleece": { it: ["pile", "pile"], genere: "m", en: ["fleece", "fleeces"], soloPlurale: false, qualificabile: false },
  "Jeans": { it: sp("jeans"), genere: "m", en: sp("jeans"), soloPlurale: true, qualificabile: true },
  "Shorts": { it: sp("pantaloncini"), genere: "m", en: sp("shorts"), soloPlurale: true, qualificabile: true },
  "Trousers": { it: sp("pantaloni"), genere: "m", en: sp("trousers"), soloPlurale: true, qualificabile: true },
  "Leggings": { it: sp("leggings"), genere: "m", en: sp("leggings"), soloPlurale: true, qualificabile: true },
  "Skirt": { it: ["gonna", "gonne"], genere: "f", en: ["skirt", "skirts"], soloPlurale: false, qualificabile: true },
  "Sweatpants": { it: sp("pantaloni della tuta"), genere: "m", en: sp("sweatpants"), soloPlurale: true, qualificabile: true },
  "Swimwear": { it: ["costume da bagno", "costumi da bagno"], genere: "m", en: ["swimsuit", "swimsuits"], soloPlurale: false, qualificabile: true },
  "Thermal Bottoms": { it: sp("pantaloni termici"), genere: "m", en: sp("thermal bottoms"), soloPlurale: true, qualificabile: false },
  "Ski Pants": { it: sp("pantaloni da sci"), genere: "m", en: sp("ski trousers"), soloPlurale: true, qualificabile: false },
  "Wetsuit": { it: ["muta", "mute"], genere: "f", en: ["wetsuit", "wetsuits"], soloPlurale: false, qualificabile: true },
  "Dress": { it: ["vestito", "vestiti"], genere: "m", en: ["dress", "dresses"], soloPlurale: false, qualificabile: true },
  "Sneakers": { it: sp("sneakers"), genere: "f", en: sp("sneakers"), soloPlurale: true, qualificabile: true },
  "Sandals": { it: sp("sandali"), genere: "m", en: sp("sandals"), soloPlurale: true, qualificabile: true },
  "Boots": { it: sp("stivali"), genere: "m", en: sp("boots"), soloPlurale: true, qualificabile: true },
  "Flip-Flops": { it: sp("infradito"), genere: "m", en: sp("flip-flops"), soloPlurale: true, qualificabile: true },
  "Loafers": { it: sp("mocassini"), genere: "m", en: sp("loafers"), soloPlurale: true, qualificabile: true },
  "Dress Shoes": { it: sp("scarpe eleganti"), genere: "f", en: sp("dress shoes"), soloPlurale: true, qualificabile: false },
  "Hiking Boots": { it: sp("scarponi da trekking"), genere: "m", en: sp("hiking boots"), soloPlurale: true, qualificabile: true },
  "Water Shoes": { it: sp("scarpette da scoglio"), genere: "f", en: sp("water shoes"), soloPlurale: true, qualificabile: true },
  "Snow Boots": { it: sp("doposci"), genere: "m", en: sp("snow boots"), soloPlurale: true, qualificabile: false },
  "Coat": { it: ["cappotto", "cappotti"], genere: "m", en: ["coat", "coats"], soloPlurale: false, qualificabile: true },
  "Rain Jacket": { it: ["giacca impermeabile", "giacche impermeabili"], genere: "f", en: ["rain jacket", "rain jackets"], soloPlurale: false, qualificabile: false },
  "Down Jacket": { it: ["piumino", "piumini"], genere: "m", en: ["down jacket", "down jackets"], soloPlurale: false, qualificabile: false },
  "Windbreaker": { it: ["giacca a vento", "giacche a vento"], genere: "f", en: ["windbreaker", "windbreakers"], soloPlurale: false, qualificabile: true },
  "Blazer": { it: ["blazer", "blazer"], genere: "m", en: ["blazer", "blazers"], soloPlurale: false, qualificabile: false },
  "Ski Jacket": { it: ["giacca da sci", "giacche da sci"], genere: "f", en: ["ski jacket", "ski jackets"], soloPlurale: false, qualificabile: false },
  "Ski Suit": { it: ["tuta da sci", "tute da sci"], genere: "f", en: ["ski suit", "ski suits"], soloPlurale: false, qualificabile: false },
  "Casual Jacket": { it: ["giacca casual", "giacche casual"], genere: "f", en: ["casual jacket", "casual jackets"], soloPlurale: false, qualificabile: true },
  "Vest": { it: ["gilet", "gilet"], genere: "m", en: ["gilet", "gilets"], soloPlurale: false, qualificabile: true },
  "Cap/Hat": { it: ["cappello", "cappelli"], genere: "m", en: ["hat", "hats"], soloPlurale: false, qualificabile: true },
  "Belt": { it: ["cintura", "cinture"], genere: "f", en: ["belt", "belts"], soloPlurale: false, qualificabile: true },
  "Bag": { it: ["borsa", "borse"], genere: "f", en: ["bag", "bags"], soloPlurale: false, qualificabile: true },
  "Scarf": { it: ["sciarpa", "sciarpe"], genere: "f", en: ["scarf", "scarves"], soloPlurale: false, qualificabile: true },
  "Sunglasses": { it: sp("occhiali da sole"), genere: "m", en: sp("sunglasses"), soloPlurale: true, qualificabile: true },
  "Jewelry": { it: ["gioiello", "gioielli"], genere: "m", en: ["piece of jewellery", "pieces of jewellery"], soloPlurale: false, qualificabile: true },
  "Watch": { it: ["orologio", "orologi"], genere: "m", en: ["watch", "watches"], soloPlurale: false, qualificabile: true },
  "Gloves": { it: sp("guanti"), genere: "m", en: sp("gloves"), soloPlurale: true, qualificabile: false },
  "Tie": { it: ["cravatta", "cravatte"], genere: "f", en: ["tie", "ties"], soloPlurale: false, qualificabile: true },
  "Umbrella": { it: ["ombrello", "ombrelli"], genere: "m", en: ["umbrella", "umbrellas"], soloPlurale: false, qualificabile: false },
};

/** Il nome generico, quando il gap non nomina una sottocategoria sola (capoDelGap). */
export const NOMI_CATEGORIA: Record<string, NomePosto> = {
  "Upper Body": { it: ["maglia", "maglie"], genere: "f", en: ["top", "tops"], soloPlurale: false, qualificabile: true },
  "Lower Body": { it: sp("pantaloni"), genere: "m", en: sp("trousers"), soloPlurale: true, qualificabile: true },
  "Full Body": { it: ["vestito", "vestiti"], genere: "m", en: ["dress", "dresses"], soloPlurale: false, qualificabile: true },
  "Shoes": { it: sp("scarpe"), genere: "f", en: sp("shoes"), soloPlurale: true, qualificabile: true },
  "Outerwear": { it: ["giacca", "giacche"], genere: "f", en: ["jacket", "jackets"], soloPlurale: false, qualificabile: true },
  "Accessory": { it: ["accessorio", "accessori"], genere: "m", en: ["accessory", "accessories"], soloPlurale: false, qualificabile: true },
};

/** Le famiglie degli essenziali di base (postiApp): chiave = il tipo del posto. Pigiama e
 *  Necessaire sono invariabili (con una copia "Aggiungi il tuo"); Mutande e Calzini solo plurali. */
export const NOMI_FAMIGLIA: Record<string, NomePosto> = {
  "intimo": { it: sp("mutande"), genere: "f", en: sp("underwear"), soloPlurale: true, qualificabile: false },
  "calzini": { it: sp("calzini"), genere: "m", en: sp("socks"), soloPlurale: true, qualificabile: false },
  "notte": { it: ["pigiama", "pigiama"], genere: "m", en: sp("pyjamas"), soloPlurale: false, qualificabile: false },
  "igiene": { it: ["necessaire", "necessaire"], genere: "m", en: ["toiletry bag", "toiletry bags"], soloPlurale: false, qualificabile: false },
};
