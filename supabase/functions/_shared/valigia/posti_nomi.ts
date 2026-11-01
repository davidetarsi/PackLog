// I nomi dei posti della valigia: uno per sottocategoria e per categoria (la generica di
// capoDelGap), in italiano e in inglese, singolare e plurale. Niente testo libero dal
// generatore: il nome nasce solo da questa tabella e dal qualificatore.
export interface NomePosto {
  /** [singolare, plurale]; per i nomi solo plurali le due voci sono uguali. */
  it: [string, string];
  genere: "m" | "f";
  /** [singular, plural]. */
  en: [string, string];
  /** false se il nome dice gia' il freddo, la pioggia o l'eleganza (Piumino, Guanti, Blazer). */
  qualificabile: boolean;
}

/** Nome solo plurale: la stessa voce per singolare e plurale. */
const sp = (s: string): [string, string] => [s, s];

export const NOMI_SOTTOCATEGORIA: Record<string, NomePosto> = {
  "T-Shirt": { it: ["maglietta", "magliette"], genere: "f", en: ["t-shirt", "t-shirts"], qualificabile: true },
  "Shirt": { it: ["camicia", "camicie"], genere: "f", en: ["shirt", "shirts"], qualificabile: true },
  "Polo": { it: ["polo", "polo"], genere: "f", en: ["polo shirt", "polo shirts"], qualificabile: true },
  "Hoodie": { it: ["felpa con cappuccio", "felpe con cappuccio"], genere: "f", en: ["hoodie", "hoodies"], qualificabile: true },
  "Sweatshirt": { it: ["felpa", "felpe"], genere: "f", en: ["sweatshirt", "sweatshirts"], qualificabile: true },
  "Sweater": { it: ["maglione", "maglioni"], genere: "m", en: ["sweater", "sweaters"], qualificabile: true },
  "Tank Top": { it: ["canottiera", "canottiere"], genere: "f", en: ["tank top", "tank tops"], qualificabile: true },
  "Crop Top": { it: ["top", "top"], genere: "m", en: ["crop top", "crop tops"], qualificabile: true },
  "Thermal Top": { it: ["maglia termica", "maglie termiche"], genere: "f", en: ["thermal top", "thermal tops"], qualificabile: false },
  "Fleece": { it: ["pile", "pile"], genere: "m", en: ["fleece", "fleeces"], qualificabile: true },
  "Jeans": { it: sp("jeans"), genere: "m", en: sp("jeans"), qualificabile: true },
  "Shorts": { it: sp("pantaloncini"), genere: "m", en: sp("shorts"), qualificabile: true },
  "Trousers": { it: sp("pantaloni"), genere: "m", en: sp("trousers"), qualificabile: true },
  "Leggings": { it: sp("leggings"), genere: "m", en: sp("leggings"), qualificabile: true },
  "Skirt": { it: ["gonna", "gonne"], genere: "f", en: ["skirt", "skirts"], qualificabile: true },
  "Sweatpants": { it: sp("pantaloni della tuta"), genere: "m", en: sp("sweatpants"), qualificabile: true },
  "Swimwear": { it: ["costume da bagno", "costumi da bagno"], genere: "m", en: ["swimsuit", "swimsuits"], qualificabile: true },
  "Thermal Bottoms": { it: sp("pantaloni termici"), genere: "m", en: sp("thermal bottoms"), qualificabile: false },
  "Ski Pants": { it: sp("pantaloni da sci"), genere: "m", en: sp("ski trousers"), qualificabile: false },
  "Wetsuit": { it: ["muta", "mute"], genere: "f", en: ["wetsuit", "wetsuits"], qualificabile: true },
  "Dress": { it: ["vestito", "vestiti"], genere: "m", en: ["dress", "dresses"], qualificabile: true },
  "Sneakers": { it: sp("sneakers"), genere: "f", en: sp("sneakers"), qualificabile: true },
  "Sandals": { it: sp("sandali"), genere: "m", en: sp("sandals"), qualificabile: true },
  "Boots": { it: sp("stivali"), genere: "m", en: sp("boots"), qualificabile: true },
  "Flip-Flops": { it: sp("infradito"), genere: "m", en: sp("flip-flops"), qualificabile: true },
  "Loafers": { it: sp("mocassini"), genere: "m", en: sp("loafers"), qualificabile: true },
  "Dress Shoes": { it: sp("scarpe eleganti"), genere: "f", en: sp("dress shoes"), qualificabile: false },
  "Hiking Boots": { it: sp("scarponi da trekking"), genere: "m", en: sp("hiking boots"), qualificabile: true },
  "Water Shoes": { it: sp("scarpe da acqua"), genere: "f", en: sp("water shoes"), qualificabile: true },
  "Snow Boots": { it: sp("doposci"), genere: "m", en: sp("snow boots"), qualificabile: false },
  "Coat": { it: ["cappotto", "cappotti"], genere: "m", en: ["coat", "coats"], qualificabile: true },
  "Rain Jacket": { it: ["giacca impermeabile", "giacche impermeabili"], genere: "f", en: ["rain jacket", "rain jackets"], qualificabile: false },
  "Down Jacket": { it: ["piumino", "piumini"], genere: "m", en: ["down jacket", "down jackets"], qualificabile: false },
  "Windbreaker": { it: ["giacca a vento", "giacche a vento"], genere: "f", en: ["windbreaker", "windbreakers"], qualificabile: true },
  "Blazer": { it: ["blazer", "blazer"], genere: "m", en: ["blazer", "blazers"], qualificabile: false },
  "Ski Jacket": { it: ["giacca da sci", "giacche da sci"], genere: "f", en: ["ski jacket", "ski jackets"], qualificabile: false },
  "Ski Suit": { it: ["tuta da sci", "tute da sci"], genere: "f", en: ["ski suit", "ski suits"], qualificabile: false },
  "Casual Jacket": { it: ["giacca casual", "giacche casual"], genere: "f", en: ["casual jacket", "casual jackets"], qualificabile: true },
  "Vest": { it: ["gilet", "gilet"], genere: "m", en: ["gilet", "gilets"], qualificabile: true },
  "Cap/Hat": { it: ["cappello", "cappelli"], genere: "m", en: ["hat", "hats"], qualificabile: true },
  "Belt": { it: ["cintura", "cinture"], genere: "f", en: ["belt", "belts"], qualificabile: true },
  "Bag": { it: ["borsa", "borse"], genere: "f", en: ["bag", "bags"], qualificabile: true },
  "Scarf": { it: ["sciarpa", "sciarpe"], genere: "f", en: ["scarf", "scarves"], qualificabile: true },
  "Sunglasses": { it: sp("occhiali da sole"), genere: "m", en: sp("sunglasses"), qualificabile: true },
  "Jewelry": { it: ["gioiello", "gioielli"], genere: "m", en: ["piece of jewellery", "pieces of jewellery"], qualificabile: true },
  "Watch": { it: ["orologio", "orologi"], genere: "m", en: ["watch", "watches"], qualificabile: true },
  "Gloves": { it: sp("guanti"), genere: "m", en: sp("gloves"), qualificabile: false },
  "Tie": { it: ["cravatta", "cravatte"], genere: "f", en: ["tie", "ties"], qualificabile: true },
  "Umbrella": { it: ["ombrello", "ombrelli"], genere: "m", en: ["umbrella", "umbrellas"], qualificabile: false },
};

/** Il nome generico, quando il gap non nomina una sottocategoria sola (capoDelGap). */
export const NOMI_CATEGORIA: Record<string, NomePosto> = {
  "Upper Body": { it: ["maglia", "maglie"], genere: "f", en: ["top", "tops"], qualificabile: true },
  "Lower Body": { it: sp("pantaloni"), genere: "m", en: sp("trousers"), qualificabile: true },
  "Full Body": { it: ["vestito", "vestiti"], genere: "m", en: ["dress", "dresses"], qualificabile: true },
  "Shoes": { it: sp("scarpe"), genere: "f", en: sp("shoes"), qualificabile: true },
  "Outerwear": { it: ["giacca", "giacche"], genere: "f", en: ["jacket", "jackets"], qualificabile: true },
  "Accessory": { it: ["accessorio", "accessori"], genere: "m", en: ["accessory", "accessories"], qualificabile: true },
};
