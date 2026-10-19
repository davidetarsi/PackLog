// Tassonomia dei capi: categorie e sottocategorie, decisa con Davide il
// 19 ottobre 2026. Porting di tassonomia.py del bench
// (AI-checklist-test-script): stesso contenuto, stesse funzioni.
//
// Ogni sottocategoria nuova ha un GENITORE, la vecchia piu' vicina, oppure
// null: con genitore il generatore la tratta come il genitore, senza entra
// solo dove una regola la chiede. "Other" c'e' in ogni categoria.

export const VECCHIE: Record<string, string[]> = {
  "Upper Body": ["T-Shirt", "Shirt", "Polo", "Hoodie", "Sweatshirt", "Sweater", "Tank Top", "Crop Top"],
  "Lower Body": ["Jeans", "Shorts", "Trousers", "Leggings", "Skirt", "Sweatpants", "Swimwear"],
  "Shoes": ["Sneakers", "Sandals", "Boots", "Flip-Flops", "Loafers", "Dress Shoes", "Hiking Boots"],
  "Outerwear": ["Coat", "Rain Jacket", "Down Jacket", "Windbreaker", "Blazer"],
  "Accessory": ["Cap/Hat", "Belt", "Bag", "Scarf", "Sunglasses", "Jewelry", "Watch"],
};

// sottocategoria nuova -> [categoria, genitore, spiegazione per il prompt]
export const NUOVE: Record<string, [string, string | null, string]> = {
  "Thermal Top": ["Upper Body", "T-Shirt", "maglia termica, strato base"],
  "Fleece": ["Upper Body", "Sweater", "pile"],
  // senza genitore (20 ottobre): come Leggings faceva da pantalone; va sotto i pantaloni
  "Thermal Bottoms": ["Lower Body", null, "calzamaglia o pantaloni termici"],
  "Ski Pants": ["Lower Body", null, "pantaloni da sci o salopette"],
  "Wetsuit": ["Lower Body", null, "muta da sub o da surf"],
  "Dress": ["Full Body", null, "vestito o abito da donna, copre sopra e sotto"],
  "Ski Jacket": ["Outerwear", "Down Jacket", "giacca da sci"],
  "Ski Suit": ["Outerwear", "Down Jacket", "tuta da sci intera, copre anche le gambe"],
  "Casual Jacket": ["Outerwear", null, "giacca casual: di jeans, bomber, giacca camicia"],
  "Vest": ["Outerwear", null, "gilet o smanicato"],
  "Water Shoes": ["Shoes", "Sandals", "scarpe da acqua o da scoglio"],
  "Snow Boots": ["Shoes", "Boots", "doposci o scarponi da neve"],
  "Gloves": ["Accessory", null, "guanti"],
  "Tie": ["Accessory", null, "cravatta o papillon"],
  "Umbrella": ["Accessory", null, "ombrello"],
  "Underwear": ["Essentials", null, "mutande, boxer, reggiseno, canottiera intima"],
  "Socks": ["Essentials", null, "calze e calzini"],
  "Pajamas": ["Essentials", null, "pigiama"],
};
export const ALTRO = "Other";

export const SPIEGA_VECCHIE: Record<string, string> = {
  "Sweatpants": "pantaloni della tuta; in italiano 'tuta' e' sempre questo",
  "Hoodie": "felpa con cappuccio",
  "Sweatshirt": "felpa senza cappuccio",
  "Swimwear": "costume da bagno, bikini",
  "Windbreaker": "giacca a vento, k-way, softshell",
  "Rain Jacket": "giacca antipioggia, guscio impermeabile",
  "Down Jacket": "piumino",
  "Cap/Hat": "cappello, berretto, cuffia di lana",
};

export const CATEGORIE = ["Upper Body", "Lower Body", "Full Body", "Shoes", "Outerwear", "Accessory",
  "Essentials"];

export const SOTTOCATEGORIE: Record<string, string[]> = Object.fromEntries(
  CATEGORIE.map((c) => [c, [
    ...(VECCHIE[c] ?? []),
    ...Object.entries(NUOVE).filter(([, [cat]]) => cat === c).map(([s]) => s),
    ALTRO,
  ]]),
);

export const GENITORE: Record<string, string | null> = Object.fromEntries(
  Object.entries(NUOVE).map(([s, [, g]]) => [s, g]),
);

/** La sottocategoria con cui ragiona la logica: il genitore se c'e'. */
export function perIlGeneratore(sottocat: string | null | undefined): string | null | undefined {
  if (sottocat == null) return sottocat;
  return GENITORE[sottocat] || sottocat;
}

export function categoriaDi(sottocat: string): string | null {
  for (const c of CATEGORIE) {
    if (sottocat !== ALTRO && SOTTOCATEGORIE[c].includes(sottocat)) return c;
  }
  return null;
}

/** Le righe "categoria -> sottocategorie" per i prompt (scan e nome). */
export function testoPerPrompt(): string {
  return CATEGORIE.map((c) => {
    const voci = SOTTOCATEGORIE[c].map((s) => {
      const spiega = NUOVE[s]?.[2] || SPIEGA_VECCHIE[s];
      return spiega ? `"${s}" (${spiega})` : `"${s}"`;
    });
    return `  ${c} → ` + voci.join(", ");
  }).join("\n");
}
