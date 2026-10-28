// I testi in inglese di motivi e avvisi: stessi motivi e stesse scelte
// dell'italiano (che resta uguale al bench), frasi ben formate e senza parole
// italiane. Uso: node --test test/inglese.test.ts
// (ORACOLO_CELLE=file per tutte le valigie: esporta_oracolo.py celle FILE)
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import type { RigaArmadio } from "../capo.ts";
import { motiviValigia, percheValigia, tagArmadio } from "../motivi.ts";
import { copyMancante, uscitaApp } from "../uscita.ts";

const casi: any[] = JSON.parse(readFileSync(process.env.ORACOLO_CELLE
  ?? new URL("./oracolo_celle_campione.json", import.meta.url).pathname, "utf8"));
const tag: Record<string, Record<string, string[]>> = {};
for (const c of JSON.parse(readFileSync(new URL("./oracolo_quantita.json", import.meta.url), "utf8"))) {
  if (c.f === "carica_armadio") tag[c.nome + ".json"] = tagArmadio(c.args[0] as RigaArmadio[]);
}

const ITALIANO = /\b(il|lo|la|le|gli|di|da|per|che|non|una|un|nell|con|giorni|pezz[oi]|manca|alla|al|più|è|ne|tra|uno|serve|minima|pioggia|freddo|mare|terme|caldo)\b/i;

/** Una frase per l'utente in inglese: i luoghi (nomi propri) non contano. */
function controlla(testo: string, dove: string, luoghi: string[] = []) {
  assert.ok(testo.length > 0, `${dove}: vuota`);
  assert.equal(testo, testo.trim(), `${dove}: spazi ai bordi`);
  assert.doesNotMatch(testo, / {2}/, `${dove}: spazi doppi "${testo}"`);
  assert.match(testo, /^[A-Z0-9]/, `${dove}: non inizia con la maiuscola "${testo}"`);
  assert.doesNotMatch(testo, /undefined|null|NaN|\[object|\$\{/, `${dove}: valore crudo "${testo}"`);
  assert.doesNotMatch(testo, /\ba [aeiou]|\ban [^aeiou\s]/i, `${dove}: articolo "${testo}"`);
  let senza = testo;
  for (const l of luoghi) if (l) senza = senza.split(l).join("");
  assert.doesNotMatch(senza, ITALIANO, `${dove}: italiano "${testo}"`);
}

function luoghiDi(c: any): string[] {
  const m = c.viaggio.meteo ?? {};
  const sc = c.viaggio.scenario ?? {};
  return [...(m._per_tappa ?? []).map((t: any) => t.destinazione), sc.destinazione,
    ...(sc.legs ?? []).map((l: any) => l.destinazione)].filter((x) => typeof x === "string");
}

test(`motivi e scheda in inglese sulle valigie del campione (${casi.length})`, () => {
  for (const c of casi) {
    const v = { scenario: c.viaggio.scenario, meteo: c.viaggio.meteo, slots: c.atteso };
    const nome = `${c.insieme}/${c.armadio}/${c.id}`;
    const luoghi = luoghiDi(c);
    const it = motiviValigia(v, tag[c.armadio]);
    const en = motiviValigia(v, tag[c.armadio], "en");
    // Stessi capi, stessi motivi: cambia solo come si dicono.
    assert.deepEqual(en.capi.map((x) => [x.item_id, x.motivo.codice]), it.capi.map((x) => [x.item_id, x.motivo.codice]), nome);
    assert.deepEqual(Object.keys(en.riepilogo), Object.keys(it.riepilogo), nome);
    for (const x of en.capi) {
      controlla(x.motivo.etichetta, `${nome} etichetta`);
      controlla(x.motivo.frase, `${nome} frase`, luoghi);
      for (const n of x.motivo.note) controlla(n, `${nome} nota`);
    }
    for (const [sub, testo] of Object.entries(en.riepilogo)) {
      if (testo || it.riepilogo[sub]) controlla(testo, `${nome} riepilogo ${sub}`);
    }
    for (const e of en.essenziali) controlla(e.motivo.frase, `${nome} essenziale`);
    const pIt = percheValigia(v, tag[c.armadio]);
    const pEn = percheValigia(v, tag[c.armadio], undefined, "en");
    assert.deepEqual(pEn.map((p) => [p.codice, p.capi]), pIt.map((p) => [p.codice, p.capi]), nome);
    for (const p of pEn) {
      controlla(p.titolo, `${nome} titolo ${p.codice}`);
      for (const f of p.frasi) controlla(f, `${nome} punto ${p.codice}`, luoghi);
    }
  }
});

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
  { warmth_richiesto: [1, 2] }, { warmth_richiesto: [1, 2], candidato_warmth: 4 }, { formality: ["Formal"] },
];
const TAPPE = [undefined, [], ["Lisbona"], ["Reykjavik", "Amsterdam", "Lisbona"]];
const CANDIDATI = [undefined, "Scarpe da trail", "  Piumino  "];

test("avvisi in inglese: ogni combinazione di mancante", () => {
  let n = 0;
  for (const tipo of TIPI) for (const category of CATEGORIE) for (const sub of [...SOTTOCATEGORIE, null, "pila"])
    for (const meteo of METEO) for (const tappe of TAPPE) for (const candidato of CANDIDATI)
      for (const [freddo, attivita] of [[false, []], [true, ["mare", "terme"]]] as [boolean, string[]][]) {
        const subs = sub === "pila" ? ["Hoodie", "Sweater"] : sub ? [sub] : [];
        const g = { tipo, category, subCategories: subs, tappe, candidato_scartato: candidato, ...meteo,
          da_valutare: tipo === "volume_eccedente" ? ["Felpa grigia", "Maglione blu"] : undefined };
        const { titolo, perche } = copyMancante(g, freddo, attivita, "en");
        const dove = JSON.stringify(g);
        // I nomi dell'utente e i luoghi restano come sono.
        const propri = [...(tappe ?? []), "Felpa grigia", "Maglione blu", candidato?.trim() ?? ""];
        controlla(titolo, `${dove} titolo`, propri);
        controlla(perche, `${dove} perche`, propri);
        assert.ok(perche.endsWith("."), `${dove}: perche senza punto`);
        if (tipo === "posseduto_ma_inadatto" && candidato?.trim()) {
          assert.ok(perche.startsWith(`The closest you have, ${candidato.trim()}, `), `${dove}: candidato "${perche}"`);
        }
        n++;
      }
  assert.ok(n > 10000, `combinazioni provate: ${n}`);
});

test("avvisi in inglese: pochi pezzi, lavanderia, esempi", () => {
  const motivi = { capi: [], essenziali: [{ item_id: "x", item: " Calzini ", quantita: 9,
    motivo: { codice: "essenziale", etichetta: "Essentials", frase: "f" } }] };
  const r = uscitaApp({ mancanti_canonici: [{ tipo: "assente", category: "Upper Body", subCategories: ["Sweater"],
    tappe: ["Reykjavik"], warmth_richiesto: [4, 5], priorita: "necessario" }] }, motivi, new Map([["x", 4]]),
  { lingua: "en", viaggio: { giorni: 40, lavatrice: false } });
  assert.deepEqual(r.avvisi.map((a) => [a.codice, a.titolo, a.perche]), [
    ["pochi_pezzi", "You need more of Calzini", "You'd need 9, the wardrobe has 4."],
    ["assente", "Missing a sweater for Reykjavik", "Nothing in this home's wardrobe is suited to the expected cold."],
    ["lavanderia", "Plan to do laundry", "It's a long trip: the packing list counts on washing clothes along the way."],
  ]);
  assert.equal(copyMancante({ tipo: "quantita_insufficiente", category: "Lower Body", subCategories: ["Jeans"] }, false, [], "en").titolo,
    "You need more than one pair of jeans for the trip");
  assert.equal(copyMancante({ tipo: "posseduto_ma_inadatto", category: "Lower Body", subCategories: ["Trousers"],
    candidato_scartato: "Pantaloni di velluto", warmth_richiesto: [1, 2], candidato_warmth: 4, tappe: ["Bali"] }, false, [], "en").titolo,
  "Missing a pair of light trousers for Bali");
  assert.equal(copyMancante({ tipo: "assente", category: "Accessory", subCategories: ["Umbrella"] }, false, [], "en").titolo,
    "Missing an umbrella for the trip");
});
