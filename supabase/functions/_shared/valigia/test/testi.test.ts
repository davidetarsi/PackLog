// Tutti i testi degli avvisi, su tutte le combinazioni che il generatore puo' dare:
// capi, tipi di mancante, meteo, tappe, nomi dell'utente. Regole di forma e di senso.
// Uso: node --test test/testi.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
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
  assert.doesNotMatch(testo, /non basta/, `${dove}: accordo col nome dell'utente "${testo}"`);
  // "non è abbastanza ..." solo col soggetto fisso "Il più simile che hai, X,"
  if (/non è abbastanza/.test(testo)) assert.match(testo, /^Il più simile che hai, .+, non è abbastanza /, `${dove}: soggetto "${testo}"`);
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

test("motivi e 'Perché queste scelte' delle valigie dell'oracolo: italiano pulito", () => {
  // I testi del generatore (motivi.ts, uguale al bench) sulle 50 valigie campione.
  const casi: any[] = JSON.parse(readFileSync(new URL("./oracolo_celle_campione.json", import.meta.url), "utf8"));
  let n = 0;
  for (const c of casi) {
    const m = c.motivi;
    const testi: string[] = [
      ...m.capi.flatMap((x: any) => [x.motivo.etichetta, x.motivo.frase, ...x.motivo.note, ...x.motivo.anche]),
      ...Object.values(m.riepilogo) as string[], ...m.essenziali.map((e: any) => e.motivo.frase),
      ...c.perche.flatMap((p: any) => [p.titolo, ...p.frasi]),
    ].filter((t) => t);
    for (const t of testi) {
      const dove = `${c.id}: "${t}"`;
      assert.doesNotMatch(t, /[aeiouAEIOU]'(\s|$|,)/, `${dove} apostrofo al posto dell'accento`);
      assert.doesNotMatch(t, /\ba [AaÀà]/, `${dove} "a" davanti ad "a"`);
      assert.doesNotMatch(t, /\b(T-shirt|camicie|polo|canotte|gonne): (col caldo )?uno\b/, `${dove} "uno" con un nome femminile`);
      assert.doesNotMatch(t, /\p{Lu}\p{Ll}+, \p{Lu}\p{Ll}+(:|$)/u, `${dove} elenco di luoghi senza "e"`);
      n++;
    }
    // Escursioni leggere non sono trekking; le terme non sono il mare.
    const att = [...(c.viaggio.scenario.attivita ?? []), ...(c.viaggio.scenario.legs ?? []).flatMap((l: any) => l.attivita ?? [])]
      .join(" ").toLowerCase();
    if (!/trekking|cammino|hiking|alpinismo/.test(att)) assert.ok(!testi.some((t) => /trekking/i.test(t)), `${c.id}: trekking`);
    if (!/mare|spiagg|beach|snorkel|surf|immersion|isola|crociera/.test(att)) {
      assert.ok(!testi.some((t) => /\bmare\b/i.test(t) && !/Mare o piscina/.test(t)), `${c.id}: mare`);
    }
  }
  assert.ok(n > 1000, `testi controllati: ${n}`);
});

test("candidato troppo pesante: il titolo chiede il capo leggero", () => {
  // Budapest, otto tappe: serve un maglione leggero, la felpa e' troppo calda.
  const g = (subCategories: string[]) => ({ tipo: "posseduto_ma_inadatto", category: "Upper Body", subCategories,
    candidato_scartato: "Felpa con cappuccio blu navy", candidato_warmth: 3, warmth_richiesto: [2, 2], tappe: ["Budapest"] });
  assert.deepEqual(copyMancante(g(["Sweater"])), { titolo: "Manca un maglione leggero per Budapest",
    perche: "Il più simile che hai, Felpa con cappuccio blu navy, è troppo pesante per il clima previsto." });
  assert.equal(copyMancante(g(["Hoodie", "Sweater"])).titolo, "Manca una felpa leggera o un maglione leggero per Budapest");
  assert.equal(copyMancante({ ...g(["Trousers"]), category: "Lower Body" }).titolo, "Manca un paio di pantaloni leggeri per Budapest");
  assert.equal(copyMancante({ ...g(["Sneakers", "Loafers", "Boots", "Sandals"]), category: "Shoes" }).titolo,
    "Manca un paio di scarpe leggere per Budapest");
  assert.equal(copyMancante({ ...g(["Casual Jacket"]), category: "Outerwear" }).titolo, "Manca una giacca casual leggera per Budapest");
  // Senza "troppo pesante" il titolo non cambia.
  assert.equal(copyMancante({ ...g(["Sweater"]), candidato_warmth: 1, warmth_richiesto: [3, 4] }).titolo, "Manca un maglione per Budapest");
});

test("capo elegante estivo in un viaggio freddo: si dice anche il freddo", () => {
  // Mosca a gennaio: il mancante chiede eleganza e accetta ogni calore, il candidato e' di lino.
  const g = { tipo: "posseduto_ma_inadatto", category: "Lower Body", subCategories: ["Trousers"],
    formality: ["Business", "Formal", "Smart Casual"], candidato_scartato: "Pantaloni di lino bianchi",
    candidato_warmth: 1, warmth_richiesto: [1, 5] };
  assert.equal(copyMancante(g, true).perche,
    "Il più simile che hai, Pantaloni di lino bianchi, non è abbastanza elegante né adatto al freddo previsto.");
  assert.equal(copyMancante(g, false).perche, "Il più simile che hai, Pantaloni di lino bianchi, non è abbastanza elegante.");
  assert.equal(copyMancante({ ...g, candidato_warmth: 3 }, true).perche,
    "Il più simile che hai, Pantaloni di lino bianchi, non è abbastanza elegante.");
});

test("bagaglio troppo pieno: un bagaglio piu' grande, o lasciare a casa qualcosa", () => {
  assert.deepEqual(copyMancante({ tipo: "volume_eccedente", da_valutare: ["Cardigan grigio", "Jeans regular scuri", "Jeans slim grigio"] }),
    { titolo: "Il bagaglio è troppo pieno",
      perche: "Considera un bagaglio più grande oppure lascia a casa qualcosa tra Cardigan grigio, Jeans regular scuri e Jeans slim grigio." });
  assert.equal(copyMancante({ tipo: "volume_eccedente", da_valutare: [] }).perche,
    "Quello che serve per questo viaggio non ci sta nel bagaglio scelto: considera un bagaglio più grande.");
});
