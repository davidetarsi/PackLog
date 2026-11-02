// PARITA' CON IL 31 OTTOBRE 2026: il catalogo di oggi dà le stesse liste di prima
// del catalogo (tassonomia, scheda dei capi, attivita'). I valori attesi sono
// scritti qui sotto, non letti da catalogo.json: cosi' il test si accorge se il
// file perde o cambia una voce.
//
// COME AGGIORNARLO. Questi test fissano il CONTENUTO: falliscono apposta quando
// il catalogo cambia (una voce nuova, disattivata, rinominata). Non e' un guasto:
// dopo un export (esporta_catalogo.mjs) si aggiornano i valori scritti qui sotto
// con la modifica fatta, nello stesso commit. Le stesse liste stanno nei test Dart
// (test/features/items/model/clothing_taxonomy_test.dart, costanti _oggi...) e
// vanno aggiornate insieme. I test di FORMA (catalogo.test.ts) non vanno toccati.
// Quello che NON si aggiorna mai e' viaggi_esistenti.test.ts.
// Uso: node --test _shared/catalogo/test/catalogo_parita.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

type Voce = { domain: string; id: string; sort: number; active: boolean; label: { it: string; en: string };
  data: Record<string, any> };
const voci: Voce[] = JSON.parse(readFileSync(new URL("../catalogo.json", import.meta.url), "utf8")).entries;
const dominio = (d: string) => voci.filter((v) => v.domain === d).sort((a, b) => a.sort - b.sort);

// ── Tassonomia dei capi (valori di tassonomia.ts al commit bbf66c0) ──────────
const ALTRO = "Other";
const CATEGORIE = ["Upper Body", "Lower Body", "Full Body", "Shoes", "Outerwear", "Accessory", "Essentials"];
const VECCHIE: Record<string, string[]> = {
  "Upper Body": ["T-Shirt", "Shirt", "Polo", "Hoodie", "Sweatshirt", "Sweater", "Tank Top", "Crop Top"],
  "Lower Body": ["Jeans", "Shorts", "Trousers", "Leggings", "Skirt", "Sweatpants", "Swimwear"],
  "Shoes": ["Sneakers", "Sandals", "Boots", "Flip-Flops", "Loafers", "Dress Shoes", "Hiking Boots"],
  "Outerwear": ["Coat", "Rain Jacket", "Down Jacket", "Windbreaker", "Blazer"],
  "Accessory": ["Cap/Hat", "Belt", "Bag", "Scarf", "Sunglasses", "Jewelry", "Watch"],
};
// tipo nuovo -> [categoria, genitore, spiegazione per il prompt]
const NUOVE: Record<string, [string, string | null, string]> = {
  "Thermal Top": ["Upper Body", "T-Shirt", "maglia termica, strato base"],
  "Fleece": ["Upper Body", "Sweater", "pile"],
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
const SPIEGA_VECCHIE: Record<string, string> = {
  "Sweatpants": "pantaloni della tuta; in italiano 'tuta' e' sempre questo",
  "Hoodie": "felpa con cappuccio",
  "Sweatshirt": "felpa senza cappuccio",
  "Swimwear": "costume da bagno, bikini",
  "Windbreaker": "giacca a vento, k-way, softshell",
  "Rain Jacket": "giacca antipioggia, guscio impermeabile",
  "Down Jacket": "piumino",
  "Cap/Hat": "cappello, berretto, cuffia di lana",
};

// ── Scheda dei capi (valori di scheda.ts al commit bbf66c0) ──────────────────
const FORMALITA = ["Loungewear", "Casual", "Smart Casual", "Business", "Formal"];
const TAG = ["Everyday", "Office", "Beach", "Swimming", "Hiking", "Sport", "Formal", "Lounge"];
const COLORI = ["Bianco", "Nero", "Grigio", "Blu", "Marrone", "Beige", "Blu navy", "Azzurro", "Verde", "Rosso",
  "Bordeaux", "Rosa", "Giallo", "Arancione", "Viola", "Multicolore"];
const SINONIMI_COLORE: Record<string, string> = {
  "celeste": "Azzurro", "blu scuro": "Blu navy", "blu notte": "Blu navy", "navy": "Blu navy",
  "crema": "Beige", "panna": "Bianco", "avorio": "Bianco", "cammello": "Beige", "kaki": "Beige",
  "cachi": "Beige", "tortora": "Beige", "antracite": "Grigio", "fucsia": "Rosa", "lilla": "Viola",
  "porpora": "Viola", "bordò": "Bordeaux", "denim": "Blu", "multicolor": "Multicolore",
  "fantasia": "Multicolore", "white": "Bianco", "black": "Nero", "grey": "Grigio", "gray": "Grigio",
  "brown": "Marrone", "blue": "Blu", "navy blue": "Blu navy", "light blue": "Azzurro", "green": "Verde",
  "red": "Rosso", "burgundy": "Bordeaux", "pink": "Rosa", "yellow": "Giallo", "orange": "Arancione",
  "purple": "Viola", "multicolour": "Multicolore", "multicolored": "Multicolore",
  "multicoloured": "Multicolore",
};

test("parita': gruppi e tipi dei capi", () => {
  assert.deepEqual(dominio("clothing_group").map((v) => v.id), CATEGORIE);
  for (const c of CATEGORIE) {
    const attesi = [
      ...(VECCHIE[c] ?? []),
      ...Object.entries(NUOVE).filter(([, [cat]]) => cat === c).map(([s]) => s),
    ];
    const tipi = dominio("clothing_type").filter((t) => t.data.group === c).map((t) => t.id);
    assert.deepEqual(tipi, attesi, c);
  }
  const tipi = dominio("clothing_type").filter((t) => t.id !== ALTRO);
  for (const t of tipi) {
    assert.equal(t.data.parent, NUOVE[t.id]?.[1] ?? null, `genitore di ${t.id}`);
    assert.equal(t.data.hint, NUOVE[t.id]?.[2] || SPIEGA_VECCHIE[t.id] || null, `spiegazione di ${t.id}`);
  }
});

test("parita': stile, usi, colori, sinonimi, calore e pioggia", () => {
  assert.deepEqual(dominio("use").map((v) => v.id), TAG);
  assert.deepEqual(dominio("formality").map((v) => v.id), FORMALITA);
  assert.deepEqual(dominio("color").map((v) => v.id), COLORI);
  const sinonimi = Object.fromEntries(dominio("color").flatMap((c) => c.data.synonyms.map((s: string) => [s, c.id])));
  assert.deepEqual(sinonimi, SINONIMI_COLORE);
  assert.deepEqual(dominio("warmth").map((v) => v.id), ["1", "2", "3", "4", "5"]);
  assert.deepEqual(dominio("water").map((v) => v.id), ["0", "1", "2"]);
});

test("parita': attivita' e alloggi decisi il 31 ottobre, con le voci tolte disattivate", () => {
  const a = dominio("activity");
  assert.deepEqual(a.filter((v) => v.active).map((v) => v.id),
    ["city", "walks", "trekking", "cammino", "sea", "diving", "ski", "camping", "work", "evenings", "wedding",
      "worship", "spa"]);
  assert.deepEqual(a.filter((v) => !v.active).map((v) => v.id),
    ["high_mountain", "formal_dinner", "nightlife", "cycling"]);
  const testi = Object.fromEntries(a.map((v) => [v.id, v.data.generator]));
  assert.deepEqual(testi.evenings, ["cene al ristorante", "vita notturna"]);
  assert.deepEqual(testi.work, ["riunioni di lavoro"]);
  assert.deepEqual(testi.wedding, ["matrimonio"]);
  assert.deepEqual(testi.walks, ["escursioni leggere"]);
  assert.deepEqual(testi.high_mountain, ["escursioni in quota"]);
  assert.deepEqual(dominio("stay").map((v) => [v.id, v.data.generator]),
    [["hotel", "hotel"], ["apartment", "appartamento"], ["hostel", "ostello"], ["camping", "campeggio"],
      ["friends", "da amici o parenti"]]);
});
