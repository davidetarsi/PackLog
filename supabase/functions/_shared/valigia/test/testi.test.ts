// Tutti i testi degli avvisi, su tutte le combinazioni che il generatore puo' dare:
// capi, tipi di mancante, meteo, tappe, nomi dell'utente. Regole di forma e di senso.
// Uso: node --test test/testi.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { copyMancante, uscitaApp } from "../uscita.ts";

const SOTTOCATEGORIE = ["T-Shirt", "Shirt", "Polo", "Hoodie", "Sweatshirt", "Sweater", "Tank Top", "Crop Top",
  "Thermal Top", "Fleece", "Jeans", "Shorts", "Trousers", "Leggings", "Skirt", "Sweatpants", "Swimwear",
  "Thermal Bottoms", "Ski Pants", "Wetsuit", "Dress", "Sneakers", "Sandals", "Boots", "Flip-Flops", "Loafers",
  "Dress Shoes", "Hiking Boots", "Water Shoes", "Snow Boots", "Coat", "Rain Jacket", "Down Jacket", "Windbreaker",
  "Blazer", "Ski Jacket", "Ski Suit", "Casual Jacket", "Vest", "Cap/Hat", "Belt", "Bag", "Scarf", "Sunglasses",
  "Jewelry", "Watch", "Gloves", "Tie", "Umbrella", "Sottocategoria nuova"];
const CATEGORIE = ["Upper Body", "Lower Body", "Full Body", "Shoes", "Outerwear", "Accessory", "Essentials", ""];
const TIPI = ["assente", "posseduto_ma_inadatto", "quantita_insufficiente", "volume_eccedente", "tipo nuovo"];
const METEO = [
  {}, { warmth_richiesto: [4, 5] }, { impermeabilita_richiesta: 2 }, { warmth_richiesto: [5, 5], impermeabilita_richiesta: 1 },
  { warmth_richiesto: [1, 2] }, { warmth_richiesto: [null, null] }, { requiredWaterResistance: 1 },
];
const TAPPE = [undefined, [], ["Lisbona"], ["Lisbona", "Sintra"], ["Reykjavik", "Amsterdam", "Lisbona"],
  ["Lisbona", "Lisbona"], ["", " "], ["Seyðisfjörður"]];
const CANDIDATI = [undefined, "", "Scarpe da trail", "giacca a vento leggera", "  Piumino  "];

const ESTIVI = new Set(["T-Shirt", "Polo", "Tank Top", "Crop Top", "Shorts", "Swimwear", "Sandals", "Flip-Flops",
  "Water Shoes", "Sunglasses", "Umbrella", "Wetsuit", "Belt", "Tie", "Jewelry", "Watch", "Bag"]);
const CONTRO_PIOGGIA = new Set(["Coat", "Rain Jacket", "Down Jacket", "Windbreaker", "Ski Jacket", "Ski Suit",
  "Casual Jacket", "Boots", "Hiking Boots", "Snow Boots", "Sneakers", "Dress Shoes", "Loafers", "Ski Pants",
  "Cap/Hat", "Umbrella"]);

/** Le regole che ogni frase mostrata all'utente deve rispettare. */
function controlla(testo: string, dove: string) {
  assert.ok(testo.length > 0, `${dove}: vuota`);
  assert.equal(testo, testo.trim(), `${dove}: spazi ai bordi`);
  assert.doesNotMatch(testo, / {2}/, `${dove}: spazi doppi "${testo}"`);
  assert.match(testo, /^[A-ZÀ-Ý]/, `${dove}: non inizia con la maiuscola "${testo}"`);
  assert.doesNotMatch(testo, /undefined|null|NaN|\[object|\$\{/, `${dove}: valore crudo "${testo}"`);
  assert.doesNotMatch(testo, /capospalla|slot|warmth|bulk|ripieg|pila/i, `${dove}: parola interna "${testo}"`);
  assert.doesNotMatch(testo, /non basta|non è abbastanza/, `${dove}: accordo col nome dell'utente "${testo}"`);
  assert.doesNotMatch(testo, / ,|,,|\.\.|, (e|o) /, `${dove}: punteggiatura "${testo}"`);
  assert.doesNotMatch(testo, /\b(\p{L}+) e \1\b/u, `${dove}: nome ripetuto "${testo}"`);
  assert.doesNotMatch(testo, /\bper il meteo previsto\b|\badatto al meteo\b/, `${dove}: meteo generico "${testo}"`);
}

test("ogni combinazione di mancante da' frasi ben formate e sensate", () => {
  let n = 0;
  for (const tipo of TIPI) for (const category of CATEGORIE) for (const sub of [...SOTTOCATEGORIE, null])
    for (const meteo of METEO) for (const tappe of TAPPE) for (const candidato of CANDIDATI) {
      const g = { tipo, category, subCategories: sub ? [sub] : [], tappe, candidato_scartato: candidato, ...meteo,
        da_valutare: tipo === "volume_eccedente" ? ["Felpa grigia", "Maglione blu"] : undefined };
      const { titolo, perche } = copyMancante(g);
      const dove = JSON.stringify(g);
      controlla(titolo, `${dove} titolo`);
      controlla(perche, `${dove} perche`);
      assert.doesNotMatch(`${titolo} ${perche}`, /\d/, `${dove}: numeri`);
      assert.ok(perche.endsWith("."), `${dove}: perche senza punto`);
      assert.ok(!titolo.endsWith("."), `${dove}: titolo col punto`);
      // Il meteo si nomina solo per i capi che lo riguardano.
      if (sub && ESTIVI.has(sub)) assert.doesNotMatch(perche, /freddo/, `${dove}: freddo per un capo estivo`);
      if (sub && sub !== "Sottocategoria nuova" && !CONTRO_PIOGGIA.has(sub)) assert.doesNotMatch(perche, /pioggia/, `${dove}: pioggia per ${sub}`);
      // Il nome dell'utente arriva pulito e fra virgole, mai a fare da soggetto.
      if (tipo === "posseduto_ma_inadatto" && candidato?.trim()) {
        assert.ok(perche.startsWith(`Il più simile che hai, ${candidato.trim()}, `), `${dove}: candidato "${perche}"`);
      }
      n++;
    }
  assert.ok(n > 10000, `combinazioni provate: ${n}`);
});

test("pochi pezzi: nomi dell'utente qualsiasi, frasi ben formate", () => {
  for (const nome of ["Calzini", "T-shirt bianca", "  Boxer  ", "jeans", "Canottiera intima bianca"]) {
    for (const [serve, ho] of [[2, 1], [11, 10], [9, 1], [3, 0]]) {
      const motivi = { capi: [], essenziali: [{ item_id: "x", item: nome, quantita: serve,
        motivo: { codice: "essenziale", etichetta: "Essenziali", frase: "f" } }] };
      const [a] = uscitaApp({ mancanti_canonici: [] }, motivi, new Map([["x", ho]])).avvisi;
      assert.equal(a.titolo, `Ti servono più pezzi di ${nome.trim()}`);
      assert.equal(a.cerca, nome.trim());
      controlla(a.perche, `${nome} ${serve}/${ho}`);
    }
  }
});

test("due mancanti con la stessa frase: un avviso solo, importante se uno lo era", () => {
  // Rovaniemi: "scarpe per la citta'" e "scarpe da neve" danno lo stesso testo.
  const stivali = (priorita: string, essential: boolean) => ({ tipo: "posseduto_ma_inadatto", priorita, essential,
    category: "Shoes", subCategories: ["Boots", "Hiking Boots"], warmth_richiesto: [4, 5], impermeabilita_richiesta: 1,
    candidato_scartato: "Scarpe da trail", tappe: [] });
  const r = uscitaApp({ mancanti_canonici: [stivali("consigliato", false), stivali("consigliato", true)] },
    { capi: [], essenziali: [] }, new Map());
  assert.deepEqual(r.avvisi.map((a) => [a.id, a.livello, a.titolo, a.perche]), [["posseduto_ma_inadatto:0", "importante",
    "Manca un paio di stivali per il viaggio",
    "Il più simile che hai, Scarpe da trail, non è adatto al freddo e alla pioggia previsti."]]);
});

test("infradito per le terme di Lisbona: niente pioggia", () => {
  // Il caso di DEV: il generatore chiede impermeabilita' 2 a un paio di infradito.
  const { titolo, perche } = copyMancante({ tipo: "posseduto_ma_inadatto", category: "Shoes",
    subCategories: ["Flip-Flops", "Sandals"], warmth_richiesto: [1, 2], impermeabilita_richiesta: 2,
    candidato_scartato: "Scarpe da acqua", tappe: ["Lisbona"] });
  assert.equal(titolo, "Manca un paio di infradito per Lisbona");
  assert.equal(perche, "Il più simile che hai, Scarpe da acqua, non è adatto a questo viaggio.");
});

test("tappe vuote o ripetute: mai 'per Lisbona e Lisbona', mai 'per '", () => {
  const titolo = (tappe: unknown) => copyMancante({ tipo: "assente", category: "Outerwear",
    subCategories: ["Coat"], tappe }).titolo;
  assert.equal(titolo(["Lisbona", "Sintra", "Lisbona"]), "Manca un cappotto per Lisbona e Sintra");
  assert.equal(titolo(["", "  "]), "Manca un cappotto per il viaggio");
  assert.equal(titolo(null), "Manca un cappotto per il viaggio");
});
